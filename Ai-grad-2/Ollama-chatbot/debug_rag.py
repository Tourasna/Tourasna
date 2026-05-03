from fahmy_chatbot import EgyptianTourismChatbot

chatbot = EgyptianTourismChatbot()
query = "I am interested in a quiet place with 5 stars rating in Marsa Alam with a spa."
context, retrieved = chatbot.conversation.update_context(chatbot.knowledge_base, chatbot.ai_core, query)

print(f"Retrieved {len(retrieved)} landmarks:")
for i, lm in enumerate(retrieved, 1):
    print(f"{i}. {lm['name']} - Similarity: {lm.get('similarity', 0):.2f}")
    # print(f"   Description: {lm['description'][:100]}...")

print("\nAugmented Prompt snippet:")
prompt = chatbot.conversation.build_augmented_prompt(query, retrieved, [])
print(prompt[:1000])
