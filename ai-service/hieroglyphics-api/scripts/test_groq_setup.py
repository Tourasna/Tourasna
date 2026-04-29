import os
from groq import Groq
from dotenv import load_dotenv

# 1. Load environment variables
load_dotenv()

# 2. Initialize Groq Client
client = Groq(api_key=os.getenv("GROQ_API_KEY"))

print("==================================================")
print("Tourasna AI Service - Groq API Setup")
print("==================================================")

try:
    print("Sending translation request for N5 (Sun Disk)...")
    
    # 3. Request Completion
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "system",
                "content": "You are an expert Egyptologist for the Tourasna app. Translate Gardiner codes to English and Arabic with historical context."
            },
            {
                "role": "user",
                "content": "Explain and translate this Gardiner code: N5"
            }
        ],
        model="llama-3.3-70b-versatile",
        temperature=0.2
    )

    print("\n[SUCCESS] Groq API Responded:")
    print("-" * 30)
    print(chat_completion.choices[0].message.content)
    print("-" * 30)
    print("\nSetup test PASSED! Your Translator is ready for Tourasna.")

except Exception as e:
    print(f"\n[ERROR] something went wrong: {e}")
