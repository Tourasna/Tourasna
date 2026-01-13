# edge_handler.py
from typing import Dict
from fahmy_chatbot import UltimateFahmy

_fahmy_instance: UltimateFahmy | None = None

def get_fahmy() -> UltimateFahmy:
    global _fahmy_instance
    if _fahmy_instance is None:
        _fahmy_instance = UltimateFahmy()
    return _fahmy_instance


def handle_chat_request(payload: Dict) -> Dict:
    """
    This function is called by Supabase Edge.
    """

    try:
        message = payload.get("message", "").strip()

        if not message:
            return {
                "type": "message",
                "message": "No message received."
            }

        fahmy = get_fahmy()
        reply = fahmy.chat(message)

        return {
            "type": "message",
            "message": reply
        }

    except Exception as e:
        return {
            "type": "error",
            "message": "Internal chatbot error"
        }
