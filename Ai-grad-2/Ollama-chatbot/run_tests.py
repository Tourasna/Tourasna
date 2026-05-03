import sys
import time
import os

# Set encoding for terminal output
os.environ['PYTHONIOENCODING'] = 'utf-8'

from fahmy_chatbot import EgyptianTourismChatbot

def run_8_tests():
    print("\n" + "="*80)
    print("RUNNING 8 VERIFICATION TESTS")
    print("="*80 + "\n")

    chatbot = EgyptianTourismChatbot()
    
    tests = [
        ("TEST 1: English Consistency", "Hello Fahmy! I want to visit some ancient temples. What do you recommend?"),
        ("TEST 2: Arabic Consistency", "أهلاً يا فهمي، أنا عايز أعرف إيه أجمل الشواطئ في مصر؟"),
        ("TEST 3: French Consistency", "Bonjour! Quels sont les meilleurs musées à visiter au Caire?"),
        ("TEST 4: Spanish Consistency", "¿Hola, cómo estás? Me gustaría saber sobre las pirámides de Giza."),
        ("TEST 5: German Consistency", "Hallo! Ich interessiere mich für die ägyptische Küche. Was sollte ich probieren?"),
        ("TEST 6: Russian Consistency", "Привет! Расскажи мне про Александрийскую библиотеку."),
        ("TEST 7: Chinese Consistency", "你好！请告诉我关于卢克索神庙的信息。"),
        ("TEST 8: Semantic RAG Proof", "I am interested in a quiet place with 5 stars rating in Marsa Alam with a spa.")
    ]

    for i, (title, query) in enumerate(tests, 1):
        print(f"\n[{title}]")
        print(f"👤 You: {query}")
        print(f"🏛️ Fahmy: ", end='', flush=True)
        
        start_time = time.time()
        for chunk in chatbot.process_query_stream(query):
            if chunk:
                print(chunk, end='', flush=True)
        
        duration = time.time() - start_time
        print(f"\n\n[Time taken: {duration:.2f}s]")
        print("-" * 40)
        time.sleep(1)

    print("\n" + "="*80)
    print("ALL TESTS COMPLETED")
    print("="*80 + "\n")

if __name__ == "__main__":
    run_8_tests()
