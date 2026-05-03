from fahmy_chatbot import EgyptianTourismChatbot

chatbot = EgyptianTourismChatbot()

cases = [
    ("Hello", "Hello, I am Fahmy."), # EN, EN -> True
    ("أهلاً", "أهلاً بك أنا فهمي"), # AR, AR -> True
    ("Bonjour", "Hello, I am Fahmy."), # FR, EN -> False
    ("Hallo", "Bonjour, je suis Fahmy."), # DE, FR -> False
]

for q, r in cases:
    _, ok = chatbot.validate_language_consistency(q, r)
    ql = chatbot.detect_language(q)
    rl = chatbot.detect_language(r)
    print(f"Q: {ql:10s} | R: {rl:10s} | Match: {ok}")
