from fahmy_chatbot import EgyptianTourismChatbot as E

d = E.detect_language
tests = [
    ("hello", "english"), #test1 
    ("مرحباً، كيف حالك؟", "arabic"), #test2
    ("Bonjour, comment allez-vous?", "french"), #test3
    ("Hola, ¿cómo estás?", "spanish"), #test4
    ("Hallo, wie geht es Ihnen?", "german"), #test5
    ("Привет, как дела?", "russian"), #test6
    ("你好，请告诉我关于埃及的事情", "chinese"), #test7
    ("I want to see something ancient", "english"), #test8
]

for text, expected in tests:
    result = d(text)
    status = "PASS" if result == expected else "FAIL"
    print(f"  {status} | {text[:35]:35s} -> {result:12s} (expected: {expected})")
