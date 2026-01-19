from fastapi import FastAPI, HTTPException
import traceback
import os
import boto3
from dotenv import load_dotenv
load_dotenv()
# Recommender

S3_BUCKET = "tourasna-assets"
S3_KEY = "landmarks.csv"
CSV_PATH = "/app/assets/landmarks.csv"

if not os.path.exists(CSV_PATH):
    print("⬇️ Downloading landmarks.csv from S3 (pre-import)...")
    os.makedirs("/app/assets", exist_ok=True)
    boto3.client("s3").download_file(S3_BUCKET, S3_KEY, CSV_PATH)
    print("✅ landmarks.csv downloaded")

from recommender.inference import recommend

# Storytelling (Groq)
from storytelling.storytelling import router as storytelling_router

app = FastAPI()


# ─────────────────────────────────────────────
# 🎯 Recommendations
# ─────────────────────────────────────────────
@app.post("/recommendations")
def recommendations(payload: dict):
    try:
        return {
            "recommendations": recommend(payload)
        }
    except Exception as e:
        print("❌ AI CRASH TRACEBACK (RECOMMENDER):")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))


# ─────────────────────────────────────────────
# 🎭 Storytelling (Groq)
# ─────────────────────────────────────────────
app.include_router(storytelling_router)
