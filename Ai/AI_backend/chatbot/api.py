from fastapi import FastAPI
from pydantic import BaseModel
from typing import List, Dict, Any
from fahmy_chatbot import UltimateFahmy

app = FastAPI()
fahmy = UltimateFahmy()

class ChatRequest(BaseModel):
    message: str
    history: List[Dict[str, Any]] = []

@app.post("/chat")
def chat(req: ChatRequest):
    print("INCOMING MESSAGE:", req.message)
    print("INCOMING HISTORY:", req.history)
    safe_history = [
        {"role": m["role"], "content": m["content"]}
        for m in req.history
        if isinstance(m, dict) and "role" in m and "content" in m
    ]

    reply = fahmy.handle_chat(
        user_input=req.message,
        history=safe_history,
    )

    return { "message": reply }
