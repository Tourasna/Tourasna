# recommender/data_loader.py

import os
import boto3
import pandas as pd

LANDMARKS = None

CSV_PATH = "assets/landmarks.csv"
S3_BUCKET = "tourasna-assets"
S3_KEY = "landmarks.csv"


def ensure_csv_exists():
    if os.path.exists(CSV_PATH):
        return

    os.makedirs("assets", exist_ok=True)

    print("⬇️ Downloading landmarks.csv from S3 (data_loader)...")
    try:
        s3_client = boto3.client("s3")
        s3_client.download_file(S3_BUCKET, S3_KEY, CSV_PATH)
        print("✅ landmarks.csv ready")
    except Exception as e:
        print(f"❌ S3 download failed: {e}")
        raise


def load_landmarks():
    global LANDMARKS

    if LANDMARKS is not None:
        return LANDMARKS

    # 🔒 GUARANTEE FILE EXISTS AT USE TIME
    ensure_csv_exists()

    df = pd.read_csv(CSV_PATH)

    LANDMARKS = df[
        [
            "landmark_name",
            "landmark_category",
            "landmark_budget",
            "landmark_rate",
            "landmark_Suitable_Travel_Type"
        ]
    ].drop_duplicates()

    return LANDMARKS