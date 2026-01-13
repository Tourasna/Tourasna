# fahmy_service.py

from fahmy_chatbot import UltimateFahmy

# In-memory user sessions (OK for now)
_sessions: dict[str, UltimateFahmy] = {}


def get_fahmy(user_id: str) -> UltimateFahmy:
    if user_id not in _sessions:
        _sessions[user_id] = UltimateFahmy()
    return _sessions[user_id]


def handle_message(payload: dict) -> dict:
    """
    payload = {
        "user_id": "uuid",
        "message": "text",
        "profile": { ... }  # optional, from DB
    }
    """

    user_id = payload.get("user_id")
    message = payload.get("message")

    if not user_id or not message:
        return {
            "error": "user_id and message are required"
        }

    fahmy = get_fahmy(user_id)

    # Inject DB profile ONCE (safe overwrite)
    profile = payload.get("profile")
    if profile:
        fahmy.profile_manager.profile.update(profile)

    reply = fahmy.chat(message)

    return {
        "reply": reply,
        "profile": fahmy.profile_manager.get_formatted_profile(),
        "recommendations": fahmy.current_recommendations or []
    }
