"""
Central configuration for the Hieroglyphics Translator API.
All paths, thresholds, and settings live here - nothing hardcoded elsewhere.
"""
from pathlib import Path
from pydantic_settings import BaseSettings, SettingsConfigDict


# Project root (ai-service/hieroglyphics-api/)
BASE_DIR = Path(__file__).resolve().parent.parent


class Settings(BaseSettings):
    """Application settings, loaded from environment variables or .env file."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ===== API Metadata =====
    app_name: str = "Tourasna Hieroglyphics Translator"
    app_version: str = "1.0.0"
    app_description: str = (
        "AI-powered hieroglyphic inscription translator. "
        "Detects, classifies, and translates ancient Egyptian glyphs "
        "into English and Arabic."
    )

    # ===== Server =====
    host: str = "0.0.0.0"
    port: int = 8000
    debug: bool = False

    # ===== Model Paths =====
    # Note: Models are NOT in the repo. Download from Google Drive and place here.
    models_dir: Path = BASE_DIR / "models"
    detector_weights: Path = models_dir / "detector" / "best.pt"
    translator_weights: Path = models_dir / "translator" / "best_translator.pth"
    translator_src_vocab: Path = models_dir / "translator" / "src_vocab.json"
    translator_tgt_bpe: Path = models_dir / "translator" / "tgt_bpe.model"
    translator_metadata: Path = models_dir / "translator" / "metadata.json"

    # ===== Data Paths =====
    data_dir: Path = BASE_DIR / "data"
    translations_db_path: Path = data_dir / "translations_db.json"

    # ===== Detector Settings =====
    detector_conf_threshold: float = 0.25  # Minimum confidence to keep a detection
    detector_iou_threshold: float = 0.45   # NMS IOU threshold
    detector_image_size: int = 640          # YOLO input size
    detector_max_detections: int = 300      # Safety cap per image

    # ===== Ambiguity Settings =====
    # A detection is "ambiguous" if its top confidence is below this threshold.
    # When ambiguous, we return top-k alternatives so the tourist can correct it.
    ambiguity_threshold: float = 0.60
    ambiguity_top_k: int = 3

    # ===== Sorter Settings (Quadrat-based reading order) =====
    sorter_row_threshold_ratio: float = 0.5
    sorter_x_overlap_ratio: float = 0.4
    sorter_default_direction: str = "rtl"  # 'rtl' or 'ltr'

    # ===== Translator Settings =====
    translator_beam_size: int = 5
    translator_max_length: int = 128
    translator_repetition_penalty: float = 1.2

    # ===== Image Upload =====
    max_image_size_mb: int = 10
    allowed_image_types: tuple = ("image/jpeg", "image/png", "image/webp")

    # ===== Device =====
    # 'cuda', 'cpu', or 'auto'. Auto picks cuda if available.
    device: str = "auto"


# Singleton instance - import this everywhere
settings = Settings()