# main.py
from fastapi import FastAPI, HTTPException
from recommender.inference import recommend
import traceback
app = FastAPI()

@app.post("/recommendations")
def recommendations(payload: dict):
    try:
        return {
            "recommendations": recommend(payload)
        }
    except Exception as e:
        print("❌ AI CRASH TRACEBACK:")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))