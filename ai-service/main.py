from fastapi import FastAPI, HTTPException
import traceback
from dotenv import load_dotenv
load_dotenv()
# Recommender
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
