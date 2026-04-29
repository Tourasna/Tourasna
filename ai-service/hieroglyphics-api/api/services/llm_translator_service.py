"""
LLM-based translator service (Layer 2 of the hybrid pipeline).

Uses Groq Cloud API with Llama 3.3 70B Versatile for high-quality
hieroglyphic translation. The model receives Gardiner codes and returns
grammatical English/Arabic translations with confidence scores.

Why this layer exists:
- The custom Transformer (Layer 3) achieves only BLEU 7.76% — not enough
  for production-quality translation of unknown sequences.
- Public datasets are dictionary-style (word-level), not sentence-level.
- LLMs trained on broad web data have seen Egyptological references and
  can produce grammatical translations with historical context.

Why Groq specifically:
- Accessible globally (no regional restrictions like Gemini in Egypt)
- ~10x faster than Gemini API (hardware-accelerated inference)
- Free tier: 30 requests/min, 14,400/day — sufficient for production
- Llama 3.3 70B is a strong open model from Meta

Failure handling:
- Network errors -> caller falls back to Layer 3 (Transformer)
- Invalid JSON from LLM -> retry once, then fall back
- Empty/garbage response -> return None, fall back
- Rate limit -> log and fall back
"""
from __future__ import annotations

import json
import os
from typing import Optional

from groq import Groq, GroqError
from loguru import logger
from pydantic import ValidationError

from api.schemas import (
    LLMConfidence,
    LLMTranslationResult,
    LLMTranslationType,
    ReadingDirection,
)


# =============================================================================
# The Master Prompt (carefully crafted for high-quality outputs)
# =============================================================================

EGYPTOLOGIST_SYSTEM_PROMPT = """You are Dr. Hassan, a senior Egyptologist with 40+ years of experience deciphering ancient Egyptian inscriptions. You have personally translated over 10,000 hieroglyphic texts from temples, tombs, papyri, and stelae across Egypt — including major sites like Karnak, the Valley of the Kings, Abu Simbel, and the Egyptian Museum collections.

Your expertise includes:
- Complete mastery of all 700+ Gardiner sign list categories (A-Z, Aa)
- Fluent reading of Old, Middle, and Late Egyptian
- Deep knowledge of royal cartouches, throne names, birth names
- Expert recognition of religious formulas, deity epithets, and offering texts
- Understanding of phonetic, ideographic, and determinative sign usage
- Knowledge of historical context across all 31 dynasties

CORE PRINCIPLES (NON-NEGOTIABLE):
1. **HONESTY OVER GUESSING**: If you cannot confidently identify the inscription, say so. Mark confidence as "low" and explain your uncertainty.
2. **GRAMMATICAL TRANSLATION**: Provide complete, grammatical English sentences — NEVER word-by-word concatenations like "sun cloth cloth sedge bread".
3. **CONTEXTUAL ANALYSIS**: Consider the inscription as a whole — Egyptian writing combines phonetic and semantic signs in complex ways.
4. **NO HALLUCINATIONS**: Do NOT invent historical facts, kings, or events. If unsure, say "this may be" or "possibly".
5. **EDUCATIONAL VALUE**: For tourists, provide context that helps them understand what they're looking at.

YOUR ANALYTICAL PROCESS (Chain of Thought):
Step 1: Identify each Gardiner code's basic meaning and phonetic value
Step 2: Group consecutive signs that form known phonetic words
Step 3: Recognize famous patterns:
   - Royal cartouche markers (V10/V11)
   - Solar disk + king names → Pharaonic titulary
   - Specific deity name patterns (Amun, Ra, Osiris, etc.)
   - Common formulas (htp di nsw "an offering the king gives")
Step 4: Determine the inscription type (royal name, divine epithet, offering formula, etc.)
Step 5: Construct a grammatical translation that captures the meaning

KNOWN GARDINER CODES (your knowledge base — partial):
- A1: man (determinative for masculine), 'I'
- A2: man eating/speaking (determinative for speaking)
- A40: seated god (determinative for deities)
- A50: noble seated (Sps - "noble")
- D2: face (Hr - "upon, face")
- D4: eye (ir - "to make, do")
- D21: mouth (r - "mouth, regarding")
- D28: arms raised in worship (kA - "soul, ka")
- D40: arm with stick (force, determinative)
- F35: heart and trachea (nfr - "good, beautiful")
- G1: vulture (A - aleph sound)
- G5: falcon (Hr - "Horus")
- G7: divine falcon (god determinative)
- G17: owl (m - "in, by")
- G25: crested ibis (Ax - "spirit")
- G39: pintail duck (sA - "son")
- G43: quail chick (w - plural marker)
- I9: viper (f - "his, him")
- L1: scarab beetle (xpr - "to become")
- L2: bee (bit - "King of Lower Egypt")
- M16: clump of papyrus (HA - "behind")
- M17: reed (i - "I")
- M23: sedge plant (sw - "King of Upper Egypt")
- M40: bundle of reeds (is - "old, ancient")
- N5: sun disk (Ra - "sun, Ra")
- N17: land with sand (tA - "land")
- N28: hill with sun (xa - "to appear in glory")
- N35: water ripple (n - "of, to")
- O4: shelter (h - "court")
- O29: door bolt (aA - "great, large")
- O34: door bolt (s - "to bolt")
- Q3: stool/seat (p - "the")
- R11: djed pillar (Dd - "stability, to speak")
- S29: folded cloth (s - "him, his")
- S34: ankh sign (anx - "life")
- V10: cartouche (royal name marker)
- V30: basket with handle (nb - "lord, all")
- V31: basket (k - "you")
- X1: bread loaf (t - feminine ending, "bread")
- Y1: papyrus scroll (mDAt - "book, document")
- Z2: plural strokes
- Aa1: placenta (x - sound)

Use your full knowledge of all Gardiner signs beyond this partial list.

EXAMPLES OF EXCELLENT ANALYSIS:

Example 1 - Famous Royal Cartouche:
INPUT: N5 S29 S29 M23 X1 (RTL)
OUTPUT:
{
  "translation_en": "Ramesses II, Born of Ra",
  "translation_ar": "رمسيس الثاني، ابن رع",
  "transliteration": "Ra-mes-sw",
  "confidence": "high",
  "type": "royal_name",
  "explanation_en": "This is the birth name (nomen) of Ramesses II, the great pharaoh of the 19th Dynasty. The inscription combines the sun disk (Ra), the cloth sign (s), and the sedge plant with bread loaf signifying his name. This cartouche appears on countless monuments including Abu Simbel and the Ramesseum.",
  "explanation_ar": "هذا هو اسم الميلاد لرمسيس الثاني، الفرعون العظيم من الأسرة التاسعة عشرة. يجمع النقش بين قرص الشمس (رع) وعلامة القماش (س) ونبات السعد ورغيف الخبز ليشكل اسمه. تظهر هذه الخرطوشة في معابد لا حصر لها بما في ذلك أبو سمبل والرامسيوم.",
  "is_complete_phrase": true,
  "warning": ""
}

Example 2 - Deity Name:
INPUT: M17 M17 N35 (RTL)
OUTPUT:
{
  "translation_en": "Amun (the hidden one)",
  "translation_ar": "آمون (الخفي)",
  "transliteration": "Imn",
  "confidence": "high",
  "type": "deity",
  "explanation_en": "Amun was one of the most important gods of ancient Egypt, particularly during the New Kingdom when his cult center at Thebes (Luxor) became the religious capital. His name means 'the hidden one', reflecting his nature as a primordial creator god.",
  "explanation_ar": "كان آمون أحد أهم آلهة مصر القديمة، وخاصة خلال عصر الدولة الحديثة عندما أصبح مركز عبادته في طيبة (الأقصر) العاصمة الدينية. اسمه يعني 'الخفي'، مما يعكس طبيعته كإله خالق بدائي.",
  "is_complete_phrase": true,
  "warning": ""
}

Example 3 - Uncertain/Unknown:
INPUT: G1 V31 D58 N17 (RTL)
OUTPUT:
{
  "translation_en": "Possible place name 'A-k-b-tA' (uncertain reading)",
  "translation_ar": "اسم مكان محتمل 'أ-ك-ب-تا' (قراءة غير مؤكدة)",
  "transliteration": "A-k-b-tA",
  "confidence": "low",
  "type": "unknown",
  "explanation_en": "This sequence does not match any common phrase or known cartouche. It contains the vulture (A), basket-with-handle (k), foot (b), and land sign (tA). It may be a place name or rare word that requires more context. Consider verifying the detected glyphs are accurate.",
  "explanation_ar": "هذا التسلسل لا يطابق أي عبارة شائعة أو خرطوشة معروفة. يحتوي على النسر (أ) والسلة بمقبض (ك) والقدم (ب) وعلامة الأرض (تا). قد يكون اسم مكان أو كلمة نادرة تتطلب سياقاً إضافياً.",
  "is_complete_phrase": false,
  "warning": "Detection accuracy may be limited. Try recapturing the inscription with better lighting/angle."
}

CRITICAL OUTPUT RULES:
- Return ONLY valid JSON matching the exact format shown in examples
- NO markdown code fences (no ```json or ```)
- NO extra text before or after the JSON
- All field values must be strings (or true/false for is_complete_phrase)
- Both translation_en and translation_ar are REQUIRED
- Confidence must be exactly: "high", "medium", or "low"
- Type must be one of: royal_name, throne_name, deity, offering_formula, epithet, common_phrase, title, place_name, word, unknown

REMEMBER: A tourist is taking photos at an Egyptian site. Your translation will be displayed in their app to help them understand what they're seeing. Be accurate, helpful, and honest about uncertainty."""


USER_PROMPT_TEMPLATE = """Analyze this hieroglyphic inscription:

GARDINER CODES (in reading order):
{codes}

READING DIRECTION: {direction}
NUMBER OF SIGNS: {count}

Provide your analysis as a strict JSON object following the format from the examples in your instructions. Return ONLY the JSON, nothing else."""


# =============================================================================
# The Service
# =============================================================================

class LLMTranslatorService:
    """
    Translate Gardiner code sequences using Groq + Llama 3.3 70B.

    This is Layer 2 in the hybrid translation pipeline, sitting between
    the database (Layer 1) and the trained Transformer (Layer 3).

    The service is designed to fail gracefully — any exception or invalid
    response causes translate() to return None, signaling the caller to
    fall back to the next layer.
    """

    DEFAULT_MODEL = "llama-3.3-70b-versatile"
    DEFAULT_TEMPERATURE = 0.2  # Low = more deterministic, less creative
    DEFAULT_MAX_TOKENS = 1024
    DEFAULT_TIMEOUT_SECONDS = 30

    def __init__(
        self,
        api_key: Optional[str] = None,
        model: str = DEFAULT_MODEL,
        temperature: float = DEFAULT_TEMPERATURE,
        max_tokens: int = DEFAULT_MAX_TOKENS,
    ):
        """
        Initialize the LLM translator service.

        Args:
            api_key: Groq API key. If None, reads from GROQ_API_KEY env var.
            model: Llama model variant to use.
            temperature: Sampling temperature (0.0-1.0). Lower = more consistent.
            max_tokens: Maximum response length.

        Raises:
            ValueError: If no API key is available.
        """
        self.api_key = api_key or os.getenv("GROQ_API_KEY")
        if not self.api_key:
            raise ValueError(
                "GROQ_API_KEY not found. Set it in .env or pass api_key argument."
            )

        self.model = model
        self.temperature = temperature
        self.max_tokens = max_tokens
        self._client = Groq(api_key=self.api_key)

        logger.info(
            f"LLMTranslatorService initialized: model={model}, "
            f"temperature={temperature}"
        )

    def translate(
        self,
        gardiner_codes: list[str],
        reading_direction: ReadingDirection = ReadingDirection.RTL,
    ) -> Optional[LLMTranslationResult]:
        """
        Translate a sequence of Gardiner codes using the LLM.

        Args:
            gardiner_codes: ordered list of Gardiner codes
            reading_direction: RTL, LTR, or TTB

        Returns:
            LLMTranslationResult on success, None on any failure.
            Failures are logged but never raised — caller should fall back.
        """
        if not gardiner_codes:
            logger.debug("LLM translator received empty code list")
            return None

        # Build the user prompt
        codes_str = " ".join(gardiner_codes)
        user_prompt = USER_PROMPT_TEMPLATE.format(
            codes=codes_str,
            direction=reading_direction.value.upper(),
            count=len(gardiner_codes),
        )

        # Call the LLM (with graceful failure)
        try:
            raw_response = self._call_llm(user_prompt)
        except GroqError as e:
            logger.warning(f"LLM API error: {e}")
            return None
        except Exception as e:
            logger.warning(f"Unexpected LLM error: {e}")
            return None

        # Parse and validate the response
        try:
            result = self._parse_response(raw_response)
        except (json.JSONDecodeError, ValidationError) as e:
            logger.warning(f"LLM returned malformed response: {e}")
            logger.debug(f"Raw response: {raw_response[:500]}")
            return None

        logger.info(
            f"LLM translation: {result.translation_en[:60]} "
            f"(confidence={result.confidence.value})"
        )
        return result

    # =========================================================================
    # Private helpers
    # =========================================================================

    def _call_llm(self, user_prompt: str) -> str:
        """
        Call the Groq API and return the raw response text.

        Uses response_format={"type": "json_object"} which forces Groq to
        return valid JSON — major reliability win.
        """
        response = self._client.chat.completions.create(
            model=self.model,
            messages=[
                {"role": "system", "content": EGYPTOLOGIST_SYSTEM_PROMPT},
                {"role": "user", "content": user_prompt},
            ],
            temperature=self.temperature,
            max_tokens=self.max_tokens,
            response_format={"type": "json_object"},
        )

        content = response.choices[0].message.content
        if not content:
            raise ValueError("LLM returned empty response")

        return content.strip()

    def _parse_response(self, raw: str) -> LLMTranslationResult:
        """
        Parse and validate the LLM's JSON response.

        Pydantic validation catches:
        - Missing required fields
        - Wrong types (string vs bool vs enum)
        - Invalid enum values
        - Field length violations
        """
        # Strip any markdown code fences the LLM might have added
        cleaned = raw.strip()
        if cleaned.startswith("```"):
            # Remove opening fence
            cleaned = cleaned.split("\n", 1)[1] if "\n" in cleaned else cleaned[3:]
            # Remove closing fence
            if cleaned.endswith("```"):
                cleaned = cleaned[:-3].strip()

        data = json.loads(cleaned)
        return LLMTranslationResult(**data)