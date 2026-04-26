"""
Model loader for the Hieroglyphics Translator API.

Responsible for loading all ML models and data files once at startup,
then exposing them as a singleton for the services to use.

Loads:
  - YOLOv8 detector (best.pt)
  - Transformer translator (best_translator.pth + vocab + BPE)
  - Translations database (translations_db.json)

Device is auto-detected (CUDA if available, CPU otherwise) or can be
explicitly set via the DEVICE environment variable.
"""
from __future__ import annotations

import json
import time
from typing import Any, Optional

import sentencepiece as spm
import torch
from loguru import logger
from ultralytics import YOLO

from api.config import settings
from api.services.transformer_model import HieroglyphTranslator
from api.services.sign_info_service import SignInfoService


class ModelLoader:
    """
    Singleton model loader. Call `load_all()` once at FastAPI startup
    (from the lifespan context manager in main.py).

    After loading, access models via attributes:
        loader.yolo_model          # Ultralytics YOLO instance
        loader.gardiner_class_names # dict[int, str]  (YOLO class ID -> Gardiner code)
        loader.transformer_model   # HieroglyphTranslator instance (eval mode)
        loader.src_token2idx       # dict[str, int]
        loader.idx2src_token       # dict[int, str]
        loader.tgt_sp              # sentencepiece.SentencePieceProcessor
        loader.translator_metadata # dict from metadata.json
        loader.translations_db     # dict from translations_db.json
        loader.phrases_by_sequence # dict[tuple[str,...], dict]  (lookup index)
        loader.phrases_by_id       # dict[str, dict]             (lookup index)
        loader.sign_meanings       # dict[str, dict]             (convenience alias)
        loader.device              # torch.device
        loader.is_loaded           # bool
    """

    # Special token IDs from the training pipeline (02_sequence_translation.ipynb)
    PAD_TOKEN_ID = 0
    SOS_TOKEN_ID = 1
    EOS_TOKEN_ID = 2
    UNK_TOKEN_ID = 3

    def __init__(self) -> None:
        # Resolve device based on config.
        # 'auto' -> CUDA if available else CPU.
        # 'cuda' -> force CUDA (will fail fast if not available).
        # 'cpu'  -> force CPU.
        self.device: torch.device = self._resolve_device(settings.device)

        # Placeholders - populated by load_all()
        # ===== Detector =====
        self.yolo_model: Optional[YOLO] = None
        self.gardiner_class_names: dict[int, str] = {}

        # ===== Translator =====
        self.transformer_model: Optional[HieroglyphTranslator] = None
        self.src_token2idx: Optional[dict[str, int]] = None
        self.idx2src_token: Optional[dict[int, str]] = None
        self.tgt_sp: Optional[spm.SentencePieceProcessor] = None
        self.translator_metadata: Optional[dict] = None

        # ===== Translations DB =====
        self.translations_db: Optional[dict] = None
        self.phrases_by_sequence: dict[tuple[str, ...], dict] = {}
        self.phrases_by_id: dict[str, dict] = {}
        self.sign_meanings: dict[str, dict] = {}

        self.sign_info_service: Optional[SignInfoService] = None

        self.is_loaded: bool = False

    @staticmethod
    def _resolve_device(device_setting: str) -> torch.device:
        """Decide which torch device to use based on the config string."""
        setting = device_setting.lower().strip()

        if setting == "auto":
            if torch.cuda.is_available():
                device = torch.device("cuda")
                logger.info(
                    f"Device auto-detected: CUDA "
                    f"({torch.cuda.get_device_name(0)})"
                )
            else:
                device = torch.device("cpu")
                logger.info("Device auto-detected: CPU (no CUDA available)")
            return device

        if setting == "cuda":
            if not torch.cuda.is_available():
                raise RuntimeError(
                    "Config requested device='cuda' but CUDA is not available. "
                    "Set DEVICE=auto or DEVICE=cpu in your .env."
                )
            logger.info(f"Device forced: CUDA ({torch.cuda.get_device_name(0)})")
            return torch.device("cuda")

        if setting == "cpu":
            logger.info("Device forced: CPU")
            return torch.device("cpu")

        raise ValueError(
            f"Invalid DEVICE setting: {device_setting!r}. "
            f"Must be one of: 'auto', 'cuda', 'cpu'."
        )

    # =========================================================================
    # Loader methods (called from load_all)
    # =========================================================================

    def _load_translations_db(self) -> None:
        """
        Load translations_db.json and build fast lookup indexes.

        Builds two in-memory indexes:
          - phrases_by_sequence: O(1) lookup by tuple of Gardiner codes
          - phrases_by_id: O(1) lookup by phrase ID (for debugging/testing)
        Also exposes sign_meanings directly as a convenience.
        """
        db_path = settings.translations_db_path
        logger.info(f"Loading translations database from: {db_path}")

        if not db_path.exists():
            raise FileNotFoundError(
                f"Translations database not found at {db_path}. "
                f"Make sure data/translations_db.json exists."
            )

        with open(db_path, "r", encoding="utf-8") as f:
            db = json.load(f)

        # Validate top-level structure - fail fast if the schema changes
        required_keys = ("phrases", "sign_meanings")
        for key in required_keys:
            if key not in db:
                raise ValueError(
                    f"Translations DB is missing required key: {key!r}. "
                    f"Found keys: {list(db.keys())}"
                )

        # Store the raw DB for metadata access (version, description, etc.)
        self.translations_db = db

        # Build phrase lookup indexes
        phrases = db["phrases"]
        if not isinstance(phrases, list):
            raise ValueError(
                f"'phrases' must be a list, got {type(phrases).__name__}"
            )

        for idx, phrase in enumerate(phrases):
            # Validate each phrase has the required fields
            phrase_id = phrase.get("id")
            codes = phrase.get("gardiner_codes")

            if not phrase_id:
                logger.warning(f"Phrase at index {idx} has no 'id' - skipping")
                continue
            if not isinstance(codes, list) or not codes:
                logger.warning(
                    f"Phrase {phrase_id!r} has invalid 'gardiner_codes' - skipping"
                )
                continue

            # Index by ID
            if phrase_id in self.phrases_by_id:
                logger.warning(
                    f"Duplicate phrase ID {phrase_id!r} - overwriting previous entry"
                )
            self.phrases_by_id[phrase_id] = phrase

            # Index by sequence (tuple so it's hashable)
            seq_key = tuple(codes)
            if seq_key in self.phrases_by_sequence:
                existing_id = self.phrases_by_sequence[seq_key].get("id", "?")
                logger.warning(
                    f"Duplicate sequence {list(seq_key)} for phrases "
                    f"{existing_id!r} and {phrase_id!r} - keeping first."
                )
                continue
            self.phrases_by_sequence[seq_key] = phrase

        # Store sign meanings as a direct alias for convenience
        sign_meanings = db["sign_meanings"]
        if not isinstance(sign_meanings, dict):
            raise ValueError(
                f"'sign_meanings' must be a dict, got {type(sign_meanings).__name__}"
            )
        self.sign_meanings = sign_meanings

        # Summary logs
        logger.info(
            f"  Loaded {len(self.phrases_by_id)} phrases, "
            f"{len(self.sign_meanings)} sign meanings "
            f"(DB version: {db.get('version', 'unknown')})"
        )

        # Log phrase type breakdown - useful for verifying coverage
        type_counts: dict[str, int] = {}
        for phrase in self.phrases_by_id.values():
            ptype = phrase.get("type", "unknown")
            type_counts[ptype] = type_counts.get(ptype, 0) + 1
        breakdown = ", ".join(f"{t}={n}" for t, n in sorted(type_counts.items()))
        logger.info(f"  Phrase types: {breakdown}")

    def _load_detector(self) -> None:
        """
        Load the YOLOv8 detector model (best.pt).

        The detector does BOTH detection (bounding boxes) and
        classification (767 Gardiner codes) in one pass.
        """
        weights_path = settings.detector_weights
        logger.info(f"Loading YOLO detector from: {weights_path}")

        if not weights_path.exists():
            raise FileNotFoundError(
                f"Detector weights not found at {weights_path}. "
                f"Make sure models/detector/best.pt exists."
            )

        start = time.time()

        # Ultralytics YOLO class handles architecture + weights in one call.
        # str() because YOLO expects a string path, not a pathlib.Path.
        self.yolo_model = YOLO(str(weights_path))

        # Move to the target device.
        # On CPU this is a no-op for YOLO (it reads the device from inputs),
        # but setting it explicitly makes our behavior consistent.
        self.yolo_model.to(self.device)

        # Extract class names mapping: {class_id: "N5", class_id: "S29", ...}
        # These are the Gardiner codes from training.
        names = self.yolo_model.names  # dict[int, str] in recent Ultralytics versions
        if isinstance(names, dict):
            self.gardiner_class_names = {int(k): str(v) for k, v in names.items()}
        elif isinstance(names, list):
            # Older Ultralytics versions use a list
            self.gardiner_class_names = {i: str(v) for i, v in enumerate(names)}
        else:
            raise TypeError(
                f"Unexpected type for YOLO class names: {type(names).__name__}"
            )

        # Sanity check: we trained on 767 Gardiner classes
        num_classes = len(self.gardiner_class_names)
        if num_classes == 0:
            raise RuntimeError("YOLO model loaded but has no class names.")

        elapsed = time.time() - start
        logger.info(
            f"  Detector loaded in {elapsed:.2f}s "
            f"({num_classes} classes, device={self.device})"
        )

        # Log a few sample class names for visual verification
        sample_codes = [
            self.gardiner_class_names[i]
            for i in sorted(self.gardiner_class_names)[:5]
        ]
        logger.info(f"  Sample Gardiner codes: {sample_codes}")

    def _load_translator(self) -> None:
        """
        Load the Transformer translator (architecture + weights + tokenizers).

        Four files are needed, all in models/translator/:
          - metadata.json: hyperparameters (d_model, nhead, layers, vocab sizes)
          - src_vocab.json: {Gardiner code: token ID}
          - tgt_bpe.model: SentencePiece BPE tokenizer (English target)
          - best_translator.pth: state_dict (weights only, no architecture)
        """
        logger.info("Loading Transformer translator...")
        start = time.time()

        # --- 1. Load metadata (hyperparameters) ---
        meta_path = settings.translator_metadata
        logger.info(f"  Reading metadata: {meta_path}")
        if not meta_path.exists():
            raise FileNotFoundError(f"Translator metadata not found: {meta_path}")
        with open(meta_path, "r", encoding="utf-8") as f:
            self.translator_metadata = json.load(f)

        meta = self.translator_metadata
        required_meta_keys = (
            "d_model", "nhead", "encoder_layers", "decoder_layers",
            "src_vocab_size", "tgt_vocab_size",
        )
        for key in required_meta_keys:
            if key not in meta:
                raise ValueError(
                    f"Translator metadata missing required key: {key!r}"
                )

        # --- 2. Load source vocabulary (Gardiner code -> ID) ---
        src_vocab_path = settings.translator_src_vocab
        logger.info(f"  Reading source vocab: {src_vocab_path}")
        if not src_vocab_path.exists():
            raise FileNotFoundError(f"Source vocab not found: {src_vocab_path}")
        with open(src_vocab_path, "r", encoding="utf-8") as f:
            src_vocab_raw = json.load(f)

        # Normalize to dict[str, int]. Some exports wrap it; handle common shapes.
        # The source vocab file wraps the mapping in "src_token2idx".
        # Shape: {"src_token2idx": {token: id}, "src_vocab": [tokens...]}
        # We only need the dict; the list is redundant.
        if not isinstance(src_vocab_raw, dict):
            raise TypeError(
                f"src_vocab.json must be a JSON object, got {type(src_vocab_raw).__name__}"
            )

        if "src_token2idx" in src_vocab_raw:
            # Expected nested shape from the training notebook
            token_map = src_vocab_raw["src_token2idx"]
        else:
            # Fallback: assume flat {token: id} shape
            token_map = src_vocab_raw

        if not isinstance(token_map, dict):
            raise TypeError(
                f"src_token2idx must be a dict, got {type(token_map).__name__}"
            )

        self.src_token2idx = {str(k): int(v) for k, v in token_map.items()}

        # Build reverse mapping for decoding (rarely needed, but cheap)
        self.idx2src_token = {v: k for k, v in self.src_token2idx.items()}

        # Verify vocab size matches metadata - catches corrupted files early
        if len(self.src_token2idx) != meta["src_vocab_size"]:
            logger.warning(
                f"  Source vocab size mismatch: file has {len(self.src_token2idx)} "
                f"entries but metadata says {meta['src_vocab_size']}. "
                f"Using file size."
            )

        # Verify essential special tokens exist
        for special in ("<pad>", "<sos>", "<eos>", "<unk>"):
            if special not in self.src_token2idx:
                logger.warning(
                    f"  Special token {special!r} not found in src_vocab. "
                    f"Translation may fail on unknown Gardiner codes."
                )

        # --- 3. Load SentencePiece BPE tokenizer (target English) ---
        bpe_path = settings.translator_tgt_bpe
        logger.info(f"  Loading target BPE: {bpe_path}")
        if not bpe_path.exists():
            raise FileNotFoundError(f"Target BPE model not found: {bpe_path}")

        self.tgt_sp = spm.SentencePieceProcessor()
        self.tgt_sp.load(str(bpe_path))

        tgt_vocab_size_actual = self.tgt_sp.get_piece_size()
        if tgt_vocab_size_actual != meta["tgt_vocab_size"]:
            logger.warning(
                f"  Target vocab size mismatch: BPE has {tgt_vocab_size_actual} "
                f"pieces but metadata says {meta['tgt_vocab_size']}."
            )

        # --- 4. Instantiate the Transformer and load weights ---
        weights_path = settings.translator_weights
        logger.info(f"  Loading translator weights: {weights_path}")
        if not weights_path.exists():
            raise FileNotFoundError(f"Translator weights not found: {weights_path}")

        self.transformer_model = HieroglyphTranslator(
            src_vocab_size=len(self.src_token2idx),
            tgt_vocab_size=tgt_vocab_size_actual,
            d_model=meta["d_model"],
            nhead=meta["nhead"],
            num_encoder_layers=meta["encoder_layers"],
            num_decoder_layers=meta["decoder_layers"],
            # dim_ff and dropout aren't in metadata.json; use training defaults
            # (confirmed from 02_sequence_translation.ipynb: dim_ff=1024)
            dim_ff=1024,
            dropout=0.0,  # dropout off for inference
        )

        # Load the state_dict. weights_only=True is the modern safe default
        # (available in PyTorch 2.1+). Keeps us from executing arbitrary
        # pickled code if the checkpoint file were ever replaced by something malicious.
        state_dict = torch.load(
            str(weights_path),
            map_location=self.device,
            weights_only=True,
        )
        self.transformer_model.load_state_dict(state_dict)

        # Move to device, flip to eval mode (disables dropout, batchnorm stats)
        self.transformer_model.to(self.device)
        self.transformer_model.eval()

        # Sanity check: parameter count should match metadata
        num_params = sum(p.numel() for p in self.transformer_model.parameters())
        expected_params = meta.get("total_params")
        if expected_params and num_params != expected_params:
            logger.warning(
                f"  Parameter count mismatch: got {num_params:,} "
                f"but metadata expects {expected_params:,}"
            )

        elapsed = time.time() - start
        logger.info(
            f"  Translator loaded in {elapsed:.2f}s "
            f"({num_params:,} params, src_vocab={len(self.src_token2idx)}, "
            f"tgt_vocab={tgt_vocab_size_actual})"
        )



    def _load_sign_info(self) -> None:
        """
        Load the SignInfoService for interactive correction support.

        Combines basic sign info from translations_db.json (already loaded)
        with extended info from sign_extended_info.json (confusions, examples).
        """
        logger.info("Loading SignInfoService...")
        start = time.time()

        translations_path = settings.translations_db_path
        extended_path = settings.translations_db_path.parent / "sign_extended_info.json"

        self.sign_info_service = SignInfoService(
            translations_db_path=translations_path,
            extended_info_path=extended_path,
        )

        elapsed = time.time() - start
        logger.info(
            f"  SignInfoService loaded in {elapsed:.2f}s "
            f"({self.sign_info_service.total_signs} signs)"
        )

    # =========================================================================
    # Orchestrator
    # =========================================================================

    def load_all(self) -> None:
        """
        Load every model and data file. Call once at startup.

        Raises on any failure - we never want to serve requests with
        a partially-loaded pipeline.
        """
        if self.is_loaded:
            logger.warning("load_all() called more than once; skipping reload.")
            return

        logger.info("=" * 60)
        logger.info("Loading Hieroglyphics Translator pipeline...")
        logger.info(f"Device: {self.device}")
        logger.info("=" * 60)

        self._load_translations_db()
        self._load_detector()
        self._load_translator()
        self._load_sign_info()

        self.is_loaded = True
        logger.info("=" * 60)
        logger.info("Pipeline loaded successfully. API is ready.")
        logger.info("=" * 60)


# Module-level singleton instance.
# Import this in main.py and call loader.load_all() from the lifespan.
loader = ModelLoader()