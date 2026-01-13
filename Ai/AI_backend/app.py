# app.py

import sys
from fastapi import FastAPI
from recommender.inference import recommend
from chatbot.ollama_chat import chat

print("FASTAPI APP STARTING", file=sys.stderr)

app = FastAPI(title="Tourasna AI Backend")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/recommend")
def get_recommendations(payload: dict):
    return {
        "recommendations": recommend(payload)
    }


@app.post("/chat")
def chat_endpoint(payload: dict):
    reply = chat(
        system_prompt=payload.get("system_prompt", ""),
        user_message=payload.get("message", ""),
        language=payload.get("language", "en")
    )
    return {"reply": reply}
