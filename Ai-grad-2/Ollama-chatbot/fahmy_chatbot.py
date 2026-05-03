#fahmy_chatbot.py
# Fully AI-Powered Egyptian Tourism Chatbot - Fahmy V2 (RAG)
# ============================================================================

import os
import re
import time
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
import json
from datetime import datetime
import requests
import sys
import faiss
import pickle

# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    "ollama_model": "mistral:7b",
    "embedding_model": "nomic-embed-text",
    "conversation_history_limit": 8,
    "streaming_delay": 0.02,
    "context_window": 3000,
    "ollama_base_url": "http://localhost:11434/api",  # Default Ollama API URL
    "ollama_timeout": 1000,  # Timeout in seconds
    "use_api_directly": True  # Set to True to use direct API calls, False for ollama python library
}

# ============================================================================
# KNOWLEDGE BASE - LOAD DATASET
# ============================================================================

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
FAISS_INDEX_PATH = os.path.join(SCRIPT_DIR, 'knowledge_base.faiss')
EMBEDDINGS_PKL_PATH = os.path.join(SCRIPT_DIR, 'embeddings.pkl')
DATASET_PATH = os.path.join(SCRIPT_DIR, 'landmarksANDplaces_info.csv')


class KnowledgeBase:
    """FAISS-based semantic knowledge base for tourism landmarks (RAG Layer 1)"""

    def __init__(self, ai_core=None, rebuild=False):
        self.landmarks = {}
        self.landmark_list = []
        self.categories = set()
        self.faiss_index = None
        self.embedding_matrix = None
        self._ai_core = ai_core
        self._load_dataset()
        self._init_faiss_index(rebuild=rebuild)

    def _load_dataset(self):
        """Load and process the tourism dataset"""
        try:
            df = pd.read_csv(DATASET_PATH, encoding='utf-8')
            for idx, row in df.iterrows():
                lid = f"landmark_{idx}"
                cat = str(row['Category']) if pd.notna(row.get('Category')) else 'Attraction'
                addr = str(row['Address'])[:200] if pd.notna(row.get('Address')) else ''
                desc = self._create_landmark_description(row)
                self.landmarks[lid] = {
                    'id': lid, 'name': str(row['Name']),
                    'city': self._extract_city(addr),
                    'subcategory': cat,
                    'rating': float(row['Rating']) if pd.notna(row.get('Rating')) else 0.0,
                    'address': addr,
                    'latitude': row.get('Latitude') if pd.notna(row.get('Latitude')) else None,
                    'longitude': row.get('Longitude') if pd.notna(row.get('Longitude')) else None,
                    'description': desc,
                    'full_text': self._create_full_text(row),
                    'phone': str(row.get('Phone', '')) if pd.notna(row.get('Phone')) else '',
                    'website': str(row.get('Website', '')) if pd.notna(row.get('Website')) else '',
                    'opening_hours': str(row.get('Opening Hours', '')) if pd.notna(row.get('Opening Hours')) else '',
                }
                self.categories.add(cat)
            self.landmark_list = list(self.landmarks.values())
        except Exception:
            self.landmarks = {}
            self.landmark_list = []

    @staticmethod
    def _extract_city(address: str) -> str:
        """Extract city name from address string"""
        addr_l = address.lower()
        cities = {'cairo': 'Cairo', 'giza': 'Giza', 'luxor': 'Luxor',
                  'aswan': 'Aswan', 'alexandria': 'Alexandria',
                  'sharm': 'Sharm El Sheikh', 'hurghada': 'Hurghada'}
        for key, val in cities.items():
            if key in addr_l:
                return val
        return 'Cairo'

    def _create_landmark_description(self, row):
        """Create a rich description for a landmark"""
        name = str(row['Name'])
        cat = str(row['Category']) if pd.notna(row.get('Category')) else 'attraction'
        rating = row.get('Rating')
        addr = str(row['Address'])[:100] if pd.notna(row.get('Address')) else 'Location varies'
        desc_col = str(row.get('Description', '')) if pd.notna(row.get('Description')) else ''
        d = f"{name} is a {cat.lower()} in Egypt. "
        if pd.notna(rating):
            d += f"Rating: {rating}/5. "
        if desc_col:
            d += desc_col[:300] + ' '
        d += f"Address: {addr}."
        return d

    def _create_full_text(self, row):
        """Create full text representation for embedding"""
        parts = [str(row['Name'])]
        if pd.notna(row.get('Category')):
            parts.append(f"Category: {row['Category']}")
        if pd.notna(row.get('Rating')):
            parts.append(f"Rating: {row['Rating']}/5")
        if pd.notna(row.get('Address')):
            parts.append(f"Address: {str(row['Address'])[:150]}")
        if pd.notna(row.get('Description')):
            parts.append(str(row['Description'])[:400])
        if pd.notna(row.get('Opening Hours')):
            parts.append(f"Hours: {row['Opening Hours']}")
        return '. '.join(parts)

    # ------------------------------------------------------------------
    # FAISS Index Management
    # ------------------------------------------------------------------
    def _init_faiss_index(self, rebuild=False):
        """Load or build FAISS index"""
        if not rebuild and os.path.exists(FAISS_INDEX_PATH) and os.path.exists(EMBEDDINGS_PKL_PATH):
            try:
                self.faiss_index = faiss.read_index(FAISS_INDEX_PATH)
                with open(EMBEDDINGS_PKL_PATH, 'rb') as f:
                    self.embedding_matrix = pickle.load(f)
                return
            except Exception:
                pass
        # Build if ai_core is available with embeddings
        if self._ai_core and getattr(self._ai_core, 'embedding_available', False):
            self._build_faiss_index()

    def _build_faiss_index(self):
        """Build FAISS index by embedding all landmarks"""
        if not self.landmark_list:
            return
        n = len(self.landmark_list)
        dim = 768
        embeddings = np.zeros((n, dim), dtype=np.float32)
        for i, lm in enumerate(self.landmark_list):
            if (i + 1) % 50 == 0 or i == 0 or i == n - 1:
                print(f"Building knowledge base: {i+1}/{n} landmarks embedded...", flush=True)
            vec = self._ai_core.generate_embedding(lm['full_text'])
            if vec is not None and len(vec) == dim:
                embeddings[i] = vec
        # L2 normalize for cosine similarity via inner product
        norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
        norms[norms == 0] = 1.0
        embeddings = embeddings / norms
        self.embedding_matrix = embeddings
        self.faiss_index = faiss.IndexFlatIP(dim)
        self.faiss_index.add(embeddings)
        # Atomic save: write to temp files first
        tmp_faiss = FAISS_INDEX_PATH + '.tmp'
        tmp_pkl = EMBEDDINGS_PKL_PATH + '.tmp'
        faiss.write_index(self.faiss_index, tmp_faiss)
        with open(tmp_pkl, 'wb') as f:
            pickle.dump(self.embedding_matrix, f)
        os.replace(tmp_faiss, FAISS_INDEX_PATH)
        os.replace(tmp_pkl, EMBEDDINGS_PKL_PATH)
        print(f"FAISS index saved to disk ({n} landmarks).")

    def semantic_search(self, query: str, top_k: int = 5) -> List[Dict]:
        """Semantic search using FAISS cosine similarity"""
        if self.faiss_index is None or self._ai_core is None:
            return []
        vec = self._ai_core.generate_embedding(query)
        if vec is None:
            return []
        qvec = np.array([vec], dtype=np.float32)
        norm = np.linalg.norm(qvec)
        if norm > 0:
            qvec = qvec / norm
        scores, indices = self.faiss_index.search(qvec, min(top_k * 2, len(self.landmark_list)))
        results = []
        for score, idx in zip(scores[0], indices[0]):
            if idx < 0 or score < 0.3:
                continue
            lm = self.landmark_list[idx].copy()
            lm['similarity'] = float(score)
            results.append(lm)
        return results[:top_k]

    def search_landmarks(self, query: str, limit: int = 5) -> List[Dict]:
        """Keyword fallback search"""
        q = query.lower()
        results = []
        for lm in self.landmark_list:
            score = 0
            if q in lm['name'].lower(): score += 3
            if q in lm['city'].lower(): score += 2
            if q in lm['subcategory'].lower(): score += 1
            if q in lm['description'].lower(): score += 1
            if score > 0:
                results.append((score, lm))
        results.sort(key=lambda x: x[0], reverse=True)
        return [r[1] for r in results[:limit]]

    def get_landmarks_by_city(self, city: str) -> List[Dict]:
        """Get all landmarks in a city"""
        cl = city.lower()
        return [lm for lm in self.landmark_list if cl in lm['city'].lower()]

    def get_landmarks_by_category(self, category: str) -> List[Dict]:
        """Get all landmarks in a category"""
        cl = category.lower()
        return [lm for lm in self.landmark_list if cl in lm['subcategory'].lower()]

# ============================================================================
# AI CORE - OLLAMA INTEGRATION WITH API
# ============================================================================

class AICore:
    """Core AI functionality using Ollama API"""
    
    def __init__(self):
        self.model = CONFIG["ollama_model"]
        self.embedding_model = CONFIG["embedding_model"]
        self.base_url = CONFIG["ollama_base_url"]
        self.timeout = CONFIG["ollama_timeout"]
        self.use_api_directly = CONFIG["use_api_directly"]
        self.available = False
        self.embedding_available = False
        self._init_ollama()
    
    def _init_ollama(self):
        """Initialize Ollama connection via API - SILENT VERSION"""
        try:
            test_url = self.base_url.replace('/api', '')
            response = requests.get(test_url, timeout=5)
            if response.status_code == 200:
                if self.use_api_directly:
                    models_url = f"{self.base_url}/tags"
                    response = requests.get(models_url, timeout=5)
                    if response.status_code == 200:
                        models = response.json().get('models', [])
                        model_names = [m['name'] for m in models]
                        if self.model not in model_names:
                            if models:
                                self.model = model_names[0]
                            else:
                                self.available = False
                                return
                        self.available = True
                        # Check embedding model
                        embed_found = any(self.embedding_model in n for n in model_names)
                        if embed_found:
                            self.embedding_available = True
                        else:
                            print(f"Warning: Embedding model not found. Run: ollama pull {self.embedding_model}")
                            self.embedding_available = False
                    else:
                        self.available = False
                else:
                    try:
                        import ollama
                        models = ollama.list()
                        model_names = [m.name for m in models.models]
                        if self.model not in model_names and models.models:
                            self.model = model_names[0]
                        self.available = True
                        embed_found = any(self.embedding_model in n for n in model_names)
                        self.embedding_available = embed_found
                        if not embed_found:
                            print(f"Warning: Embedding model not found. Run: ollama pull {self.embedding_model}")
                    except:
                        self.available = False
            else:
                self.available = False
        except:
            self.available = False

    def generate_embedding(self, text: str) -> Optional[np.ndarray]:
        """Generate embedding using nomic-embed-text via Ollama API"""
        if not self.embedding_available:
            return None
        try:
            url = f"{self.base_url}/embeddings"
            payload = {"model": self.embedding_model, "prompt": text[:2000]}
            resp = requests.post(url, json=payload, timeout=30)
            if resp.status_code == 200:
                emb = resp.json().get('embedding')
                if emb:
                    return np.array(emb, dtype=np.float32)
            return None
        except Exception:
            return None
    
    def _api_chat_stream(self, messages: List[Dict], options: Dict = None):
        """Make streaming API call to Ollama"""
        try:
            chat_url = f"{self.base_url}/chat"
            
            payload = {
                "model": self.model,
                "messages": messages,
                "stream": True,
                "options": options or {
                    "temperature": 0.8,
                    "num_predict": 800,
                    "top_p": 0.9,
                    "repeat_penalty": 1.1
                }
            }
            
            response = requests.post(
                chat_url, 
                json=payload,
                timeout=self.timeout,
                stream=True
            )
            
            if response.status_code == 200:
                for line in response.iter_lines():
                    if line:
                        try:
                            json_response = json.loads(line)
                            if 'message' in json_response:
                                content = json_response['message'].get('content', '')
                                if content:
                                    yield content
                        except json.JSONDecodeError:
                            continue
            else:
                yield None
                
        except Exception:
            yield None
    
    def _api_chat(self, messages: List[Dict], options: Dict = None) -> Optional[str]:
        """Make direct API call to Ollama"""
        try:
            chat_url = f"{self.base_url}/chat"
            
            payload = {
                "model": self.model,
                "messages": messages,
                "stream": False,
                "options": options or {
                    "temperature": 0.8,
                    "num_predict": 800,
                    "top_p": 0.9,
                    "repeat_penalty": 1.1
                }
            }
            
            response = requests.post(
                chat_url, 
                json=payload,
                timeout=self.timeout
            )
            
            if response.status_code == 200:
                result = response.json()
                return result.get('message', {}).get('content', '')
            else:
                return None
                
        except Exception:
            return None
    
    def _library_chat(self, messages: List[Dict], options: Dict = None) -> Optional[str]:
        """Use ollama python library"""
        try:
            import ollama
            
            response = ollama.chat(
                model=self.model,
                messages=messages,
                options=options or {
                    "temperature": 0.8,
                    "num_predict": 800,
                    "top_p": 0.9,
                    "repeat_penalty": 1.1
                }
            )
            
            return response['message']['content']
            
        except Exception:
            return None
    
    def generate_response_stream(self, 
                                 user_input: str, 
                                 context: str = "", 
                                 conversation_history: List[Dict] = None,
                                 temperature: float = 0.8,
                                 user_language: str = 'english'):
        """Generate AI response with streaming"""
        if not self.available:
            yield None
            return
        
        try:
            messages = []
            system_prompt = self._create_system_prompt(context, user_language=user_language)
            messages.append({"role": "system", "content": system_prompt})
            
            if conversation_history:
                messages.extend(conversation_history[-6:])
            
            messages.append({"role": "user", "content": user_input})
            
            options = {
                "temperature": temperature,
                "num_predict": 800,
                "top_p": 0.9,
                "repeat_penalty": 1.1
            }
            
            if self.use_api_directly:
                for chunk in self._api_chat_stream(messages, options):
                    yield chunk
            else:
                response = self._library_chat(messages, options)
                if response:
                    for char in response:
                        yield char
                        time.sleep(0.01)
            
        except Exception:
            yield None
    
    def generate_response(self, 
                         user_input: str, 
                         context: str = "", 
                         conversation_history: List[Dict] = None,
                         temperature: float = 0.8,
                         user_language: str = 'english') -> Optional[str]:
        """Generate AI response (non-streaming)"""
        if not self.available:
            return None
        
        try:
            messages = []
            system_prompt = self._create_system_prompt(context, user_language=user_language)
            messages.append({"role": "system", "content": system_prompt})
            
            if conversation_history:
                messages.extend(conversation_history[-6:])
            
            messages.append({"role": "user", "content": user_input})
            
            options = {
                "temperature": temperature,
                "num_predict": 800,
                "top_p": 0.9,
                "repeat_penalty": 1.1
            }
            
            if self.use_api_directly:
                return self._api_chat(messages, options)
            else:
                return self._library_chat(messages, options)
            
        except Exception:
            return None
    
    def _create_system_prompt(self, context: str, user_language: str = 'english') -> str:
        """Create system prompt for the AI with RAG context"""
        # FIX 3: Escape curly braces in external data to prevent .format() crashes
        context_safe = (context if context else 'General Egyptian tourism knowledge available.')
        context_safe = context_safe.replace('{', '{{').replace('}', '}}')
        lang_safe = user_language.replace('{', '{{').replace('}', '}}')

        prompt = """You are Fahmy ({fahmy_ar}), an Egyptian Tourism Guide AI. Your name means "understanding" in Arabic.

CORE IDENTITY:
- You're warm, genuine, and deeply passionate about Egypt
- You speak naturally like a knowledgeable friend, not a formal assistant
- You're multilingual and ALWAYS respond in the SAME LANGUAGE the user speaks to you in
- You adapt your tone to match the conversation - casual for chit-chat, informative for serious queries

MULTILINGUAL BEHAVIOR (CRITICAL):
You support the following languages natively:
Arabic, Hebrew, Persian/Farsi, Greek, Russian, Chinese (Simplified),
Japanese, Korean, Thai, Hindi, French, Spanish, German, Italian,
Portuguese, and English.

Rules:
- ALWAYS respond in the EXACT same language the user writes to you in
- If the user writes in Arabic, respond completely in Arabic
- If the user writes in Chinese, respond completely in Chinese
- If the user writes in Russian, respond completely in Russian
- Apply this rule to ALL supported languages
- NEVER switch languages mid-response unless the user does first
- Maintain natural, native-speaker quality in every language
- If you detect a language you are uncertain about, default to English
  and politely ask the user to confirm their preferred language

ACTIVE LANGUAGE INSTRUCTION (HIGHEST PRIORITY):
The user is communicating in: {user_language}
You MUST respond ENTIRELY in {user_language}.
Do NOT use any other language anywhere in your response.
Not even a single word, greeting, or emoji label in another language.
FAILURE TO RESPOND IN {user_language} IS UNACCEPTABLE AND WILL BREAK THE SYSTEM.
If you were thinking of using another language, STOP and translate it to {user_language} first.

PERSONALITY TRAITS:
- You share stories and personal insights about Egypt
- You use conversational language, not robotic responses
- You're enthusiastic but not overwhelming
- You ask thoughtful follow-up questions
- You remember context from the conversation
- You're honest when you don't know something
- You use emojis naturally to add warmth (but not excessively)

CONVERSATION STYLE:
- Start responses naturally - vary your openings
- Share interesting facts as stories, not lists
- Use "I think", "In my experience", "I'd recommend" instead of "It is recommended"
- Ask follow-up questions when appropriate
- Make connections between topics naturally
- Show genuine interest in what the user wants

RETRIEVED KNOWLEDGE FROM KNOWLEDGE BASE:
{context}

INSTRUCTION: Base your response primarily on the retrieved knowledge above.
If the retrieved knowledge does not contain enough information, acknowledge this honestly rather than hallucinating facts.

EXAMPLES OF YOUR STYLE:

User (English): "Tell me about the pyramids"
You: "Oh, the pyramids! They never get old for me. The Great Pyramid of Giza is absolutely mind-blowing - it's the oldest of the Seven Wonders and the only one still standing. When you see it in person, the sheer scale is incredible. Have you ever seen them before, or would this be your first time?"

User (Arabic): "{example_ar}"
You: "{response_ar}"

User (French): "Quels sont les meilleurs endroits au Caire?"
You: "Ah, Le Caire! C'est une ville fascinante avec tellement a voir. Je te recommanderais de commencer par les pyramides de Gizeh bien sur, puis le Musee egyptien au centre-ville. Le bazar de Khan el-Khalili est incroyable pour l'ambiance et les souvenirs. Tu cherches plutot des sites historiques ou tu veux aussi decouvrir la vie moderne du Caire?"

REMEMBER:
- Be helpful but conversational
- Show personality and warmth
- ALWAYS match the user's language
- Make Egypt come alive through your words
- Be the friend who knows Egypt inside and out"""

        return prompt.format(
            context=context_safe,
            user_language=lang_safe,
            fahmy_ar='\u0641\u0647\u0645\u064a',
            example_ar='\u0623\u0646\u0627 \u0639\u0627\u064a\u0632 \u0623\u0639\u0631\u0641 \u0639\u0646 \u0627\u0644\u0645\u062a\u062d\u0641 \u0627\u0644\u0645\u0635\u0631\u064a',
            response_ar='\u0627\u0644\u0645\u062a\u062d\u0641 \u0627\u0644\u0645\u0635\u0631\u064a \u0641\u064a \u0627\u0644\u0642\u0627\u0647\u0631\u0629 \u062f\u0647 \u062d\u0627\u062c\u0629 \u062a\u0627\u0646\u064a\u0629 \u062e\u0627\u0644\u0635!'
        )
    
    def is_tourism_related(self, text: str, knowledge_base: KnowledgeBase) -> Tuple[bool, str]:
        """Use AI to determine if query is tourism-related"""
        if not self.available:
            return False, "no_ai"
        
        try:
            prompt = f"""Analyze this user message and determine if it's related to Egyptian tourism, travel, or culture.

User message: "{text}"

Consider it tourism-related if it's about:
- Egyptian landmarks, attractions, or places
- Travel planning to Egypt
- Egyptian culture, history, or food
- Recommendations for visiting Egypt
- General questions about Egypt

Respond with ONLY one word: YES or NO"""

            messages = [{"role": "user", "content": prompt}]
            options = {"temperature": 0.1, "num_predict": 10}
            
            response_text = self._api_chat(messages, options)
            
            if response_text:
                result = response_text.strip().upper()
                return "YES" in result, "ai_detection"
            else:
                return False, "error"
            
        except Exception:
            return False, "error"
    
    def check_health(self) -> bool:
        """Check if Ollama API is healthy"""
        try:
            health_url = self.base_url.replace('/api', '')
            response = requests.get(health_url, timeout=5)
            return response.status_code == 200
        except:
            return False

# ============================================================================
# CONVERSATION MANAGER
# ============================================================================

class ConversationManager:
    """Manage conversation flow and context"""
    
    def __init__(self):
        self.history = []
        self.context = ""
        self.user_interests = []
        self.conversation_mode = "general"
        
    def add_message(self, role: str, content: str):
        """Add message to history"""
        self.history.append({
            "role": role,
            "content": content,
            "timestamp": datetime.now().isoformat()
        })
        
        if len(self.history) > CONFIG["conversation_history_limit"] * 2:
            self.history = self.history[-CONFIG["conversation_history_limit"] * 2:]
    
    def get_recent_history(self, max_messages: int = 6) -> List[Dict]:
        """Get recent conversation history"""
        return self.history[-max_messages:] if self.history else []
    
    def extract_interests(self, text: str) -> List[str]:
        """Extract user interests from conversation"""
        interests = []
        text_lower = text.lower()

        cities = [
            'cairo', 'giza', 'luxor', 'aswan', 'alexandria', 'sharm', 'hurghada',
            'marsa alam', 'dahab', 'siwa', 'fayoum', 'port said', 'ismailia', 'suez',
            '\u0627\u0644\u0642\u0627\u0647\u0631\u0629', '\u0627\u0644\u062c\u064a\u0632\u0629', '\u0627\u0644\u0623\u0642\u0635\u0631', '\u0623\u0633\u0648\u0627\u0646', '\u0627\u0644\u0625\u0633\u0643\u0646\u062f\u0631\u064a\u0629',
            '\u0645\u0631\u0633\u0649 \u0639\u0644\u0645', '\u062f\u0647\u0628', '\u0633\u064a\u0648\u0629', '\u0627\u0644\u0641\u064a\u0648\u0645', '\u0628\u0648\u0631\u0633\u0639\u064a\u062f',
            'le caire', 'alexandrie', 'louxor',
            'el cairo', 'alejandr\u00eda',
            'kairo', 'alexandrien',
            '\u043a\u0430\u0438\u0440', '\u0430\u043b\u0435\u043a\u0441\u0430\u043d\u0434\u0440\u0438\u044f', '\u043b\u0443\u043a\u0441\u043e\u0440', '\u0430\u0441\u0443\u0430\u043d',
            '\u5f00\u7f57', '\u5409\u8428', '\u5362\u514b\u7d22', '\u4e9a\u5386\u5c71\u5927',
            '\u30ab\u30a4\u30ed', '\u30eb\u30af\u30bd\u30fc\u30eb',
            '\uce74\uc774\ub85c', '\ub8e9\uc18c\ub974',
            '\u0915\u093e\u0939\u093f\u0930\u093e', '\u0932\u0915\u094d\u0938\u0930',
            'il cairo', 'alessandria',
            '\u03ba\u03ac\u03b9\u03c1\u03bf', '\u03b1\u03bb\u03b5\u03be\u03ac\u03bd\u03b4\u03c1\u03b5\u03b9\u03b1',
        ]
        for city in cities:
            if city in text_lower:
                interests.append(city)

        categories = ['museum', 'pyramid', 'temple', 'shopping', 'park', 'nature',
                     'beach', 'desert', 'market', 'bazaar', 'restaurant',
                     '\u0645\u062a\u062d\u0641', '\u0647\u0631\u0645', '\u0645\u0639\u0628\u062f', '\u0633\u0648\u0642', '\u0634\u0627\u0637\u0626']
        for category in categories:
            if category in text_lower:
                interests.append(category)
        
        return interests
    
    def update_context(self, knowledge_base: KnowledgeBase, ai_core, user_input: str) -> Tuple[str, List[Dict]]:
        """Update context using semantic retrieval (RAG Layer 2)"""
        # Stage 1: Semantic retrieval with FAISS
        retrieved = self.retrieve_relevant_landmarks(knowledge_base, ai_core, user_input)

        # Fallback to keyword search if semantic returns nothing
        if not retrieved:
            keyword_results = knowledge_base.search_landmarks(user_input, limit=5)
            retrieved = keyword_results

        # Stage 2: Build augmented prompt
        context = self.build_augmented_prompt(user_input, retrieved, self.history)

        if self.user_interests:
            context += f"\nUSER INTERESTS: {', '.join(self.user_interests)}"
        context += f"\nCONVERSATION MODE: {self.conversation_mode}"

        self.context = context
        return self.context, retrieved

    def retrieve_relevant_landmarks(self, knowledge_base: KnowledgeBase, ai_core, query: str, top_k: int = 5) -> List[Dict]:
        """Algorithm 1: Semantic Retrieval with diversity"""
        results = knowledge_base.semantic_search(query, top_k=top_k * 2)
        if not results:
            return []
        # Diversity: max 2 from same category
        diverse = []
        cat_count = {}
        for lm in results:
            cat = lm.get('subcategory', 'Unknown')
            cat_count[cat] = cat_count.get(cat, 0)
            if cat_count[cat] < 2:
                diverse.append(lm)
                cat_count[cat] += 1
            if len(diverse) >= top_k:
                break
        return diverse

    def build_augmented_prompt(self, query: str, retrieved: List[Dict], history: List[Dict]) -> str:
        """Algorithm 2: Context Augmentation with token budget"""
        TOKEN_BUDGET = 2500
        est_tokens = lambda t: len(t) // 4

        # Build retrieved knowledge (never truncated)
        facts_parts = []
        for lm in retrieved:
            sim = lm.get('similarity', '')
            sim_str = f" [similarity: {sim:.2f}]" if isinstance(sim, float) else ''
            entry = f"- {lm['name']} ({lm.get('city', '')}, {lm.get('subcategory', '')}): {lm['description'][:300]}{sim_str}"
            facts_parts.append(entry)
        facts_block = "RETRIEVED KNOWLEDGE:\n" + "\n".join(facts_parts) if facts_parts else "No specific landmarks found for this query."

        remaining = TOKEN_BUDGET - est_tokens(facts_block) - est_tokens(query) - 50

        # Last 3 conversation turns (truncatable)
        recent = history[-6:]  # 3 turns = 6 messages
        hist_lines = []
        for msg in recent:
            role = msg.get('role', 'user')
            content = msg.get('content', '')[:200]
            hist_lines.append(f"{role}: {content}")
        hist_block = "\n".join(hist_lines)
        if est_tokens(hist_block) > remaining:
            hist_block = hist_block[:remaining * 4]

        parts = [facts_block]
        if hist_block.strip():
            parts.append(f"CONVERSATION HISTORY:\n{hist_block}")
        parts.append(f"CURRENT QUERY: {query}")
        return "\n\n".join(parts)

# ============================================================================
# MAIN CHATBOT
# ============================================================================

class EgyptianTourismChatbot:
    """Main chatbot class - RAG-powered AI-driven V2"""

    def __init__(self, rebuild_index=False):
        # Initialize AI core first (needed for embeddings)
        self.ai_core = AICore()
        # Initialize knowledge base with AI core for FAISS
        self.knowledge_base = KnowledgeBase(ai_core=self.ai_core, rebuild=rebuild_index)
        self.conversation = ConversationManager()

        self.stats = {
            "total_queries": 0,
            "tourism_queries": 0,
            "casual_queries": 0
        }

        # Display chat interface
        print("\n" + "="*70)
        print("FAHMY - Your Egyptian Tourism Friend (V2 RAG)")
        print("="*70 + "\n")
        n_landmarks = len(self.knowledge_base.landmark_list)
        if self.knowledge_base.faiss_index is not None:
            print(f"RAG Knowledge Base: {n_landmarks} landmarks indexed")
        else:
            print(f"Knowledge Base: {n_landmarks} landmarks (keyword mode - no embeddings)")
        print("I'm Fahmy - I'll respond in whatever language you speak to me!")
        print("Ask me anything about Egypt, or just chat with me casually\n")
        print("-" * 70)

        if not self.ai_core.available:
            pass

    @staticmethod
    def detect_language(text: str) -> str:
        """
        Detect dominant language using character-level and lexical analysis.
        Priority order: Arabic > Hebrew > Persian/Farsi > Greek > Russian/Cyrillic >
                        Chinese > Japanese > Korean > Thai > Hindi/Devanagari >
                        French > Spanish > German > Italian > Portuguese > English (default)
        """
        if not text or not text.strip():
            return 'english'

        # --- Script-based detection ---

        # Arabic
        if sum(1 for c in text if '\u0600' <= c <= '\u06FF') > 0:
            return 'arabic'

        # Hebrew
        if sum(1 for c in text if '\u0590' <= c <= '\u05FF') > 0:
            return 'hebrew'

        # Persian/Farsi
        if sum(1 for c in text if '\uFB50' <= c <= '\uFDFF') > 0:
            return 'persian'

        # Greek
        if sum(1 for c in text if '\u0370' <= c <= '\u03FF') > 0:
            return 'greek'

        # Russian / Cyrillic
        if sum(1 for c in text if '\u0400' <= c <= '\u04FF') > 0:
            return 'russian'

        # Korean
        if sum(1 for c in text if '\uAC00' <= c <= '\uD7A3') > 0:
            return 'korean'

        # Japanese
        if sum(1 for c in text if '\u3040' <= c <= '\u309F' or '\u30A0' <= c <= '\u30FF') > 0:
            return 'japanese'

        # Chinese
        if sum(1 for c in text if '\u4E00' <= c <= '\u9FFF') > 0:
            return 'chinese'

        # Thai
        if sum(1 for c in text if '\u0E00' <= c <= '\u0E7F') > 0:
            return 'thai'

        # Hindi / Devanagari
        if sum(1 for c in text if '\u0900' <= c <= '\u097F') > 0:
            return 'hindi'

        # --- Latin-script language detection (lexical) ---

        # French accents
        if any(c in 'éèêëàâôùûüîïçœæÉÈÊËÀÂÔÙÛÜÎÏÇŒÆ' for c in text):
            return 'french'

        words = [w.strip('.,!?;:\'\"()[]¿¡') for w in text.lower().split()]
        wc = len(words)
        # Threshold: 1 hit for very short text, 2 for medium, 3 for long
        t = 1 if wc <= 3 else (2 if wc <= 12 else 3)

        # French keywords
        fr = {'je', 'tu', 'il', 'elle', 'nous', 'vous', 'ils', 'elles', 'le', 'la', 'les', 'un', 'une', 'des', 'du', 'de', 'et', 'est', 'sont', 'dans', 'pour', 'avec', 'sur', 'que', 'qui', 'quoi', 'où', 'comment', 'pourquoi', 'bonjour', 'merci', 'oui', 'non', 'très', 'bien', 'aussi', 'mais', 'donc', 'quand', 'quel', 'quelle', 'voici', 'voilà'}
        if sum(1 for w in words if w in fr) >= t:
            return 'french'

        # Spanish keywords
        es = {'yo', 'tú', 'él', 'ella', 'nosotros', 'vosotros', 'ellos', 'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'es', 'son', 'estar', 'tiene', 'hola', 'gracias', 'por', 'favor', 'qué', 'cómo', 'dónde', 'cuándo', 'quién', 'también', 'pero', 'porque', 'cuando', 'como', 'muy', 'bien', 'sí', 'no', 'buenos', 'días', 'tarde', 'noche'}
        if sum(1 for w in words if w in es) >= t:
            return 'spanish'

        # German keywords
        de = {'ich', 'du', 'er', 'sie', 'wir', 'ihr', 'der', 'die', 'das', 'ein', 'eine', 'und', 'ist', 'sind', 'haben', 'hallo', 'danke', 'bitte', 'wie', 'was', 'wo', 'wann', 'warum', 'aber', 'oder', 'nicht', 'auch', 'sehr', 'gut', 'guten', 'morgen', 'abend', 'nacht', 'ja', 'nein'}
        if sum(1 for w in words if w in de) >= t:
            return 'german'

        # Italian keywords
        it = {'io', 'tu', 'lui', 'lei', 'noi', 'voi', 'loro', 'il', 'lo', 'la', 'i', 'gli', 'le', 'un', 'una', 'è', 'sono', 'ciao', 'grazie', 'prego', 'come', 'dove', 'quando', 'perché', 'che', 'non', 'anche', 'molto', 'bene', 'buongiorno', 'buonasera', 'sì', 'no'}
        if sum(1 for w in words if w in it) >= t:
            return 'italian'

        # Portuguese keywords
        pt = {'eu', 'tu', 'ele', 'ela', 'nós', 'vós', 'eles', 'elas', 'o', 'a', 'os', 'as', 'um', 'uma', 'uns', 'umas', 'é', 'são', 'olá', 'obrigado', 'obrigada', 'por', 'favor', 'como', 'onde', 'quando', 'porque', 'que', 'também', 'mas', 'muito', 'bem', 'bom', 'boa', 'sim', 'não'}
        if sum(1 for w in words if w in pt) >= t:
            return 'portuguese'

        return 'english'

    def validate_language_consistency(self, user_input: str, response: str) -> Tuple[str, bool]:
        """Validate that response language matches user input language."""
        user_lang = self.detect_language(user_input)
        resp_lang = self.detect_language(response)
        # Handle Japanese/Chinese/Korean as close siblings for validation if needed, 
        # but here we follow the detected script exactly.
        return response, (user_lang == resp_lang)

    def process_query_stream(self, user_input: str):
        """RAG Pipeline: 4-stage process — validate first, then stream to user"""
        self.stats["total_queries"] += 1

        # Check for exit
        if user_input.lower() in ['exit', 'quit', 'bye', 'goodbye',
                                   '\u062e\u0631\u0648\u062c',
                                   '\u0645\u0639 \u0627\u0644\u0633\u0644\u0627\u0645\u0629']:
            yield self._create_farewell()
            return

        # Update user interests
        new_interests = self.conversation.extract_interests(user_input)
        self.conversation.user_interests.extend(new_interests)
        self.conversation.user_interests = list(set(self.conversation.user_interests))[:5]

        # Determine conversation mode
        if self.ai_core.available:
            is_tourism, method = self.ai_core.is_tourism_related(user_input, self.knowledge_base)
        else:
            is_tourism = False
            method = "no_ai"

        if is_tourism:
            self.stats["tourism_queries"] += 1
            self.conversation.conversation_mode = "tourism_focused"
        else:
            self.stats["casual_queries"] += 1
            self.conversation.conversation_mode = "casual"

        # Stage 1+3: Semantic retrieval + augmented prompt construction
        context, retrieved = self.conversation.update_context(
            self.knowledge_base, self.ai_core, user_input
        )

        # Stage 2: Language detection BEFORE generation
        user_lang = self.detect_language(user_input)

        # Stage 4: Generate, validate, then stream
        full_response = ""
        if self.ai_core.available:
            # Step 1: Generate complete response (non-streaming) for validation
            full_response = self.ai_core.generate_response(
                user_input=user_input, context=context,
                conversation_history=self.conversation.get_recent_history(),
                temperature=0.8, user_language=user_lang
            ) or ""

            # Step 2: Validate language consistency
            if full_response:
                _, is_consistent = self.validate_language_consistency(user_input, full_response)
                # Step 3: Max 1 retry if language mismatch
                if not is_consistent:
                    # Log retry for debugging - Silenced as per request
                    # print(f"\n[Language mismatch detected. Retrying in {user_lang.upper()}...]", end='', flush=True)
                    lang_map = {
                        'arabic': 'ARABIC', 'hebrew': 'HEBREW',
                        'persian': 'PERSIAN/FARSI', 'greek': 'GREEK',
                        'russian': 'RUSSIAN', 'chinese': 'CHINESE (SIMPLIFIED)',
                        'thai': 'THAI', 'hindi': 'HINDI',
                        'french': 'FRENCH', 'spanish': 'SPANISH',
                        'german': 'GERMAN', 'italian': 'ITALIAN',
                        'portuguese': 'PORTUGUESE', 'english': 'ENGLISH',
                        'japanese': 'JAPANESE', 'korean': 'KOREAN',
                    }
                    lang_name = lang_map.get(user_lang, 'ENGLISH')
                    retry_input = f"[RESPOND ONLY IN {lang_name}] {user_input}"
                    retry_response = self.ai_core.generate_response(
                        user_input=retry_input, context=context,
                        conversation_history=self.conversation.get_recent_history(),
                        user_language=user_lang
                    )
                    if retry_response:
                        full_response = retry_response

            # Step 4: Stream the validated response character by character
            for char in full_response:
                yield char
                time.sleep(CONFIG["streaming_delay"])
        else:
            fallback = self._create_fallback_response(user_input, is_tourism)
            full_response = fallback
            for char in fallback:
                yield char
                time.sleep(CONFIG["streaming_delay"])

        # Add to history
        self.conversation.add_message("user", user_input)
        self.conversation.add_message("assistant", full_response)
    
    def process_query(self, user_input: str) -> str:
        """Non-streaming version"""
        self.stats["total_queries"] += 1

        if user_input.lower() in ['exit', 'quit', 'bye', 'goodbye',
                                   '\u062e\u0631\u0648\u062c',
                                   '\u0645\u0639 \u0627\u0644\u0633\u0644\u0627\u0645\u0629']:
            return self._create_farewell()

        new_interests = self.conversation.extract_interests(user_input)
        self.conversation.user_interests.extend(new_interests)
        self.conversation.user_interests = list(set(self.conversation.user_interests))[:5]

        if self.ai_core.available:
            is_tourism, method = self.ai_core.is_tourism_related(user_input, self.knowledge_base)
        else:
            is_tourism = False

        if is_tourism:
            self.stats["tourism_queries"] += 1
            self.conversation.conversation_mode = "tourism_focused"
        else:
            self.stats["casual_queries"] += 1
            self.conversation.conversation_mode = "casual"

        user_lang = self.detect_language(user_input)

        context, retrieved = self.conversation.update_context(
            self.knowledge_base, self.ai_core, user_input
        )

        ai_response = self.ai_core.generate_response(
            user_input=user_input, context=context,
            conversation_history=self.conversation.get_recent_history(),
            temperature=0.8, user_language=user_lang
        )

        if not ai_response:
            ai_response = self._create_fallback_response(user_input, is_tourism)

        self.conversation.add_message("user", user_input)
        self.conversation.add_message("assistant", ai_response)
        return ai_response
    
    def _create_fallback_response(self, user_input: str, is_tourism: bool) -> str:
        """Fallback when AI is not available"""
        user_lang = self.detect_language(user_input)
        
        # Header strings for when landmarks are found
        header_map = {
            'arabic':     '🏛️ إليك ما وجدته:',
            'hebrew':     ':הנה מה שמצאתי 🏛️',
            'persian':    '🏛️ این چیزی است که من پیدا کردم:',
            'greek':      '🏛️ Δείτε τι βρήκα:',
            'russian':    '🏛️ Вот что я нашел:',
            'chinese':    '🏛️ 这是我发现的：',
            'thai':       '🏛️ นี่คือสิ่งที่ฉันพบ:',
            'hindi':      '🏛️ यहाँ मुझे क्या मिला:',
            'french':     '🏛️ Voici ce que j\'ai trouvé :',
            'spanish':    '🏛️ Aquí está lo que encontré:',
            'german':     '🏛️ Hier ist, was ich gefunden habe:',
            'italian':    '🏛️ Ecco cosa ho trovato:',
            'portuguese': '🏛️ Aqui está o que eu encontrei:',
            'japanese':   '🏛️ 私が見つけたものは次のとおりです。',
            'korean':     '🏛️ 제가 찾은 결과는 다음과 같습니다.',
            'english':    '🏛️ Here\'s what I found:',
        }

        # General tourism fallback (no specific landmarks found)
        tourism_fallback_map = {
            'arabic':     '🏛️ مصر فيها أماكن كتير رائعة! قولي إيه اللي بيشدك - أهرامات، متاحف، ولا شواطئ؟',
            'hebrew':     'מצרים מלאה במקומות מדהימים! ספר לי מה מעניין אותך - פירמידות, מוזיאונים או חופים? 🏛️',
            'persian':    '🏛️ مصر مکان‌های شگفت‌انگیز زیادی دارد! به من بگو چه چیزی برایت جالب است - اهرام، موزه‌ها یا سواحل؟',
            'greek':      '🏛️ Η Αίγυπτος έχει τόσα πολλά καταπληκτικά μέρη! Πείτε μου τι σας ενδιαφέρει - πυραμίδες, μουσεία ή παραλίες;',
            'russian':    '🏛️ В Египте так много удивительных мест! Расскажите, что вас интересует — пирамиды, музеи или пляжи?',
            'chinese':    '🏛️ 埃及有许多神奇的地方！告诉我你感兴趣的是什么——金字塔、博物馆还是海滩？',
            'thai':       '🏛️ อียิปต์มีสถานที่ที่น่าตื่นตาตื่นใจมากมาย! บอกฉันว่าคุณสนใจอะไร - พีระมิด พิพิธภัณฑ์ หรือชายหาด?',
            'hindi':      '🏛️ मिस्र में बहुत सारे अद्भुत स्थान हैं! मुझे बताएं कि आपकी रुचि किसमें है - पिरामिд, संग्रहालय या समुद्र तट?',
            'french':     '🏛️ L\'Égypte regorge de lieux incroyables ! Dites-moi ce qui vous intéresse : pyramides, musées ou plages ?',
            'spanish':    '🏛️ ¡Egipto tiene tantos lugares increíbles! Dime qué te interesa: ¿pirámides, museos o playas?',
            'german':     '🏛️ Ägypten hat so viele tolle Orte! Sag mir, was dich interessiert – Pyramiden, Museen oder Strände?',
            'italian':    '🏛️ L\'Egitto ha così tanti posti meravigliosi! Dimmi cosa ti interessa: piramidi, musei o spiagge?',
            'portuguese': '🏛️ O Egito tem tantos lugares incríveis! Diga-me o que lhe interessa - pirâmides, museus ou praias?',
            'japanese':   '🏛️ エジプトには素晴らしい場所がたくさんあります！ピラミッド、博物館、ビーチなど、何に興味があるか教えてください。',
            'korean':     '🏛️ 이집트에는 놀라운 곳이 정말 많아요! 피라미드, 박물관, 해변 중 어디에 관심이 있는지 알려주세요.',
            'english':    '🏛️ Egypt has so many amazing places! Tell me what interests you - pyramids, museums, beaches?',
        }

        # Casual chat fallback
        casual_fallback_map = {
            'arabic':     'أهلاً بك! 😊 أنا فهمي، صديقك السياحي في مصر. تحب تعرف إيه عن مصر؟',
            'hebrew':     'היי שם! 😊 אני פהמי, חברך לטיולים במצרים. מה תרצה לדעת על מצרים?',
            'persian':    'سلام! 😊 من فهمی هستم، دوست گردشگری شما در مصر. چه چیزی می‌خواهید درباره مصر بدانید؟',
            'greek':      'Γεια σας! 😊 Είμαι ο Fahmy, ο φίλος σας για τον τουρισμό στην Αίγυπτο. Τι θα θέλατε να μάθετε για την Αίγυπτο;',
            'russian':    'Привет! 😊 Я Фахми, ваш друг-путеводитель по Египту. Что бы вы хотели узнать о Египте?',
            'chinese':    '你好！😊 我是法赫米，你的埃及旅游朋友。你想了解关于埃及的什么？',
            'thai':       'สวัสดี! 😊 ฉันคือฟะฮ์มี เพื่อนร่วมทางท่องเที่ยวอียิปต์ของคุณ คุณอยากรู้อะไรเกี่ยวกับอียิปต์บ้าง?',
            'hindi':      'नमस्ते! 😊 मैं फहमी हूँ, मिस्र का आपका पर्यटन मित्र। आप मिस्र के बारे में क्या जानना चाहेंगे?',
            'french':     'Salut ! 😊 Je suis Fahmy, votre ami touristique en Égypte. Que aimeriez-vous savoir sur l\'Égypte ?',
            'spanish':    '¡Hola! 😊 Soy Fahmy, tu amigo de turismo en Egipto. ¿Qué te gustaría saber sobre Egipto?',
            'german':     'Hallo! 😊 Ich bin Fahmy, dein ägyptischer Tourismusfreund. Was möchtest du über Ägypten wissen?',
            'italian':    'Ciao! 😊 Sono Fahmy, il tuo amico per il turismo in Egitto. Cosa ti piacerebbe sapere sull\'Egitto?',
            'portuguese': 'Olá! 😊 Eu sou Fahmy, seu amigo de turismo no Egito. O que você gostaria de saber sobre o Egito?',
            'japanese':   'こんにちは！😊 私はファーミー、あなたのエジプト観光の友達です。エジプトについて何を知りたいですか？',
            'korean':     '안녕하세요! 😊 저는 파미입니다. 당신의 이집트 관광 친구죠. 이집트에 대해 무엇을 알고 싶으신가요?',
            'english':    'Hey there! 😊 I\'m Fahmy, your Egyptian tourism friend. What would you like to know about Egypt?',
        }

        if is_tourism:
            landmarks = self.knowledge_base.search_landmarks(user_input, limit=2)
            if landmarks:
                header = header_map.get(user_lang, header_map['english'])
                response = f"{header}\n\n"
                for lm in landmarks:
                    response += f"**{lm['name']}** ({lm['city']})\n"
                    response += f"*{lm['subcategory']}* | Rating: {lm['rating']}/5\n"
                    response += f"{lm['description'][:200]}...\n\n"
                return response
            
            return tourism_fallback_map.get(user_lang, tourism_fallback_map['english'])
        
        return casual_fallback_map.get(user_lang, casual_fallback_map['english'])
    
    def _create_farewell(self) -> str:
        """Create a language-aware farewell message based on the user's conversation language."""
        # Detect language from the last user message in conversation history
        last_user_lang = 'english'
        for msg in reversed(self.conversation.history):
            if msg.get('role') == 'user':
                last_user_lang = self.detect_language(msg.get('content', ''))
                break

        farewell_map = {
            'arabic':     'مع السلامة يا صديقي! مصر دايماً مستنياك 🏛️✨',
            'hebrew':     '!להתראות חברי! מצרים תמיד מחכה לך 🏛️✨',
            'persian':    'خداحافظ دوستم! مصر همیشه منتظر توست 🏛️✨',
            'greek':      'Αντίο φίλε! Η Αίγυπτος σε περιμένει πάντα! 🏛️✨',
            'russian':    'До свидания, друг! Египет всегда ждёт тебя! 🏛️✨',
            'chinese':    '再见，朋友！埃及永远欢迎你！🏛️✨',
            'thai':       'ลาก่อนเพื่อน! อียิปต์รอต้อนรับคุณเสมอ! 🏛️✨',
            'hindi':      'अलविदा दोस्त! मिस्र हमेशा आपका स्वागत करता है! 🏛️✨',
            'french':     "Au revoir mon ami! L'Égypte vous attend toujours! 🏛️✨",
            'spanish':    '¡Hasta luego amigo! ¡Que tus aventuras en Egipto sean inolvidables! 🏛️',
            'german':     'Auf Wiedersehen! Ägypten wartet immer auf dich! 🏛️✨',
            'italian':    "Arrivederci amico! L'Egitto ti aspetta sempre! 🏛️✨",
            'portuguese': 'Até logo amigo! O Egito sempre te espera! 🏛️✨',
            'japanese':   'さようなら！エジプトはいつもあなたを歓迎します！🏛️✨',
            'korean':     '안녕히 가세요! 이집트는 항상 당신을 환영합니다! 🏛️✨',
            'english':    '🏛️ Safe travels, my friend! Egypt will always welcome you with open arms. ✨',
        }

        farewell = farewell_map.get(last_user_lang, farewell_map['english'])

        if self.stats['total_queries'] > 0:
            stats = (
                f"\n\n[Chat Summary: {self.stats['total_queries']} messages "
                f"({self.stats['tourism_queries']} about Egypt, "
                f"{self.stats['casual_queries']} casual)]"
            )
            return farewell + stats

        return farewell
    
    def print_response_stream(self):
        """For streaming output in main loop"""
        print(f"\n🏛️ Fahmy: ", end='', flush=True)

# ============================================================================
# MAIN INTERFACE
# ============================================================================

def main():
    """Main chatbot interface with streaming"""
    sys.stdout.reconfigure(encoding='utf-8')

    # Check for --rebuild-index flag
    rebuild = '--rebuild-index' in sys.argv

    # Automatically configure Ollama from command line if provided
    for arg in sys.argv[1:]:
        if arg.startswith('http'):
            CONFIG["ollama_base_url"] = f"{arg.rstrip('/')}/api"

    chatbot = EgyptianTourismChatbot(rebuild_index=rebuild)
    
    print("\n💬 Start chatting! (Type 'exit' to quit)\n")
    
    while True:
        try:
            user_input = input("\n👤 You: ").strip()
            
            if not user_input:
                continue
            
            # Print header
            chatbot.print_response_stream()
            
            # Stream the response
            is_farewell = False
            for chunk in chatbot.process_query_stream(user_input):
                if chunk:
                    print(chunk, end='', flush=True)
                    # Check if this is a farewell message
                    chunk_lower = chunk.lower()
                    farewell_markers = [
                        'farewell', 'safe travels', 'until we meet',
                        'مع السلامة', 'au revoir', 'hasta luego',
                        'auf wiedersehen', 'arrivederci', 'até logo',
                        'до свидания', '再见', 'さようなら',
                        '안녕히', 'अलविदा', 'αντίο', 'ลาก่อน',
                        'להתראות', 'خداحافظ', 'chat summary'
                    ]
                    if any(marker in chunk_lower for marker in farewell_markers):
                        is_farewell = True
            
            print()  # New line after streaming
            
            if is_farewell:
                break
            
        except KeyboardInterrupt:
            print("\n\n🏛️ Thanks for chatting! مع السلامة! ✨")
            break
        except Exception:
            print("\n⚠️ Let's keep going...\n")

# ============================================================================
# EXAMPLE CONVERSATIONS
# ============================================================================

def run_example_conversations():
    """Run example conversations to demonstrate capabilities"""
    
    # Skip configuration and initialization messages
    if len(sys.argv) > 1:
        url_arg = sys.argv[1]
        if url_arg.startswith('http'):
            CONFIG["ollama_base_url"] = f"{url_arg.rstrip('/')}/api"
    
    chatbot = EgyptianTourismChatbot()
    examples = [
        "Hello! How are you?",
        "مرحباً! عامل إيه؟",
        "Tell me about the pyramids",
        "أنا عايز أعرف عن المتحف المصري",
        "What's the best time to visit Egypt?",
        "Thanks! Goodbye!"
    ]
    
    print("\n" + "="*70)
    print("EXAMPLE MULTILINGUAL CONVERSATION")
    print("="*70 + "\n")
    
    for query in examples:
        print(f"\n👤 You: {query}")
        chatbot.print_response_stream()
        
        for chunk in chatbot.process_query_stream(query):
            if chunk:
                print(chunk, end='', flush=True)
        
        print()
        time.sleep(1.5)
    
    print("\n" + "="*70)
    print("END OF DEMO")
    print("="*70 + "\n")

# ============================================================================
# ENTRY POINT - NO CONFIGURATION MENU
# ============================================================================

if __name__ == "__main__":
    # Handle command line arguments
    if len(sys.argv) > 1 and sys.argv[1] == "--demo":
        run_example_conversations()
    elif len(sys.argv) > 1 and sys.argv[1] == "--test":
        # Silent test - don't show output
        ai_core = AICore()
        if ai_core.available:
           
            pass
        else:
            # Failure, show minimal error
            print("❌ Ollama connection failed")
    else:
        
        main()