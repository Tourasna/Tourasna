# ai_tourism_chatbot.py
# Fully AI-Powered Egyptian Tourism Chatbot - Fahmy 
# ============================================================================

import os
import re
import time
import pandas as pd
import numpy as np
from typing import Dict, List, Optional, Tuple
import json
from datetime import datetime
import requests  # Added for API calls
import sys
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATASET_PATH = os.path.join(BASE_DIR, 'filtered_landmark_dataset.csv')

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

class KnowledgeBase:
    """Load and manage tourism knowledge from dataset"""
    
    def __init__(self):
        self.landmarks = {}
        self.embeddings = {}
        self.cities = set()
        self.categories = set()
        self._load_dataset()
        
    def _load_dataset(self):
        """Load and process the tourism dataset"""
        try:
            df = pd.read_csv(DATASET_PATH)
            
            # Process each landmark
            for idx, row in df.iterrows():
                landmark_id = f"landmark_{idx}"
                
                # Create comprehensive description
                description = self._create_landmark_description(row)
                
                # Store landmark
                self.landmarks[landmark_id] = {
                    "id": landmark_id,
                    "name": str(row['name']),
                    "city": str(row['city']),
                    "subcategory": str(row['subcategory']) if pd.notna(row['subcategory']) else "Attraction",
                    "rating": float(row['rating']) if pd.notna(row['rating']) else 0.0,
                    "address": str(row['address']) if pd.notna(row['address']) else "",
                    "latitude": row['latitude'] if pd.notna(row['latitude']) else None,
                    "longitude": row['longitude'] if pd.notna(row['longitude']) else None,
                    "description": description,
                    "full_text": self._create_full_text(row)
                }
                
                # Add to sets
                self.cities.add(str(row['city']))
                if pd.notna(row['subcategory']):
                    self.categories.add(str(row['subcategory']))
            
        except Exception as e:
            self.landmarks = {}

    
    def _create_landmark_description(self, row):
        """Create a rich description for a landmark"""
        name = str(row['name'])
        city = str(row['city'])
        category = str(row['subcategory']) if pd.notna(row['subcategory']) else "attraction"
        rating = row['rating'] if pd.notna(row['rating']) else "Not rated"
        address = str(row['address'])[:100] if pd.notna(row['address']) else "Location varies"
        
        description = f"{name} is a {category.lower()} located in {city}. "
        
        if pd.notna(row['rating']):
            description += f"It has a rating of {rating}/5. "
        
        # Add category-specific details
        if "Museum" in category:
            description += f"This museum showcases Egyptian culture and history. "
        elif "Nature" in category or "Park" in category:
            description += f"This natural attraction offers beautiful scenery. "
        elif "Shopping" in category:
            description += f"This shopping destination has various stores and goods. "
        elif "Sights" in category:
            description += f"This historical site is worth visiting. "
        
        description += f"The address is {address}."
        return description
    
    def _create_full_text(self, row):
        """Create full text representation for search"""
        text = f"{row['name']} in {row['city']}. "
        if pd.notna(row['subcategory']):
            text += f"Category: {row['subcategory']}. "
        if pd.notna(row['rating']):
            text += f"Rating: {row['rating']}/5. "
        if pd.notna(row['address']):
            text += f"Address: {row['address'][:150]}. "
        return text
    
    def search_landmarks(self, query: str, limit: int = 5) -> List[Dict]:
        """Search landmarks by name or description"""
        query = query.lower()
        results = []
        
        for landmark in self.landmarks.values():
            score = 0
            
            # Name match
            if query in landmark['name'].lower():
                score += 3
            
            # City match
            if query in landmark['city'].lower():
                score += 2
            
            # Category match
            if query in landmark['subcategory'].lower():
                score += 1
            
            # Description match
            if query in landmark['description'].lower():
                score += 1
            
            if score > 0:
                results.append((score, landmark))
        
        # Sort by score
        results.sort(key=lambda x: x[0], reverse=True)
        return [item[1] for item in results[:limit]]
    
    def get_landmarks_by_city(self, city: str) -> List[Dict]:
        """Get all landmarks in a city"""
        city_lower = city.lower()
        return [lm for lm in self.landmarks.values() if city_lower in lm['city'].lower()]
    
    def get_landmarks_by_category(self, category: str) -> List[Dict]:
        """Get all landmarks in a category"""
        category_lower = category.lower()
        return [lm for lm in self.landmarks.values() if category_lower in lm['subcategory'].lower()]

# ============================================================================
# AI CORE - OLLAMA INTEGRATION WITH API
# ============================================================================

class AICore:
    """Core AI functionality using Ollama API"""
    
    def __init__(self):
        self.model = CONFIG["ollama_model"]
        self.base_url = CONFIG["ollama_base_url"]
        self.timeout = CONFIG["ollama_timeout"]
        self.use_api_directly = CONFIG["use_api_directly"]
        self.available = False
        self._init_ollama()
    
    def _init_ollama(self):
        try:
            models_url = f"{self.base_url}/tags"
            response = requests.get(models_url, timeout=5)

            if response.status_code != 200:
                self.available = False
                return

            models = response.json().get("models", [])
            model_names = [m["name"] for m in models]

            if self.model not in model_names:
                print(f"⚠️ Model '{self.model}' not found. Available:", model_names)
                self.available = False
                return

            self.available = True

        except Exception as e:
            print("❌ Ollama init failed:", e)
            self.available = False

    
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
                                 temperature: float = 0.8):
        """Generate AI response with streaming"""
        if not self.available:
            yield None
            return
        
        try:
            # Prepare messages
            messages = []
            
            # System prompt with context
            system_prompt = self._create_system_prompt(context)
            messages.append({"role": "system", "content": system_prompt})
            
            # Add conversation history
            if conversation_history:
                messages.extend(conversation_history[-6:])
            
            # Add current user input
            messages.append({"role": "user", "content": user_input})
            
            # Prepare options
            options = {
                "temperature": temperature,
                "num_predict": 800,
                "top_p": 0.9,
                "repeat_penalty": 1.1
            }
            
            # Stream response
            if self.use_api_directly:
                for chunk in self._api_chat_stream(messages, options):
                    yield chunk
            else:
                # Fallback to non-streaming
                response = self._library_chat(messages, options)
                if response:
                    # Simulate streaming
                    for char in response:
                        yield char
                        time.sleep(0.01)
            
        except Exception:
            yield None
    
    def generate_response(self, 
                         user_input: str, 
                         context: str = "", 
                         conversation_history: List[Dict] = None,
                         temperature: float = 0.8) -> Optional[str]:
        """Generate AI response (non-streaming fallback)"""
        if not self.available:
            return None
        
        try:
            messages = []
            system_prompt = self._create_system_prompt(context)
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
    
    def _create_system_prompt(self, context: str) -> str:
        """Create system prompt for the AI"""
        prompt = """You are Fahmy (فهمي), an Egyptian Tourism Guide AI. Your name means "understanding" in Arabic.

CORE IDENTITY:
- You're warm, genuine, and deeply passionate about Egypt
- You speak naturally like a knowledgeable friend, not a formal assistant
- You're multilingual and ALWAYS respond in the SAME LANGUAGE the user speaks to you in
- You adapt your tone to match the conversation - casual for chit-chat, informative for serious queries

MULTILINGUAL BEHAVIOR (CRITICAL):
- If user writes in Arabic, respond completely in Arabic
- If user writes in English, respond completely in English
- If user writes in French, respond completely in French
- If user mixes languages, use the dominant language in their message
- NEVER switch languages mid-response unless the user does
- Maintain natural, native-speaker quality in each language

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

KNOWLEDGE BASE:
{context}

HOW TO USE THE KNOWLEDGE:
- Weave facts naturally into conversation
- Don't just dump information - tell stories
- Connect landmarks to broader Egyptian culture
- Share practical tips from a local's perspective
- Make recommendations based on user interests

EXAMPLES OF YOUR STYLE:

User (English): "Tell me about the pyramids"
You: "Oh, the pyramids! They never get old for me. The Great Pyramid of Giza is absolutely mind-blowing - it's the oldest of the Seven Wonders and the only one still standing. When you see it in person, the sheer scale is incredible. Have you ever seen them before, or would this be your first time?"

User (Arabic): "أنا عايز أعرف عن المتحف المصري"
You: "المتحف المصري في القاهرة ده حاجة تانية خالص! فيه أكتر من ١٢٠ ألف قطعة أثرية، وكنوز توت عنخ آمون طبعاً اللي بتخطف الأنظار. لو بتحب التاريخ الفرعوني، المكان ده هيبهرك. إنت بتفكر تزوره امتى؟"

User (French): "Quels sont les meilleurs endroits au Caire?"
You: "Ah, Le Caire! C'est une ville fascinante avec tellement à voir. Je te recommanderais de commencer par les pyramides de Gizeh bien sûr, puis le Musée égyptien au centre-ville. Le bazar de Khan el-Khalili est incroyable pour l'ambiance et les souvenirs. Tu cherches plutôt des sites historiques ou tu veux aussi découvrir la vie moderne du Caire?"

REMEMBER:
- Be helpful but conversational
- Show personality and warmth
- ALWAYS match the user's language
- Make Egypt come alive through your words
- Be the friend who knows Egypt inside and out"""
        
        return prompt.format(context=context if context else "General Egyptian tourism knowledge available.")
    
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
        
        cities = ['cairo', 'giza', 'luxor', 'aswan', 'alexandria', 'sharm', 'hurghada',
                 'القاهرة', 'الجيزة', 'الأقصر', 'أسوان', 'الإسكندرية']
        for city in cities:
            if city in text_lower:
                interests.append(city)
        
        categories = ['museum', 'pyramid', 'temple', 'shopping', 'park', 'nature', 
                     'beach', 'desert', 'market', 'bazaar', 'restaurant',
                     'متحف', 'هرم', 'معبد', 'سوق', 'شاطئ']
        for category in categories:
            if category in text_lower:
                interests.append(category)
        
        return interests
    
    def update_context(self, knowledge_base: KnowledgeBase, user_input: str) -> str:
        """Update context based on conversation"""
        relevant_landmarks = knowledge_base.search_landmarks(user_input, limit=3)
        
        context_parts = []
        
        if relevant_landmarks:
            context_parts.append("RELEVANT LANDMARKS:")
            for lm in relevant_landmarks:
                context_parts.append(f"- {lm['name']} ({lm['city']}): {lm['description']}")
        
        if self.user_interests:
            context_parts.append(f"\nUSER INTERESTS: {', '.join(self.user_interests)}")
        
        context_parts.append(f"\nCONVERSATION MODE: {self.conversation_mode}")
        
        self.context = "\n".join(context_parts)
        return self.context

# ============================================================================
# MAIN CHATBOT
# ============================================================================

class EgyptianTourismChatbot:
    """Main chatbot class - Fully AI-driven"""
    
    def __init__(self):
        # Initialize components SILENTLY
        self.knowledge_base = KnowledgeBase()
        self.ai_core = AICore()
        self.conversation = ConversationManager()
        
        self.stats = {
            "total_queries": 0,
            "tourism_queries": 0,
            "casual_queries": 0
        }
        # Check if we're in limited mode without showing it to user
        if not self.ai_core.available:
            # We don't show this to the user - it will just use fallback responses
            pass
    
    def process_query_stream(self, user_input: str):
        """Process user input and generate streaming response"""
        self.stats["total_queries"] += 1
        
        # Check for exit
        if user_input.lower() in ['exit', 'quit', 'bye', 'goodbye', 'خروج', 'مع السلامة']:
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
        
        # Update context
        context = self.conversation.update_context(self.knowledge_base, user_input)
        
        # Generate streaming response
        full_response = ""
        if self.ai_core.available:
            for chunk in self.ai_core.generate_response_stream(
                user_input=user_input,
                context=context,
                conversation_history=self.conversation.get_recent_history(),
                temperature=0.8
            ):
                if chunk:
                    full_response += chunk
                    yield chunk
        else:
            # Fallback
            fallback = self._create_fallback_response(user_input, is_tourism)
            full_response = fallback
            for char in fallback:
                yield char
                time.sleep(0.01)
        
        # Add to history
        self.conversation.add_message("user", user_input)
        self.conversation.add_message("assistant", full_response)
    
    def process_query(self, user_input: str) -> str:
        """Non-streaming version"""
        self.stats["total_queries"] += 1
        
        if user_input.lower() in ['exit', 'quit', 'bye', 'goodbye', 'خروج', 'مع السلامة']:
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
        
        context = self.conversation.update_context(self.knowledge_base, user_input)
        
        ai_response = self.ai_core.generate_response(
            user_input=user_input,
            context=context,
            conversation_history=self.conversation.get_recent_history(),
            temperature=0.8
        )
        
        if not ai_response:
            ai_response = self._create_fallback_response(user_input, is_tourism)
        
        self.conversation.add_message("user", user_input)
        self.conversation.add_message("assistant", ai_response)
        
        return ai_response
    
    def _create_fallback_response(self, user_input: str, is_tourism: bool) -> str:
        """Fallback when AI is not available"""
        if is_tourism:
            landmarks = self.knowledge_base.search_landmarks(user_input, limit=2)
            if landmarks:
                response = "🏛️ Here's what I found:\n\n"
                for lm in landmarks:
                    response += f"**{lm['name']}** ({lm['city']})\n"
                    response += f"*{lm['subcategory']}* | Rating: {lm['rating']}/5\n"
                    response += f"{lm['description'][:200]}...\n\n"
                return response
            
            return "🏛️ Egypt has so many amazing places! Tell me what interests you - pyramids, museums, beaches?"
        
        return "Hey there! 😊 I'm Fahmy, your Egyptian tourism friend. What would you like to know about Egypt?"
    
    def _create_farewell(self) -> str:
        """Create farewell message"""
        import random
        farewells = [
            "🏛️ Safe travels, my friend! Egypt will always welcome you with open arms. ✨",
            "👋 Until we meet again! May your Egyptian adventures be unforgettable!",
            "مع السلامة يا صديقي! مصر دايماً مستنياك 🏛️✨",
            "🌟 Take care! Remember, I'm here whenever you want to talk about Egypt!"
        ]
        
        farewell = random.choice(farewells)
        
        if self.stats["total_queries"] > 0:
            stats = f"\n\n[Chat Summary: {self.stats['total_queries']} messages "
            stats += f"({self.stats['tourism_queries']} about Egypt, {self.stats['casual_queries']} casual)]"
            return farewell + stats
        
        return farewell