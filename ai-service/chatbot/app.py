from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from typing import Dict

from chatbot_core import EgyptianTourismChatbot

app = FastAPI()

# session_id -> chatbot instance
sessions: Dict[str, EgyptianTourismChatbot] = {}


@app.get("/health")
def health():
    return {"status": "ok"}


@app.websocket("/chat/{session_id}")
async def chat_ws(websocket: WebSocket, session_id: str):
    await websocket.accept()

    if session_id not in sessions:
        sessions[session_id] = EgyptianTourismChatbot()

    chatbot = sessions[session_id]

    try:
        while True:
            payload = await websocket.receive_json()
            message = payload.get("message")

            if not message:
                continue

            for chunk in chatbot.process_query_stream(message):
                if chunk:
                    await websocket.send_text(chunk)

            await websocket.send_text("__END__")

    except WebSocketDisconnect:
        pass

    except Exception:
        await websocket.send_text("⚠️ Something went wrong.")
