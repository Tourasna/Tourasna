from fastapi import APIRouter, HTTPException
import os
import requests
import traceback

router = APIRouter(
    prefix="/storytelling",
    tags=["storytelling"],
)

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"


@router.post("")
def generate_story(payload: dict):
    try:
        name = payload.get("name")
        description = payload.get("description")

        if not name or not description:
            raise HTTPException(status_code=400, detail="Missing place data")

        if not GROQ_API_KEY:
            raise HTTPException(status_code=500, detail="GROQ_API_KEY not set")

        prompt = f"""
Write a short, engaging storytelling narration for tourists.

Name: {name}
Description: {description}
"""

        response = requests.post(
            GROQ_URL,
            headers={
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "llama-3.1-8b-instant",
                "messages": [{"role": "user", "content": prompt}],
                "temperature": 0.7,
                "max_tokens": 400,
            },
            timeout=60,
        )

        print("GROQ STATUS:", response.status_code)
        print("GROQ RAW:", response.text)

        data = response.json()

        if "choices" not in data or not data["choices"]:
            raise HTTPException(status_code=500, detail=data)

        return {
            "story": data["choices"][0]["message"]["content"]
        }

    except HTTPException:
        raise
    except Exception:
        print("❌ STORYTELLING CRASH")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail="Storytelling failed")
