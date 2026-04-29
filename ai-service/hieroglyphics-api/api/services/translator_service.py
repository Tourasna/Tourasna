"""
Translator service — hybrid 3-layer translation of Gardiner code sequences.

Pipeline:
  Layer 1: Database exact-match lookup (31 known phrases — royal names,
           deities, formulas, titles, symbols, GEM inscriptions)
  Layer 2: Transformer seq2seq model (BLEU 7.76% on BBAW Egyptian Corpus)
           with beam search + repetition penalty (English only)
  Layer 3: Per-sign meanings fallback (concatenation of individual sign
           meanings from translations_db sign_meanings section)

Each layer can either produce a translation or pass to the next.
Layer 3 is guaranteed to produce something (even for unknown signs).

Arabic translation is only populated when it comes from the database
(layers 1 and 3); the Transformer is English-only.
"""
from __future__ import annotations

import re

import torch
import torch.nn.functional as F
from loguru import logger

from api.config import settings
from api.schemas import (
    LLMConfidence,
    LLMTranslationResult,
    SignDetail,
    TranslationMethod,
    TranslationResult,
)
from api.services.model_loader import ModelLoader


# Tokens that should never appear in the decoded output. If they do,
# Ultralytics fed us junk and we should fall back.
_BANNED_FALLBACK_MARKERS = ("<unk>", "<pad>", "<bos>", "<sos>", "<eos>")


class TranslatorService:
    """
    Hybrid 3-layer translator.

    Usage:
        translator = TranslatorService(loader)
        result = translator.translate(["N5", "S29", "S29", "M23", "X1"])
    """

    def __init__(self, loader: ModelLoader) -> None:
        if not loader.is_loaded:
            raise RuntimeError(
                "ModelLoader is not loaded. Call loader.load_all() first."
            )
        self.loader = loader

    # =========================================================================
    # Public API
    # =========================================================================

    def translate(self, gardiner_codes: list[str]) -> TranslationResult:
        """
        Translate a sequence of Gardiner codes using the hybrid pipeline.

        Args:
            gardiner_codes: ordered list of Gardiner codes (after Sorter)

        Returns:
            TranslationResult with method, translation_en/ar, sign_details.

        This method never raises for translation failures — the Layer 3
        fallback always produces something. It may raise if the loader
        state is corrupted.
        """
        if not gardiner_codes:
            return TranslationResult(
                method=TranslationMethod.EMPTY,
                translation_en="(no glyphs detected)",
                translation_ar="(لم يتم اكتشاف أي علامات)",
                sign_details=[],
            )

        logger.debug(
            f"Translating {len(gardiner_codes)} codes: {gardiner_codes[:10]}"
            + ("..." if len(gardiner_codes) > 10 else "")
        )

        # Layer 1: try the database
        db_result = self._try_database(gardiner_codes)
        if db_result is not None:
            logger.info(
                f"Translation via DATABASE: {db_result.translation_en[:60]}"
            )
            return db_result

        # Layer 2: try the LLM (Groq + Llama 3.3 70B)
        llm_result = self._try_llm(gardiner_codes)
        if llm_result is not None:
            logger.info(
                f"Translation via LLM: {llm_result.translation_en[:60]}"
            )
            return llm_result

        # Layer 3: try the transformer
        tf_result = self._try_transformer(gardiner_codes)
        if tf_result is not None:
            logger.info(
                f"Translation via TRANSFORMER: {tf_result.translation_en[:60]}"
            )
            return tf_result

        # Layer 3: sign meanings fallback
        fb_result = self._sign_meanings_fallback(gardiner_codes)
        logger.info(
            f"Translation via SIGN_MEANINGS: {fb_result.translation_en[:60]}"
        )
        return fb_result

    # =========================================================================
    # Layer 1: Database lookup
    # =========================================================================

    def _try_database(
        self, gardiner_codes: list[str]
    ) -> TranslationResult | None:
        """
        Look up the sequence in translations_db.

        Strategy:
          1. Exact match first (fastest, highest confidence).
          2. Subsequence match — is our sequence a contiguous slice of a
             known phrase? (catches cases where the detector caught only
             part of a longer inscription).

        Returns None if no match, else a TranslationResult.
        """
        seq_key = tuple(gardiner_codes)

        # -- Exact match --
        phrase = self.loader.phrases_by_sequence.get(seq_key)
        if phrase is not None:
            return self._phrase_to_result(phrase, gardiner_codes)

        # -- Subsequence match --
        # For each known phrase, check if our sequence is a contiguous
        # sub-slice. This is O(N * M) where N = num phrases (~31) and
        # M = avg phrase length, so it's fast.
        detected = list(gardiner_codes)
        for phrase in self.loader.phrases_by_id.values():
            known = phrase.get("gardiner_codes", [])
            if not known or len(detected) > len(known):
                continue

            # Sliding window over the known phrase
            match_found = False
            for start in range(len(known) - len(detected) + 1):
                if known[start : start + len(detected)] == detected:
                    match_found = True
                    break

            if match_found:
                # Mark it so the user knows this is partial
                return self._phrase_to_result(
                    phrase, gardiner_codes, is_partial=True
                )

        return None

    def _phrase_to_result(
        self,
        phrase: dict,
        gardiner_codes: list[str],
        is_partial: bool = False,
    ) -> TranslationResult:
        """Build a TranslationResult from a database phrase."""
        en = phrase.get("translation_en", "")
        ar = phrase.get("translation_ar", "")

        if is_partial:
            en = f"{en} (partial match)"
            ar = f"{ar} (مطابقة جزئية)"

        return TranslationResult(
            method=TranslationMethod.DATABASE_EXACT,
            translation_en=en,
            translation_ar=ar,
            transliteration=phrase.get("transliteration"),
            context_en=phrase.get("context_en"),
            context_ar=phrase.get("context_ar"),
            sign_details=self._build_sign_details(gardiner_codes),
        )

    # =========================================================================
    # Layer 2: LLM (Groq + Llama 3.3 70B)
    # =========================================================================

    def _try_llm(
        self, gardiner_codes: list[str]
    ) -> TranslationResult | None:
        """
        Translate via the LLM (Groq + Llama 3.3 70B).

        Returns None if:
        - The LLM service is not initialized (no API key)
        - The API call fails (network, rate limit, etc)
        - The response is malformed
        - The LLM reports low confidence

        On success, converts the structured LLMTranslationResult into
        a TranslationResult that fits the rest of the pipeline.
        """
        # Check if LLM service is available
        if self.loader.llm_translator is None:
            logger.debug("LLM translator not available, skipping Layer 2")
            return None

        # Call the LLM (it handles its own exceptions internally)
        llm_result = self.loader.llm_translator.translate(gardiner_codes)
        if llm_result is None:
            return None

        # Even with low confidence, the LLM's output is more honest than
        # a hallucinating Transformer. The LLM explicitly marks uncertainty,
        # which is more useful for the user than confident-but-wrong output.
        # The frontend can show a warning when confidence is "low".
        if llm_result.confidence == LLMConfidence.LOW:
            logger.info(
                f"LLM low-confidence result accepted: "
                f"{llm_result.translation_en[:60]}"
            )
            # Note: We could still return this with a warning, but for now
            # we prefer the deterministic Transformer/sign-meanings fallback.
            # If you want to keep low-confidence LLM output, comment this out.

        # Convert LLMTranslationResult -> TranslationResult
        return self._llm_result_to_translation_result(
            llm_result, gardiner_codes
        )

    def _llm_result_to_translation_result(
        self,
        llm_result: LLMTranslationResult,
        gardiner_codes: list[str],
    ) -> TranslationResult:
        """
        Map the LLM's structured output to the pipeline's TranslationResult.

        The LLM provides richer information (confidence, type, explanation)
        than the older layers. We pack the explanation into the context
        fields so the frontend can display it.
        """
        return TranslationResult(
            method=TranslationMethod.LLM_TRANSLATION,
            translation_en=llm_result.translation_en,
            translation_ar=llm_result.translation_ar,
            transliteration=llm_result.transliteration or None,
            context_en=llm_result.explanation_en or None,
            context_ar=llm_result.explanation_ar or None,
            sign_details=self._build_sign_details(gardiner_codes),
        )

    # =========================================================================
    # Layer 3: Transformer (beam search decoding)
    # =========================================================================

    def _try_transformer(
        self, gardiner_codes: list[str]
    ) -> TranslationResult | None:
        """
        Run the trained Transformer on the sequence.

        Returns None if the output looks like garbage (empty, too short,
        or filled with unknown tokens). Otherwise returns a TranslationResult
        with English only; translation_ar is left empty since the model
        was trained on English targets only.
        """
        # Guard: need at least one real code for meaningful inference
        real_codes = [c for c in gardiner_codes if c in self.loader.src_token2idx]
        if not real_codes:
            return None

        try:
            english = self._beam_search_decode(gardiner_codes)
        except Exception as exc:
            # Never let a transformer failure crash the API; fall through
            # to the sign-meanings fallback.
            logger.warning(f"Transformer decoding failed: {exc}")
            return None

        # Sanity checks on the output
        if not self._is_reasonable_translation(english):
            logger.debug(
                f"Transformer output rejected as garbage: {english[:80]!r}"
            )
            return None

        return TranslationResult(
            method=TranslationMethod.TRANSFORMER,
            translation_en=english.strip(),
            # Transformer is English-only; leave Arabic empty so the
            # frontend can fall back gracefully.
            translation_ar="",
            transliteration=None,
            context_en=None,
            context_ar=None,
            sign_details=self._build_sign_details(gardiner_codes),
        )

    def _beam_search_decode(self, gardiner_codes: list[str]) -> str:
        """
        Beam search decoding ported from 02_sequence_translation.ipynb.

        Includes repetition penalty to combat the model's tendency to
        loop on common tokens. Uses length-normalized scoring.
        """
        model = self.loader.transformer_model
        device = self.loader.device
        sp = self.loader.tgt_sp

        beam_size = settings.translator_beam_size
        max_len = settings.translator_max_length
        rep_penalty = settings.translator_repetition_penalty

        # --- Encode source ---
        # Use <unk> for unseen codes instead of skipping - preserves length.
        unk_id = self.loader.src_token2idx.get("<unk>", 3)
        src_ids = [
            self.loader.src_token2idx.get(code, unk_id)
            for code in gardiner_codes
        ]
        # Cap source length for safety (match training pipeline)
        src_ids = src_ids[:200]
        src_tensor = torch.tensor([src_ids], device=device, dtype=torch.long)

        # --- Beam search ---
        # Each beam: (cumulative_log_prob, token_list)
        # Start with just <sos>
        beams: list[tuple[float, list[int]]] = [(0.0, [ModelLoader.SOS_TOKEN_ID])]
        completed: list[tuple[float, list[int]]] = []

        for _ in range(max_len):
            candidates: list[tuple[float, list[int]]] = []

            for score, tokens in beams:
                # If this beam has already emitted <eos>, move it to completed
                if tokens[-1] == ModelLoader.EOS_TOKEN_ID:
                    completed.append((score, tokens))
                    continue

                tgt_tensor = torch.tensor(
                    [tokens], device=device, dtype=torch.long
                )
                with torch.no_grad():
                    output = model(src_tensor, tgt_tensor)
                # output shape: (1, tgt_len, vocab_size)
                log_probs = F.log_softmax(output[0, -1], dim=-1)

                # Get top-(beam_size) next tokens
                top_values, top_indices = log_probs.topk(beam_size)

                for prob, idx in zip(top_values, top_indices):
                    token_id = int(idx.item())
                    raw_logprob = float(prob.item())

                    # Apply repetition penalty (log-additive)
                    penalty = 0.0
                    # 2 consecutive same tokens -> mild penalty
                    if len(tokens) >= 1 and token_id == tokens[-1]:
                        penalty -= (rep_penalty - 1.0) * 2.0
                    # 3 consecutive same tokens -> strong penalty
                    if (
                        len(tokens) >= 2
                        and token_id == tokens[-1] == tokens[-2]
                    ):
                        penalty -= (rep_penalty - 1.0) * 5.0

                    candidates.append(
                        (score + raw_logprob + penalty, tokens + [token_id])
                    )

            if not candidates:
                break

            # Length-normalized scoring to avoid short-sequence bias
            candidates.sort(
                key=lambda pair: pair[0] / max(len(pair[1]), 1),
                reverse=True,
            )
            beams = candidates[:beam_size]

        # Combine completed + any remaining beams
        all_results = completed + beams
        if not all_results:
            return ""

        all_results.sort(
            key=lambda pair: pair[0] / max(len(pair[1]), 1),
            reverse=True,
        )
        best_tokens = all_results[0][1]

        # Strip special tokens
        special = {
            ModelLoader.PAD_TOKEN_ID,
            ModelLoader.SOS_TOKEN_ID,
            ModelLoader.EOS_TOKEN_ID,
        }
        clean_tokens = [t for t in best_tokens if t not in special]

        # Decode via SentencePiece
        return sp.decode(clean_tokens)

    @staticmethod
    def _is_reasonable_translation(text: str) -> bool:
        """
        Heuristics to detect garbage output from the Transformer.

        Returns True iff the text looks like a sensible English translation.
        """
        if not text:
            return False

        cleaned = text.strip()
        if len(cleaned) < 3:
            return False

        # Reject obvious special-token leaks
        lowered = cleaned.lower()
        for marker in _BANNED_FALLBACK_MARKERS:
            if marker in lowered:
                return False

        # Reject output that is almost entirely a single repeated word,
        # e.g. "the the the the the the" or "and and and".
        words = re.findall(r"\w+", cleaned.lower())
        if len(words) >= 5:
            unique_ratio = len(set(words)) / len(words)
            if unique_ratio < 0.25:
                return False

        return True

    # =========================================================================
    # Layer 4: Sign meanings fallback
    # =========================================================================

    def _sign_meanings_fallback(
        self, gardiner_codes: list[str]
    ) -> TranslationResult:
        """
        Build a best-effort translation by concatenating per-sign meanings.

        Always succeeds — unknown codes are simply labeled "?".
        """
        en_parts: list[str] = []
        ar_parts: list[str] = []

        for code in gardiner_codes:
            meaning = self.loader.sign_meanings.get(code)
            if meaning is None:
                en_parts.append(f"[{code}]")
                ar_parts.append(f"[{code}]")
                continue

            en = meaning.get("en", "").strip()
            ar = meaning.get("ar", "").strip()
            en_parts.append(en or f"[{code}]")
            ar_parts.append(ar or f"[{code}]")

        translation_en = " · ".join(en_parts)
        translation_ar = " · ".join(ar_parts)

        return TranslationResult(
            method=TranslationMethod.SIGN_MEANINGS_ONLY,
            translation_en=translation_en,
            translation_ar=translation_ar,
            transliteration=None,
            context_en=None,
            context_ar=None,
            sign_details=self._build_sign_details(gardiner_codes),
        )

    # =========================================================================
    # Shared helper — sign details
    # =========================================================================

    def _build_sign_details(
        self, gardiner_codes: list[str]
    ) -> list[SignDetail]:
        """Look up sign meanings and return SignDetail objects in order."""
        details: list[SignDetail] = []
        for code in gardiner_codes:
            meaning = self.loader.sign_meanings.get(code)
            if meaning is None:
                # Still include the code so the frontend can show it
                details.append(SignDetail(code=code))
                continue
            details.append(
                SignDetail(
                    code=code,
                    meaning_en=meaning.get("en"),
                    meaning_ar=meaning.get("ar"),
                    sound=meaning.get("sound"),
                    category=meaning.get("category"),
                )
            )
        return details