# 🏛️ Handover Guide: AI Tourism Stack v2.0 (Ai-grad-2)

This project consists of two core systems: a **Multilingual RAG Chatbot (Fahmy)** and a **Personalized Travel Recommendation System**. Both are modular and ready for integration into a mobile or web application.

---

## 1. Infrastructure Requirements (Critical)

The **Chatbot** requires a local instance of [Ollama](https://ollama.ai/) to be running on the host machine/server.

**Steps for SW Team:**

1. Install Ollama on the server.
2. Pull the necessary models:

   ```bash
   ollama pull mistral:7b
   ollama pull nomic-embed-text
   ```

3. Ensure the API is accessible at `http://localhost:11434` (configurable in `fahmy_chatbot.py` -> `CONFIG`).

---

## 2. File Manifest

### A. Chatbot (RAG System)

*Located in `/Ollama_chatbot/`*
*(Note: Rename the folder from `Ollama-chatbot` to `Ollama_chatbot` to allow Python imports)*

- `fahmy_chatbot.py`: The main logic class `EgyptianTourismChatbot`.
- `knowledge_base.faiss`: Pre-built semantic index of 677+ landmarks.
- `embeddings.pkl`: Vectorized representations for fast retrieval.
- `landmarksANDplaces_info.csv`: The source dataset for RAG.

### B. Recommender (DL System)

*Located in `/RecommendationSystem/`*

- `model_inference.py`: The inference engine class `RecommendationEngine`.
- `travel_recommendation_model.keras`: The trained Deep Learning model.
- `label_encoders.pkl` & `all_categories.pkl`: Encoders for feature processing.
- `model_config.json`: Model hyperparameters and metadata.
- `utils.py`: Shared utilities for feature engineering.

---

## 3. Integration Guide

### How to use the Chatbot

Initialize the class once and call the streaming query method.

```python
from Ollama_chatbot.fahmy_chatbot import EgyptianTourismChatbot

chatbot = EgyptianTourismChatbot()

# For streaming responses (recommended for UI):
for chunk in chatbot.process_query_stream("Hello! Tell me about Cairo."):
    print(chunk, end='')
```

### How to use the Recommender

Initialize the engine and pass user preference dictionaries.

```python
from RecommendationSystem.model_inference import load_model_and_artifacts, RecommendationEngine, get_landmark_data

model, encoders, categories, config = load_model_and_artifacts()
unique_landmarks = get_landmark_data() # Loads from CSV
engine = RecommendationEngine(model, categories, unique_landmarks)

user_input = {
    'user_budget': 'medium',
    'user_preferences': ['Museum', 'Pharaonic Site'],
    'user_travel_type': 'solo',
    'user_age': 25,
    'user_gender': 'Male'
}
recommendations = engine.get_recommendations(user_input, top_n=10)
```

---

## 4. Key Features Added (v2.0)

- **Strict Multilingualism**: The chatbot automatically detects 16 languages and validates its own output to prevent "language mixing."
- **Adaptive Blending**: The recommender uses an 80/20 popularity-to-preference blend for new users, solving the "cold-start" problem.
- **Feedback Loop**: User "likes" or "dislikes" can be logged via `engine.log_interaction()` to improve future results.

---
**Ready for Deployment.**
*Prepared by AI Assistant for graduation project handoff.*
