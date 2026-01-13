# fahmy_chatbot_ultimate.py - ULTIMATE UNIFIED VERSION
# Combines: Ollama (Mistral 7B) + DL Recommendation Model + Smart Conversation
# Author: Tourasna Team
# ============================================================================

import os
import sys
import re
import time
import json
import io
from contextlib import redirect_stdout, redirect_stderr
from typing import Dict, List, Optional, Tuple
from datetime import datetime
SESSIONS: Dict[str, "UltimateFahmy"] = {}
# ============================================================================
# CONFIGURATION
# ============================================================================

CONFIG = {
    "ollama_model": "mistral:7b",
    "ollama_timeout": 30,
    "max_recommendations": 10,
    "streaming_delay": 0.012,  # Typing effect delay
    "conversation_history_limit": 10,
    "debug_mode": True,  # ENABLED for testing - set to False in production
    "enable_streaming": True  # Enable/disable typing effect
}

# ============================================================================
# STREAMING OUTPUT HANDLER
# ============================================================================

class StreamingPrinter:
    """Handles streaming/typing effect for output"""
    
    @staticmethod
    def print_streaming(text: str, delay: float = None):
        """Print text with typing effect"""
        if delay is None:
            delay = CONFIG["streaming_delay"]
        
        if not CONFIG["enable_streaming"]:
            print(text)
            return
        
        for char in text:
            print(char, end='', flush=True)
            time.sleep(delay)
        print()  # New line at end
    
    @staticmethod
    def print_response(text: str, prefix: str = "🐫 Fahmy: "):
        """Print bot response with formatting and streaming"""
        print(f"\n{prefix}", end='', flush=True)
        
        if CONFIG["enable_streaming"]:
            for char in text:
                print(char, end='', flush=True)
                time.sleep(CONFIG["streaming_delay"])
            print()  # New line
        else:
            print(text)

# ============================================================================
# OLLAMA HANDLER (with fallback)
# ============================================================================

class OllamaHandler:
    """Handles Ollama integration with automatic fallback"""
    
    def __init__(self):
        self.is_available = False
        self.model = CONFIG["ollama_model"]
        self._check_ollama()
    
    def _check_ollama(self):
        """Check if Ollama is running and model is available"""
        try:
            import ollama
            # Test connection
            ollama.list()
            self.is_available = True
            print("[OLLAMA] ✅ Connected successfully")
        except ImportError:
            print("[OLLAMA] ⚠️ Library not installed (pip install ollama)")
            self.is_available = False
        except Exception as e:
            print(f"[OLLAMA] ⚠️ Not available: {str(e)[:50]}")
            self.is_available = False
    
    def chat(self, messages: List[Dict], temperature: float = 0.8, response_language: str = 'en') -> Optional[str]:
        """Get response from Ollama with explicit language instruction"""
        if not self.is_available:
            return None
        
        try:
            import ollama
            
            # Add language instruction to the last user message
            language_names = {
                'en': 'English', 'ar': 'Arabic', 'fr': 'French', 'de': 'German',
                'es': 'Spanish', 'it': 'Italian', 'pt': 'Portuguese', 'ru': 'Russian',
                'zh': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean', 'nl': 'Dutch',
                'pl': 'Polish', 'sv': 'Swedish', 'tr': 'Turkish', 'hi': 'Hindi',
                'th': 'Thai', 'vi': 'Vietnamese', 'id': 'Indonesian', 'el': 'Greek',
                'he': 'Hebrew'
            }
            
            lang_name = language_names.get(response_language, 'English')
            
            # Modify system prompt to enforce language
            modified_messages = []
            for msg in messages:
                if msg['role'] == 'system':
                    # Add strict language instruction to system prompt
                    lang_instruction = f"\n\nCRITICAL INSTRUCTION: You MUST respond ONLY in {lang_name}. Do NOT use any other language. Every word of your response must be in {lang_name}."
                    modified_messages.append({
                        'role': 'system',
                        'content': msg['content'] + lang_instruction
                    })
                else:
                    modified_messages.append(msg)
            
            response = ollama.chat(
                model=self.model,
                messages=modified_messages,
                options={
                    "temperature": temperature,
                    "top_p": 0.9,
                    "num_predict": 400,
                    "repeat_penalty": 1.1
                }
            )
            return response['message']['content']
        except Exception as e:
            if CONFIG["debug_mode"]:
                print(f"[OLLAMA ERROR] {e}")
            return None

# ============================================================================
# RECOMMENDATION ENGINE (connects to model_inference.py)
# ============================================================================

class RecommendationEngine:
    """Connects to the trained DL model for personalized recommendations"""
    
    def __init__(self):
        self.model = None
        self.all_categories = None
        self.unique_landmarks = None
        self.label_encoders = None
        self.model_config = None
        self.is_initialized = False
        
        # Available categories (must match training)
        self.default_categories = [
            'Fun & Games', 'Water & Amusement Parks', 'Outdoor Activities',
            'Concerts & Shows', 'Zoos & Aquariums', 'Shopping',
            'Nature & Parks', 'Sights & Landmarks', 'Museums', 'Traveler Resources'
        ]
    
    def initialize(self, recommendation_path: str = None) -> bool:
        """Initialize the recommendation engine"""
        if self.is_initialized:
            return True
        
        print("[REC ENGINE] Loading recommendation model...")
        
        # Find RecommendationSystem folder
        if recommendation_path is None:
            recommendation_path = self._find_recommendation_system()
        
        if recommendation_path is None:
            print("[REC ENGINE] ⚠️ RecommendationSystem not found, using fallback")
            self.all_categories = self.default_categories
            return True
        
        try:
            # Add to path
            if recommendation_path not in sys.path:
                sys.path.insert(0, recommendation_path)
            
            # Suppress output during loading
            original_dir = os.getcwd()
            os.chdir(recommendation_path)
            
            f = io.StringIO()
            with redirect_stdout(f), redirect_stderr(f):
                from model_inference import (
                    load_model_and_artifacts,
                    get_landmark_data
                )
                
                self.model, self.label_encoders, self.all_categories, self.model_config = load_model_and_artifacts()
                self.unique_landmarks = get_landmark_data()
            
            os.chdir(original_dir)
            
            if self.model is not None and self.unique_landmarks is not None:
                self.is_initialized = True
                landmark_count = len(self.unique_landmarks) if self.unique_landmarks is not None else 0
                print(f"[REC ENGINE] ✅ Loaded model with {landmark_count} landmarks")
                return True
            else:
                print("[REC ENGINE] ⚠️ Model loaded but incomplete")
                self.all_categories = self.default_categories
                return True
                
        except Exception as e:
            print(f"[REC ENGINE] ⚠️ Error loading model: {str(e)[:50]}")
            self.all_categories = self.default_categories
            try:
                os.chdir(original_dir)
            except:
                pass
            return True
    
    def _find_recommendation_system(self) -> Optional[str]:
        """Find the RecommendationSystem folder"""
        current_dir = os.path.dirname(os.path.abspath(__file__))
        
        possible_paths = [
            os.path.join(current_dir, "..", "RecommendationSystem"),
            os.path.join(current_dir, "RecommendationSystem"),
            os.path.join(os.path.dirname(current_dir), "RecommendationSystem"),
            os.path.join(current_dir, "..", "..", "RecommendationSystem"),
        ]
        
        for path in possible_paths:
            abs_path = os.path.abspath(path)
            if os.path.exists(abs_path):
                # Check for required files
                required = ["travel_recommendation_model.keras", "user_landmark_matches_1M.xls"]
                if all(os.path.exists(os.path.join(abs_path, f)) for f in required):
                    return abs_path
        
        return None
    
    def get_recommendations(self, user_profile: Dict, limit: int = 10) -> List[Dict]:
        """Get personalized recommendations for user profile"""
        
        # Ensure profile is in correct format (English)
        formatted_profile = self._format_profile(user_profile)
        
        if CONFIG["debug_mode"]:
            print(f"[DEBUG] Profile: {formatted_profile}")
        
        # Try using actual model
        if self.is_initialized and self.model is not None:
            try:
                recommendations = self._get_model_recommendations(formatted_profile, limit)
                if recommendations:
                    return recommendations
            except Exception as e:
                if CONFIG["debug_mode"]:
                    print(f"[DEBUG] Model error: {e}")
        
        # Fallback to rule-based recommendations
        return self._get_fallback_recommendations(formatted_profile, limit)
    
    def _format_profile(self, profile: Dict) -> Dict:
        """Ensure profile matches model_inference.py format (English)"""
        
        # Map any Arabic or variant inputs to English
        budget_map = {
            'منخفض': 'low', 'محدود': 'low', 'اقتصادي': 'low',
            'متوسط': 'medium', 'معتدل': 'medium',
            'عالي': 'high', 'مرتفع': 'high', 'فاخر': 'high',
            'low': 'low', 'medium': 'medium', 'high': 'high'
        }
        
        travel_type_map = {
            'منفرد': 'solo', 'وحدي': 'solo', 'alone': 'solo',
            'زوجين': 'couple', 'رومانسي': 'couple', 'romantic': 'couple',
            'عائلة': 'family', 'عائلي': 'family', 'kids': 'family',
            'فاخر': 'luxury', 'vip': 'luxury', 'premium': 'luxury',
            'solo': 'solo', 'couple': 'couple', 'family': 'family', 'luxury': 'luxury'
        }
        
        # Format profile
        formatted = {
            'user_age': int(profile.get('user_age', 25)),
            'user_gender': profile.get('user_gender', 'Not specified'),
            'user_budget': budget_map.get(str(profile.get('user_budget', 'medium')).lower(), 'medium'),
            'user_travel_type': travel_type_map.get(str(profile.get('user_travel_type', 'solo')).lower(), 'solo'),
            'user_preferences': self._map_preferences(profile.get('user_preferences', []))
        }
        
        # Ensure age is in valid range
        formatted['user_age'] = max(18, min(75, formatted['user_age']))
        
        # Ensure at least 2 preferences
        if len(formatted['user_preferences']) < 2:
            formatted['user_preferences'] = ['Museums', 'Sights & Landmarks']
        
        return formatted
    
    def _map_preferences(self, preferences: List[str]) -> List[str]:
        """Map user preferences to valid categories"""
        
        # Mapping of keywords to categories
        preference_map = {
            # English keywords
            'museum': 'Museums', 'history': 'Museums', 'art': 'Museums', 'artifact': 'Museums',
            'shop': 'Shopping', 'market': 'Shopping', 'mall': 'Shopping', 'bazaar': 'Shopping',
            'outdoor': 'Outdoor Activities', 'adventure': 'Outdoor Activities', 'hiking': 'Outdoor Activities',
            'diving': 'Outdoor Activities', 'safari': 'Outdoor Activities', 'cruise': 'Outdoor Activities',
            'nature': 'Nature & Parks', 'park': 'Nature & Parks', 'garden': 'Nature & Parks',
            'landmark': 'Sights & Landmarks', 'pyramid': 'Sights & Landmarks', 'temple': 'Sights & Landmarks',
            'monument': 'Sights & Landmarks', 'sight': 'Sights & Landmarks', 'historical': 'Sights & Landmarks',
            'zoo': 'Zoos & Aquariums', 'aquarium': 'Zoos & Aquariums', 'animal': 'Zoos & Aquariums',
            'concert': 'Concerts & Shows', 'show': 'Concerts & Shows', 'music': 'Concerts & Shows',
            'opera': 'Concerts & Shows', 'entertainment': 'Concerts & Shows',
            'fun': 'Fun & Games', 'game': 'Fun & Games', 'play': 'Fun & Games',
            'water park': 'Water & Amusement Parks', 'amusement': 'Water & Amusement Parks',
            'food': 'Traveler Resources', 'restaurant': 'Traveler Resources', 'cuisine': 'Traveler Resources',
            
            # Arabic keywords
            'متحف': 'Museums', 'تاريخ': 'Museums', 'اثار': 'Museums',
            'تسوق': 'Shopping', 'سوق': 'Shopping',
            'مغامرة': 'Outdoor Activities', 'رحلة': 'Outdoor Activities',
            'طبيعة': 'Nature & Parks', 'حديقة': 'Nature & Parks',
            'معلم': 'Sights & Landmarks', 'هرم': 'Sights & Landmarks', 'معبد': 'Sights & Landmarks',
            'حيوان': 'Zoos & Aquariums',
            'حفلة': 'Concerts & Shows', 'عرض': 'Concerts & Shows',
            'طعام': 'Traveler Resources', 'اكل': 'Traveler Resources'
        }
        
        mapped = []
        categories = self.all_categories or self.default_categories
        
        for pref in preferences:
            pref_lower = pref.lower().strip()
            
            # Direct match with category
            for cat in categories:
                if cat.lower() == pref_lower:
                    if cat not in mapped:
                        mapped.append(cat)
                    break
            else:
                # Keyword match
                for keyword, category in preference_map.items():
                    if keyword in pref_lower:
                        if category not in mapped:
                            mapped.append(category)
                        break
        
        return mapped if mapped else ['Museums', 'Sights & Landmarks']
    
    def _get_model_recommendations(self, profile: Dict, limit: int) -> List[Dict]:
        """Get recommendations using the trained model"""
        
        current_dir = os.path.dirname(os.path.abspath(__file__))
        rec_path = self._find_recommendation_system()
        
        if not rec_path:
            return []
        
        original_dir = os.getcwd()
        os.chdir(rec_path)
        
        try:
            f = io.StringIO()
            with redirect_stdout(f), redirect_stderr(f):
                from model_inference import get_recommendations as model_get_recs
                
                recommendations = model_get_recs(
                    profile,
                    self.model,
                    self.all_categories,
                    self.unique_landmarks
                )
            
            os.chdir(original_dir)
            return recommendations[:limit] if recommendations else []
            
        except Exception as e:
            os.chdir(original_dir)
            if CONFIG["debug_mode"]:
                print(f"[DEBUG] Model rec error: {e}")
            return []
    
    def _get_fallback_recommendations(self, profile: Dict, limit: int) -> List[Dict]:
        """Fallback recommendations when model unavailable"""
        
        # Egyptian landmarks database
        landmarks = [
            # Sights & Landmarks
            {'name': 'Pyramids of Giza', 'category': 'Sights & Landmarks', 'rating': 4.9,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family', 'luxury'],
             'description': 'The last remaining wonder of the ancient world'},
            {'name': 'Great Sphinx', 'category': 'Sights & Landmarks', 'rating': 4.8,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family', 'luxury'],
             'description': 'Iconic limestone statue guarding the pyramids'},
            {'name': 'Valley of the Kings', 'category': 'Sights & Landmarks', 'rating': 4.8,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Royal burial ground with 63 tombs'},
            {'name': 'Karnak Temple', 'category': 'Sights & Landmarks', 'rating': 4.9,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family', 'luxury'],
             'description': 'Largest ancient religious complex ever built'},
            {'name': 'Abu Simbel', 'category': 'Sights & Landmarks', 'rating': 4.9,
             'budget': 'high', 'travel_types': ['couple', 'luxury'],
             'description': 'Magnificent rock-cut temples of Ramesses II'},
            {'name': 'Luxor Temple', 'category': 'Sights & Landmarks', 'rating': 4.7,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Ancient temple complex in the heart of Luxor'},
            {'name': 'Philae Temple', 'category': 'Sights & Landmarks', 'rating': 4.6,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Temple dedicated to goddess Isis in Aswan'},
            
            # Museums
            {'name': 'Egyptian Museum', 'category': 'Museums', 'rating': 4.8,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family', 'luxury'],
             'description': 'Home to Tutankhamun treasures and 120,000 artifacts'},
            {'name': 'Grand Egyptian Museum', 'category': 'Museums', 'rating': 4.9,
             'budget': 'high', 'travel_types': ['solo', 'couple', 'family', 'luxury'],
             'description': 'Largest archaeological museum in the world'},
            {'name': 'Nubian Museum', 'category': 'Museums', 'rating': 4.7,
             'budget': 'low', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Showcasing Nubian culture and heritage'},
            {'name': 'Coptic Museum', 'category': 'Museums', 'rating': 4.5,
             'budget': 'low', 'travel_types': ['solo', 'couple'],
             'description': 'Largest collection of Coptic Christian artifacts'},
            {'name': 'Museum of Islamic Art', 'category': 'Museums', 'rating': 4.6,
             'budget': 'low', 'travel_types': ['solo', 'couple'],
             'description': 'Masterpieces of Islamic art from across the world'},
            
            # Shopping
            {'name': 'Khan el-Khalili', 'category': 'Shopping', 'rating': 4.5,
             'budget': 'low', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Historic bazaar since 1382, perfect for souvenirs'},
            {'name': 'City Stars Mall', 'category': 'Shopping', 'rating': 4.4,
             'budget': 'medium', 'travel_types': ['family', 'couple'],
             'description': 'Largest shopping mall in Cairo'},
            {'name': 'Mall of Egypt', 'category': 'Shopping', 'rating': 4.5,
             'budget': 'high', 'travel_types': ['family', 'couple', 'luxury'],
             'description': 'Modern mall with ski slope and entertainment'},
            
            # Outdoor Activities
            {'name': 'Nile Felucca Cruise', 'category': 'Outdoor Activities', 'rating': 4.6,
             'budget': 'low', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Traditional sailboat experience on the Nile'},
            {'name': 'Red Sea Diving', 'category': 'Outdoor Activities', 'rating': 4.8,
             'budget': 'high', 'travel_types': ['solo', 'couple'],
             'description': 'World-class diving in crystal clear waters'},
            {'name': 'Desert Safari', 'category': 'Outdoor Activities', 'rating': 4.5,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Adventure in the Western Desert'},
            {'name': 'Hot Air Balloon Luxor', 'category': 'Outdoor Activities', 'rating': 4.9,
             'budget': 'high', 'travel_types': ['couple', 'luxury'],
             'description': 'Sunrise balloon ride over Valley of Kings'},
            {'name': 'Snorkeling Sharm El Sheikh', 'category': 'Outdoor Activities', 'rating': 4.7,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Explore colorful coral reefs'},
            
            # Nature & Parks
            {'name': 'Al-Azhar Park', 'category': 'Nature & Parks', 'rating': 4.6,
             'budget': 'low', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Beautiful park with panoramic Cairo views'},
            {'name': 'Ras Mohammed National Park', 'category': 'Nature & Parks', 'rating': 4.8,
             'budget': 'medium', 'travel_types': ['solo', 'couple'],
             'description': 'Protected marine reserve in Sinai'},
            {'name': 'White Desert', 'category': 'Nature & Parks', 'rating': 4.7,
             'budget': 'medium', 'travel_types': ['solo', 'couple'],
             'description': 'Surreal chalk rock formations'},
            {'name': 'Siwa Oasis', 'category': 'Nature & Parks', 'rating': 4.6,
             'budget': 'medium', 'travel_types': ['solo', 'couple'],
             'description': 'Remote desert oasis with ancient culture'},
            
            # Concerts & Shows
            {'name': 'Cairo Opera House', 'category': 'Concerts & Shows', 'rating': 4.7,
             'budget': 'high', 'travel_types': ['couple', 'luxury'],
             'description': 'Premier venue for performing arts'},
            {'name': 'Sound & Light Show Pyramids', 'category': 'Concerts & Shows', 'rating': 4.4,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Spectacular nighttime show at the pyramids'},
            {'name': 'Tanoura Dance Show', 'category': 'Concerts & Shows', 'rating': 4.6,
             'budget': 'low', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Traditional Sufi whirling dance'},
            
            # Fun & Games
            {'name': 'KidZania Cairo', 'category': 'Fun & Games', 'rating': 4.5,
             'budget': 'medium', 'travel_types': ['family'],
             'description': 'Interactive city for children'},
            {'name': 'Magic Planet', 'category': 'Fun & Games', 'rating': 4.3,
             'budget': 'medium', 'travel_types': ['family'],
             'description': 'Indoor amusement center'},
            
            # Zoos & Aquariums
            {'name': 'Giza Zoo', 'category': 'Zoos & Aquariums', 'rating': 4.0,
             'budget': 'low', 'travel_types': ['family'],
             'description': 'Historic zoo founded in 1891'},
            {'name': 'Hurghada Grand Aquarium', 'category': 'Zoos & Aquariums', 'rating': 4.5,
             'budget': 'medium', 'travel_types': ['family', 'couple'],
             'description': 'Marine life showcase on the Red Sea'},
            
            # Water & Amusement Parks
            {'name': 'Aqua Park Cairo', 'category': 'Water & Amusement Parks', 'rating': 4.3,
             'budget': 'medium', 'travel_types': ['family'],
             'description': 'Water slides and pools for all ages'},
            {'name': 'Dream Park', 'category': 'Water & Amusement Parks', 'rating': 4.2,
             'budget': 'medium', 'travel_types': ['family'],
             'description': 'Amusement park with rides and attractions'},
            
            # Traveler Resources (Food & Tours)
            {'name': 'Egyptian Cooking Class', 'category': 'Traveler Resources', 'rating': 4.8,
             'budget': 'medium', 'travel_types': ['solo', 'couple'],
             'description': 'Learn to cook traditional Egyptian dishes'},
            {'name': 'Cairo Food Tour', 'category': 'Traveler Resources', 'rating': 4.7,
             'budget': 'medium', 'travel_types': ['solo', 'couple', 'family'],
             'description': 'Taste authentic Egyptian street food'},
            {'name': 'Nile Dinner Cruise', 'category': 'Traveler Resources', 'rating': 4.6,
             'budget': 'high', 'travel_types': ['couple', 'luxury'],
             'description': 'Fine dining with entertainment on the Nile'},
        ]
        
        # Score landmarks based on profile
        scored = []
        user_prefs_lower = [p.lower() for p in profile['user_preferences']]
        
        for landmark in landmarks:
            score = 0.5  # Base score
            
            # Category match (+0.4)
            if landmark['category'].lower() in user_prefs_lower or \
               any(pref in landmark['category'].lower() for pref in user_prefs_lower):
                score += 0.4
            
            # Budget match (+0.3)
            if landmark['budget'] == profile['user_budget']:
                score += 0.3
            elif profile['user_budget'] == 'high':  # High budget can access all
                score += 0.15
            elif profile['user_budget'] == 'medium' and landmark['budget'] == 'low':
                score += 0.2
            
            # Travel type match (+0.3)
            if profile['user_travel_type'] in landmark['travel_types']:
                score += 0.3
            
            landmark['dl_score'] = min(score, 1.0)
            scored.append(landmark)
        
        # Sort by score
        scored.sort(key=lambda x: (x['dl_score'], x['rating']), reverse=True)
        
        # Apply diversity
        return self._apply_diversity(scored, profile['user_preferences'])[:limit]
    
    def _apply_diversity(self, landmarks: List[Dict], preferences: List[str]) -> List[Dict]:
        """Ensure diverse recommendations across categories"""
        
        prefs_lower = [p.lower() for p in preferences]
        by_category = {pref: [] for pref in prefs_lower}
        others = []
        
        for landmark in landmarks:
            cat_lower = landmark['category'].lower()
            matched = False
            for pref in prefs_lower:
                if pref in cat_lower or cat_lower in pref:
                    by_category[pref].append(landmark)
                    matched = True
                    break
            if not matched:
                others.append(landmark)
        
        # Select diverse set
        selected = []
        selected_names = set()
        
        # Take 2-3 from each preferred category
        for pref in prefs_lower:
            count = 0
            for landmark in by_category.get(pref, []):
                if landmark['name'] not in selected_names and count < 3:
                    selected.append(landmark)
                    selected_names.add(landmark['name'])
                    count += 1
        
        # Fill remaining from preferred categories
        for pref in prefs_lower:
            for landmark in by_category.get(pref, []):
                if landmark['name'] not in selected_names and len(selected) < 10:
                    selected.append(landmark)
                    selected_names.add(landmark['name'])
        
        # Add from others if needed
        for landmark in others:
            if landmark['name'] not in selected_names and len(selected) < 10:
                selected.append(landmark)
                selected_names.add(landmark['name'])
        
        return selected

# ============================================================================
# USER PROFILE MANAGER
# ============================================================================

class UserProfileManager:
    """Manages user profile collection and updates"""
    
    def __init__(self):
        self.profile = {
            'user_age': None,
            'user_gender': 'Not specified',
            'user_budget': None,
            'user_travel_type': None,
            'user_preferences': []
        }
        self.collection_state = 'idle'  # idle, collecting, complete
    
    def reset(self):
        """Reset profile to defaults"""
        self.profile = {
            'user_age': None,
            'user_gender': 'Not specified',
            'user_budget': None,
            'user_travel_type': None,
            'user_preferences': []
        }
        self.collection_state = 'idle'
    
    def update_from_text(self, text: str) -> Dict[str, any]:
        """Extract and update profile from user text"""
        text_lower = text.lower()
        updates = {}
        
        # Age extraction
        age_patterns = [
            r"i[' ]?a?m\s*(\d+)",
            r"(\d+)\s*years?\s*old",
            r"age[:\s]+(\d+)",
            r"عمري\s*(\d+)",
            r"(\d+)\s*سنة"
        ]
        for pattern in age_patterns:
            match = re.search(pattern, text_lower)
            if match:
                age = int(match.group(1))
                if 18 <= age <= 75:
                    self.profile['user_age'] = age
                    updates['age'] = age
                break
        
        # Gender extraction
        if any(word in text_lower for word in ['male', 'man', 'رجل', 'ذكر']):
            self.profile['user_gender'] = 'Male'
            updates['gender'] = 'Male'
        elif any(word in text_lower for word in ['female', 'woman', 'انثى', 'امرأة']):
            self.profile['user_gender'] = 'Female'
            updates['gender'] = 'Female'
        
        # Budget extraction
        if any(word in text_lower for word in ['low budget', 'cheap', 'budget-friendly', 'اقتصادي', 'رخيص']):
            self.profile['user_budget'] = 'low'
            updates['budget'] = 'low'
        elif any(word in text_lower for word in ['high budget', 'luxury', 'expensive', 'premium', 'فاخر', 'غالي']):
            self.profile['user_budget'] = 'high'
            updates['budget'] = 'high'
        elif any(word in text_lower for word in ['medium', 'moderate', 'mid-range', 'متوسط']):
            self.profile['user_budget'] = 'medium'
            updates['budget'] = 'medium'
        
        # Travel type extraction
        if any(word in text_lower for word in ['solo', 'alone', 'by myself', 'وحدي', 'منفرد']):
            self.profile['user_travel_type'] = 'solo'
            updates['travel_type'] = 'solo'
        elif any(word in text_lower for word in ['couple', 'partner', 'romantic', 'boyfriend', 'girlfriend', 'wife', 'husband', 'زوجين']):
            self.profile['user_travel_type'] = 'couple'
            updates['travel_type'] = 'couple'
        elif any(word in text_lower for word in ['family', 'kids', 'children', 'عائلة', 'اطفال']):
            self.profile['user_travel_type'] = 'family'
            updates['travel_type'] = 'family'
        elif any(word in text_lower for word in ['luxury', 'vip', 'premium', 'فاخر']):
            self.profile['user_travel_type'] = 'luxury'
            updates['travel_type'] = 'luxury'
        
        # Preferences extraction
        preference_keywords = {
            'museum': 'Museums', 'history': 'Museums', 'artifact': 'Museums', 'متحف': 'Museums',
            'shop': 'Shopping', 'market': 'Shopping', 'bazaar': 'Shopping', 'تسوق': 'Shopping',
            'outdoor': 'Outdoor Activities', 'adventure': 'Outdoor Activities', 'مغامر': 'Outdoor Activities',
            'nature': 'Nature & Parks', 'park': 'Nature & Parks', 'طبيعة': 'Nature & Parks',
            'landmark': 'Sights & Landmarks', 'pyramid': 'Sights & Landmarks', 'temple': 'Sights & Landmarks',
            'monument': 'Sights & Landmarks', 'historical': 'Sights & Landmarks', 'هرم': 'Sights & Landmarks',
            'zoo': 'Zoos & Aquariums', 'aquarium': 'Zoos & Aquariums', 'حيوان': 'Zoos & Aquariums',
            'concert': 'Concerts & Shows', 'show': 'Concerts & Shows', 'music': 'Concerts & Shows',
            'fun': 'Fun & Games', 'game': 'Fun & Games', 'العاب': 'Fun & Games',
            'water park': 'Water & Amusement Parks', 'amusement': 'Water & Amusement Parks',
            'food': 'Traveler Resources', 'restaurant': 'Traveler Resources', 'cuisine': 'Traveler Resources',
            'طعام': 'Traveler Resources', 'اكل': 'Traveler Resources'
        }
        
        for keyword, category in preference_keywords.items():
            if keyword in text_lower and category not in self.profile['user_preferences']:
                self.profile['user_preferences'].append(category)
                if 'preferences' not in updates:
                    updates['preferences'] = []
                updates['preferences'].append(category)
        
        return updates
    
    def add_preference(self, preference: str) -> bool:
        """Add a preference to the profile"""
        # Map to valid category
        category_map = {
            'museum': 'Museums', 'history': 'Museums',
            'shop': 'Shopping', 'market': 'Shopping',
            'outdoor': 'Outdoor Activities', 'adventure': 'Outdoor Activities',
            'nature': 'Nature & Parks', 'park': 'Nature & Parks',
            'landmark': 'Sights & Landmarks', 'pyramid': 'Sights & Landmarks',
            'monument': 'Sights & Landmarks', 'temple': 'Sights & Landmarks',
            'zoo': 'Zoos & Aquariums', 'aquarium': 'Zoos & Aquariums',
            'concert': 'Concerts & Shows', 'show': 'Concerts & Shows',
            'fun': 'Fun & Games', 'game': 'Fun & Games',
            'water': 'Water & Amusement Parks', 'amusement': 'Water & Amusement Parks',
            'food': 'Traveler Resources', 'restaurant': 'Traveler Resources'
        }
        
        pref_lower = preference.lower()
        for key, category in category_map.items():
            if key in pref_lower:
                if category not in self.profile['user_preferences']:
                    self.profile['user_preferences'].append(category)
                    return True
        return False
    
    def remove_preference(self, preference: str) -> bool:
        """Remove a preference from the profile"""
        pref_lower = preference.lower()
        
        for i, pref in enumerate(self.profile['user_preferences']):
            if pref_lower in pref.lower():
                self.profile['user_preferences'].pop(i)
                return True
        return False
    
    def get_missing_fields(self) -> List[str]:
        """Get list of missing profile fields"""
        missing = []
        if self.profile['user_travel_type'] is None:
            missing.append('travel_type')
        if self.profile['user_budget'] is None:
            missing.append('budget')
        if len(self.profile['user_preferences']) < 2:
            missing.append('preferences')
        return missing
    
    def is_complete(self) -> bool:
        """Check if profile has minimum required info"""
        return len(self.get_missing_fields()) == 0
    
    def get_formatted_profile(self) -> Dict:
        """Get profile in model-ready format"""
        return {
            'user_age': self.profile['user_age'] or 25,
            'user_gender': self.profile['user_gender'],
            'user_budget': self.profile['user_budget'] or 'medium',
            'user_travel_type': self.profile['user_travel_type'] or 'solo',
            'user_preferences': self.profile['user_preferences'] if self.profile['user_preferences'] else ['Museums', 'Sights & Landmarks']
        }

# ============================================================================
# MULTILINGUAL LANGUAGE DETECTOR (22+ Languages) - IMPROVED VERSION
# ============================================================================

class LanguageDetector:
    """
    Accurate language detection for chatbot responses.
    Priority: Script-based detection > Strong keyword matching > English default
    """
    
    # Non-Latin script patterns (highest priority - very accurate)
    SCRIPT_PATTERNS = {
        'ar': re.compile(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]+'),  # Arabic
        'zh': re.compile(r'[\u4E00-\u9FFF\u3400-\u4DBF]+'),  # Chinese
        'ja': re.compile(r'[\u3040-\u309F\u30A0-\u30FF]+'),  # Japanese Hiragana/Katakana
        'ko': re.compile(r'[\uAC00-\uD7AF\u1100-\u11FF]+'),  # Korean
        'ru': re.compile(r'[\u0400-\u04FF]+'),  # Russian/Cyrillic
        'el': re.compile(r'[\u0370-\u03FF]+'),  # Greek
        'he': re.compile(r'[\u0590-\u05FF]+'),  # Hebrew
        'th': re.compile(r'[\u0E00-\u0E7F]+'),  # Thai
        'hi': re.compile(r'[\u0900-\u097F]+'),  # Hindi/Devanagari
    }
    
    # Language-specific UNIQUE words (words that ONLY exist in that language)
    # These should NOT be common in English
    UNIQUE_KEYWORDS = {
        'fr': ['bonjour', 'bonsoir', 'merci', 'beaucoup', 'comment', 'allez-vous', 
               "s'il vous plaît", 'excusez-moi', 'parlez', 'voulez', 'pouvez',
               "je voudrais", "j'aimerais", 'où est', 'combien', 'pourquoi'],
        
        'de': ['guten morgen', 'guten tag', 'guten abend', 'danke', 'bitte', 
               'entschuldigung', 'sprechen', 'möchten', 'können', 'wo ist',
               'wie viel', 'warum', 'ich möchte', 'auf wiedersehen'],
        
        'es': ['buenos días', 'buenas tardes', 'buenas noches', 'gracias', 
               'por favor', 'disculpe', 'habla', 'quiero', 'puede', 'dónde',
               'cuánto', 'por qué', 'me gustaría', 'hasta luego', 'hola'],
        
        'it': ['buongiorno', 'buonasera', 'grazie', 'prego', 'scusi', 
               'parla', 'vorrei', 'può', 'dove', 'quanto', 'perché',
               'mi piacerebbe', 'arrivederci', 'ciao'],
        
        'pt': ['bom dia', 'boa tarde', 'boa noite', 'obrigado', 'obrigada',
               'por favor', 'desculpe', 'fala', 'quero', 'pode', 'onde',
               'quanto', 'por que', 'gostaria', 'tchau', 'olá'],
        
        'nl': ['goedemorgen', 'goedemiddag', 'goedenavond', 'dank u', 'alstublieft',
               'excuseer', 'spreekt', 'wilt', 'kunt', 'waar is', 'hoeveel'],
        
        'pl': ['dzień dobry', 'dobry wieczór', 'dziękuję', 'proszę', 'przepraszam',
               'mówi', 'chcę', 'może', 'gdzie', 'ile', 'dlaczego', 'cześć'],
        
        'sv': ['god morgon', 'god kväll', 'tack', 'snälla', 'ursäkta',
               'talar', 'vill', 'kan', 'var är', 'hur mycket', 'varför', 'hej'],
        
        'tr': ['günaydın', 'iyi akşamlar', 'teşekkürler', 'lütfen', 'affedersiniz',
               'konuşuyor', 'istiyorum', 'nerede', 'ne kadar', 'neden', 'merhaba'],
        
        'id': ['selamat pagi', 'selamat siang', 'selamat malam', 'terima kasih',
               'tolong', 'maaf', 'berbicara', 'mau', 'bisa', 'di mana', 'berapa'],
        
        'vi': ['xin chào', 'cảm ơn', 'xin lỗi', 'làm ơn', 'nói', 'muốn',
               'có thể', 'ở đâu', 'bao nhiêu', 'tại sao'],
    }
    
    # Language names for display
    LANGUAGE_NAMES = {
        'en': 'English',
        'ar': 'Arabic (العربية)',
        'zh': 'Chinese (中文)',
        'ja': 'Japanese (日本語)',
        'ko': 'Korean (한국어)',
        'ru': 'Russian (Русский)',
        'el': 'Greek (Ελληνικά)',
        'he': 'Hebrew (עברית)',
        'th': 'Thai (ไทย)',
        'hi': 'Hindi (हिन्दी)',
        'tr': 'Turkish (Türkçe)',
        'vi': 'Vietnamese (Tiếng Việt)',
        'fr': 'French (Français)',
        'de': 'German (Deutsch)',
        'es': 'Spanish (Español)',
        'it': 'Italian (Italiano)',
        'pt': 'Portuguese (Português)',
        'nl': 'Dutch (Nederlands)',
        'pl': 'Polish (Polski)',
        'sv': 'Swedish (Svenska)',
        'id': 'Indonesian (Bahasa Indonesia)',
    }
    
    @staticmethod
    def detect(text: str) -> str:
        """
        Detect language with high accuracy.
        Returns 'en' for English, or appropriate language code.
        
        Detection priority:
        1. Non-Latin scripts (Arabic, Chinese, etc.) - 100% accurate
        2. Strong unique keywords (bonjour, hola, etc.)
        3. Default to English
        """
        if not text or not text.strip():
            return 'en'
        
        original_text = text
        text_lower = text.lower().strip()
        
        # ============================================================
        # STEP 1: Check for non-Latin scripts (highest accuracy)
        # ============================================================
        for lang_code, pattern in LanguageDetector.SCRIPT_PATTERNS.items():
            if pattern.search(original_text):
                return lang_code
        
        # ============================================================
        # STEP 2: Check for Vietnamese diacritics
        # ============================================================
        vietnamese_chars = re.compile(r'[àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ]', re.IGNORECASE)
        if vietnamese_chars.search(text_lower):
            return 'vi'
        
        # ============================================================
        # STEP 3: Check for Turkish special characters
        # ============================================================
        turkish_chars = re.compile(r'[ğĞıİşŞçÇöÖüÜ]')
        if turkish_chars.search(original_text):
            return 'tr'
        
        # ============================================================
        # STEP 4: Check for unique language keywords
        # Only match if we find STRONG evidence of another language
        # ============================================================
        for lang_code, keywords in LanguageDetector.UNIQUE_KEYWORDS.items():
            for keyword in keywords:
                # Exact match or word boundary match
                if keyword in text_lower:
                    # Make sure it's a real match, not part of another word
                    pattern = r'\b' + re.escape(keyword) + r'\b'
                    if re.search(pattern, text_lower):
                        return lang_code
        
        # ============================================================
        # STEP 5: Default to English
        # If no other language detected, assume English
        # ============================================================
        return 'en'
    
    @staticmethod
    def get_language_name(code: str) -> str:
        """Get human-readable language name"""
        return LanguageDetector.LANGUAGE_NAMES.get(code, 'English')
    
    @staticmethod
    def get_supported_languages() -> List[str]:
        """Get list of supported language codes"""
        return list(LanguageDetector.LANGUAGE_NAMES.keys())

# ============================================================================
# ULTIMATE FAHMY CHATBOT
# ============================================================================

class UltimateFahmy:
    """The Ultimate Egyptian Travel Assistant"""
    
    def __init__(self):
        print("\n" + "=" * 70)
        print("🐫 FAHMY - Your Egyptian Travel Guide")
        print("=" * 70)
        print("\nInitializing systems...\n")
        
        # Initialize components
        self.ollama = OllamaHandler()
        self.recommender = RecommendationEngine()
        self.profile_manager = UserProfileManager()
        
        # Initialize recommender
        self.recommender.initialize()
        
        # Conversation state
        self.conversation_history = []
        self.current_recommendations = []
        self.state = 'general'  # general, collecting_profile, showing_recommendations
        self.user_language = 'en'
        
        # System prompt for Ollama (Multilingual)
        self.system_prompt = """You are Fahmy, a friendly and knowledgeable Egyptian travel guide.

YOUR PERSONALITY:
- Warm, welcoming, and enthusiastic about Egypt
- Knowledgeable about Egyptian history, culture, landmarks, and travel tips
- Helpful and patient with travelers
- Use natural conversational tone (like a friend, not a robot)
- Occasionally use expressions like "Actually...", "You know what...", "Great choice!"

YOUR EXPERTISE:
- Egyptian landmarks and monuments (pyramids, temples, museums)
- Historical information about ancient Egypt
- Travel tips (best times to visit, what to wear, safety)
- Local customs and culture
- Food and cuisine recommendations
- Budget and practical advice

MULTILINGUAL CAPABILITY:
You are fluent in many languages. ALWAYS respond in the SAME LANGUAGE the user writes in.
- If user writes in French → Respond in French
- If user writes in German → Respond in German
- If user writes in Spanish → Respond in Spanish
- If user writes in Arabic → Respond in Arabic
- If user writes in Chinese → Respond in Chinese
- If user writes in Russian → Respond in Russian
- If user writes in Italian → Respond in Italian
- If user writes in Portuguese → Respond in Portuguese
- If user writes in Japanese → Respond in Japanese
- If user writes in Korean → Respond in Korean
- And so on for any language...

RULES:
1. Keep responses concise but informative (2-4 sentences for simple questions)
2. Be enthusiastic without being overwhelming
3. If asked about recommendations, mention you can create a personalized list
4. Never make up historical facts - if unsure, say so
5. Always be respectful of Egyptian culture
6. ALWAYS match the user's language in your response

RESPONSE STYLE:
- Start with a brief, engaging response
- Add useful tips when relevant
- End with a follow-up question or offer to help more (occasionally, not always)"""

        print("\n" + "=" * 70)
        print("✅ Fahmy is ready!")
        print("=" * 70)
        self._print_greeting()
    
    def _print_greeting(self):
        """Print initial greeting"""
        greeting = """
Hello! 👋 I'm Fahmy, your personal Egyptian travel guide!

I can help you with:
🏛️  Information about landmarks & monuments
📜  Egyptian history and culture  
🗺️  Personalized travel recommendations
💡  Travel tips and practical advice

🌍 I speak multiple languages! Just chat in your preferred language:
   English, العربية, Français, Deutsch, Español, Italiano, Português,
   Русский, 中文, 日本語, 한국어, Nederlands, Polski, Türkçe, and more!

Just chat naturally - ask me anything about Egypt!
Type 'exit' to end our conversation.
"""
        print(greeting)
        print("─" * 70 + "\n")
    
    def chat(self, user_input: str) -> str:
        """Main chat function"""
        user_input = user_input.strip()
        
        if not user_input:
            return ""
        
        # Detect language
        self.user_language = LanguageDetector.detect(user_input)
        
        # Debug: Show detected language
        if CONFIG["debug_mode"]:
            print(f"[DEBUG] Detected language: {self.user_language} for input: '{user_input}'")
        
        # Check for exit
        if user_input.lower() in ['exit', 'quit', 'bye', 'goodbye', 'خروج', 'مع السلامة']:
            return self._get_farewell()
        
        # Update profile from any text
        self.profile_manager.update_from_text(user_input)
        
        # Parse intent
        intent = self._parse_intent(user_input)
        
        # Add to conversation history
        self.conversation_history.append({"role": "user", "content": user_input})
        
        # Handle based on intent
        if intent == 'recommendation':
            response = self._handle_recommendation_request(user_input)
        elif intent == 'add_preference':
            response = self._handle_add_preference(user_input)
        elif intent == 'remove_preference':
            response = self._handle_remove_preference(user_input)
        elif intent == 'change_budget':
            response = self._handle_change_budget(user_input)
        elif intent == 'change_travel_type':
            response = self._handle_change_travel_type(user_input)
        elif intent == 'more_recommendations':
            response = self._handle_more_recommendations()
        elif intent == 'show_profile':
            response = self._handle_show_profile()
        elif intent == 'reset':
            response = self._handle_reset()
        elif self.state == 'collecting_profile':
            response = self._continue_profile_collection(user_input)
        else:
            response = self._handle_general_conversation(user_input)
        
        # Add to history
        self.conversation_history.append({"role": "assistant", "content": response})
        
        # Trim history
        if len(self.conversation_history) > CONFIG["conversation_history_limit"] * 2:
            self.conversation_history = self.conversation_history[-CONFIG["conversation_history_limit"] * 2:]
        
        return response
    
    def _parse_intent(self, text: str) -> str:
        """Parse user intent from text"""
        text_lower = text.lower()
        
        # Recommendation request
        rec_keywords = ['recommend', 'suggest', 'places to visit', 'what should i see',
                       'itinerary', 'plan my trip', 'where to go', 'best places',
                       'توصيات', 'اقترح', 'اماكن', 'رحلة']
        if any(kw in text_lower for kw in rec_keywords):
            return 'recommendation'
        
        # Add preference
        add_keywords = ['add', 'include', 'also want', 'plus', 'اضف', 'اريد ايضا']
        if any(kw in text_lower for kw in add_keywords):
            return 'add_preference'
        
        # Remove preference
        remove_keywords = ['remove', 'delete', 'no more', 'exclude', 'without', 'احذف', 'بدون']
        if any(kw in text_lower for kw in remove_keywords):
            return 'remove_preference'
        
        # Change budget
        if ('change' in text_lower or 'switch' in text_lower or 'غير' in text_lower) and \
           ('budget' in text_lower or 'ميزانية' in text_lower):
            return 'change_budget'
        
        # Change travel type
        if ('change' in text_lower or 'switch' in text_lower) and \
           any(word in text_lower for word in ['travel', 'solo', 'couple', 'family', 'luxury']):
            return 'change_travel_type'
        
        # More recommendations
        more_keywords = ['more', 'other', 'different', 'alternatives', 'another', 'المزيد', 'غيرها']
        if any(kw in text_lower for kw in more_keywords) and self.current_recommendations:
            return 'more_recommendations'
        
        # Show profile
        if any(kw in text_lower for kw in ['my profile', 'my preferences', 'what do you know about me']):
            return 'show_profile'
        
        # Reset
        if any(kw in text_lower for kw in ['reset', 'start over', 'clear', 'من جديد']):
            return 'reset'
        
        return 'general'
    
    def _handle_recommendation_request(self, user_input: str) -> str:
        """Handle recommendation requests"""
        
        # Check if profile is complete
        missing = self.profile_manager.get_missing_fields()
        
        if missing:
            self.state = 'collecting_profile'
            return self._ask_for_missing_info(missing)
        else:
            return self._generate_recommendations()
    
    def _ask_for_missing_info(self, missing: List[str]) -> str:
        """Ask for missing profile information - Multilingual"""
        
        lang = self.user_language
        
        # Multilingual questions
        questions = {
            'en': {
                'travel_type': "How are you traveling? (solo / couple / family / luxury)",
                'budget': "What's your budget level? (low / medium / high)",
                'preferences': "What interests you most? (e.g., history, museums, shopping, adventure, food)"
            },
            'ar': {
                'travel_type': "كيف ستسافر؟ (منفرد / زوجين / عائلة / فاخر)",
                'budget': "ما هي ميزانيتك؟ (منخفضة / متوسطة / عالية)",
                'preferences': "ما الذي يثير اهتمامك؟ (مثل: التاريخ، المتاحف، التسوق، المغامرة، الطعام)"
            },
            'fr': {
                'travel_type': "Comment voyagez-vous? (seul / couple / famille / luxe)",
                'budget': "Quel est votre budget? (bas / moyen / élevé)",
                'preferences': "Qu'est-ce qui vous intéresse? (ex: histoire, musées, shopping, aventure, gastronomie)"
            },
            'de': {
                'travel_type': "Wie reisen Sie? (allein / Paar / Familie / Luxus)",
                'budget': "Wie hoch ist Ihr Budget? (niedrig / mittel / hoch)",
                'preferences': "Was interessiert Sie? (z.B. Geschichte, Museen, Shopping, Abenteuer, Essen)"
            },
            'es': {
                'travel_type': "¿Cómo viajas? (solo / pareja / familia / lujo)",
                'budget': "¿Cuál es tu presupuesto? (bajo / medio / alto)",
                'preferences': "¿Qué te interesa? (ej: historia, museos, compras, aventura, comida)"
            },
            'it': {
                'travel_type': "Come viaggi? (solo / coppia / famiglia / lusso)",
                'budget': "Qual è il tuo budget? (basso / medio / alto)",
                'preferences': "Cosa ti interessa? (es: storia, musei, shopping, avventura, cibo)"
            },
            'ru': {
                'travel_type': "Как вы путешествуете? (один / пара / семья / люкс)",
                'budget': "Какой у вас бюджет? (низкий / средний / высокий)",
                'preferences': "Что вас интересует? (напр: история, музеи, шоппинг, приключения, еда)"
            },
            'zh': {
                'travel_type': "您如何旅行？(独自 / 情侣 / 家庭 / 豪华)",
                'budget': "您的预算是多少？(低 / 中 / 高)",
                'preferences': "您对什么感兴趣？(如：历史、博物馆、购物、冒险、美食)"
            },
            'ja': {
                'travel_type': "どのように旅行しますか？(一人 / カップル / 家族 / 豪華)",
                'budget': "ご予算は？(低 / 中 / 高)",
                'preferences': "何に興味がありますか？(例：歴史、博物館、ショッピング、アドベンチャー、グルメ)"
            },
            'ko': {
                'travel_type': "어떻게 여행하시나요? (혼자 / 커플 / 가족 / 럭셔리)",
                'budget': "예산은 어떻게 되나요? (저 / 중 / 고)",
                'preferences': "무엇에 관심이 있으신가요? (예: 역사, 박물관, 쇼핑, 모험, 음식)"
            },
        }
        
        # Intro messages
        intros = {
            'en': "Great! To give you personalized recommendations, I need to know:\n\n",
            'ar': "رائع! لأقدم لك توصيات مخصصة، أحتاج أن أعرف:\n\n",
            'fr': "Super! Pour vous donner des recommandations personnalisées, j'ai besoin de savoir:\n\n",
            'de': "Super! Um Ihnen personalisierte Empfehlungen zu geben, muss ich wissen:\n\n",
            'es': "¡Genial! Para darte recomendaciones personalizadas, necesito saber:\n\n",
            'it': "Ottimo! Per darti raccomandazioni personalizzate, devo sapere:\n\n",
            'ru': "Отлично! Чтобы дать вам персональные рекомендации, мне нужно знать:\n\n",
            'zh': "太好了！为了给您个性化推荐，我需要知道：\n\n",
            'ja': "素晴らしい！パーソナライズされたおすすめを提供するために、以下を教えてください：\n\n",
            'ko': "좋아요! 맞춤 추천을 드리기 위해 알아야 할 것이 있습니다:\n\n",
        }
        
        # Get language-specific content or default to English
        lang_questions = questions.get(lang, questions['en'])
        response = intros.get(lang, intros['en'])
        
        # Ask for first missing item
        if missing:
            first = missing[0]
            response += f"👉 {lang_questions.get(first, '')}"
        
        return response
    
    def _continue_profile_collection(self, user_input: str) -> str:
        """Continue collecting profile information"""
        
        missing = self.profile_manager.get_missing_fields()
        
        if not missing:
            self.state = 'general'
            return self._generate_recommendations()
        else:
            return self._ask_for_missing_info(missing)
    
    def _generate_recommendations(self) -> str:
        """Generate and format recommendations - Multilingual"""
        
        self.state = 'showing_recommendations'
        profile = self.profile_manager.get_formatted_profile()
        lang = self.user_language
        
        # Get recommendations
        self.current_recommendations = self.recommender.get_recommendations(
            profile, 
            limit=CONFIG["max_recommendations"]
        )
        
        if not self.current_recommendations:
            no_results = {
                'en': "Sorry, I couldn't find matching recommendations. Could you adjust your preferences?",
                'ar': "عذراً، لم أجد توصيات مناسبة. هل يمكنك تعديل تفضيلاتك؟",
                'fr': "Désolé, je n'ai pas trouvé de recommandations correspondantes. Pouvez-vous ajuster vos préférences?",
                'de': "Entschuldigung, ich konnte keine passenden Empfehlungen finden. Können Sie Ihre Präferenzen anpassen?",
                'es': "Lo siento, no pude encontrar recomendaciones. ¿Podrías ajustar tus preferencias?",
                'it': "Scusa, non ho trovato raccomandazioni corrispondenti. Puoi modificare le tue preferenze?",
                'ru': "Извините, я не нашел подходящих рекомендаций. Можете ли вы изменить свои предпочтения?",
                'zh': "抱歉，我找不到匹配的推荐。您能调整一下偏好吗？",
                'ja': "申し訳ありませんが、一致するおすすめが見つかりませんでした。好みを調整していただけますか？",
                'ko': "죄송합니다. 일치하는 추천을 찾을 수 없습니다. 선호도를 조정해 주시겠어요?",
            }
            return no_results.get(lang, no_results['en'])
        
        # Headers
        headers = {
            'en': "🎯 **Here are your personalized recommendations:**\n\n",
            'ar': "🎯 **إليك توصياتي المخصصة لك:**\n\n",
            'fr': "🎯 **Voici vos recommandations personnalisées:**\n\n",
            'de': "🎯 **Hier sind Ihre personalisierten Empfehlungen:**\n\n",
            'es': "🎯 **Aquí están tus recomendaciones personalizadas:**\n\n",
            'it': "🎯 **Ecco le tue raccomandazioni personalizzate:**\n\n",
            'ru': "🎯 **Вот ваши персональные рекомендации:**\n\n",
            'zh': "🎯 **以下是您的个性化推荐：**\n\n",
            'ja': "🎯 **パーソナライズされたおすすめ：**\n\n",
            'ko': "🎯 **맞춤 추천 목록:**\n\n",
        }
        
        response = headers.get(lang, headers['en'])
        
        # Category emojis
        emojis = {
            'Museums': '🏛️', 'Shopping': '🛍️', 'Outdoor Activities': '🚵',
            'Nature & Parks': '🌳', 'Sights & Landmarks': '🗽',
            'Zoos & Aquariums': '🐠', 'Concerts & Shows': '🎭',
            'Fun & Games': '🎪', 'Water & Amusement Parks': '🎢',
            'Traveler Resources': '🍽️'
        }
        
        for i, rec in enumerate(self.current_recommendations, 1):
            emoji = emojis.get(rec['category'], '📍')
            score = rec.get('dl_score', 0.8) * 100
            
            response += f"{i}. {emoji} **{rec['name']}**\n"
            response += f"   📍 {rec['category']} | ⭐ {rec.get('rating', 4.5):.1f}/5 | 💰 {rec.get('budget', 'medium').capitalize()}\n"
            
            if 'description' in rec:
                response += f"   📝 {rec['description']}\n"
            
            response += f"   🎯 Match: {score:.0f}%\n\n"
        
        # Tips in different languages
        tips = {
            'en': """
💡 **You can:**
• Say 'add food' to include a new interest
• Say 'remove museums' to exclude a category
• Say 'change budget to high' for luxury options
• Say 'more' for different recommendations
""",
            'ar': """
💡 **يمكنك:**
• قل 'أضف طعام' لإضافة اهتمام جديد
• قل 'احذف متاحف' لإزالة فئة
• قل 'غير الميزانية إلى عالية' للخيارات الفاخرة
• قل 'المزيد' لتوصيات مختلفة
""",
            'fr': """
💡 **Vous pouvez:**
• Dire 'ajouter gastronomie' pour inclure un nouvel intérêt
• Dire 'supprimer musées' pour exclure une catégorie
• Dire 'changer budget en élevé' pour les options luxe
• Dire 'plus' pour d'autres recommandations
""",
            'de': """
💡 **Sie können:**
• Sagen Sie 'Essen hinzufügen' für ein neues Interesse
• Sagen Sie 'Museen entfernen' um eine Kategorie auszuschließen
• Sagen Sie 'Budget auf hoch ändern' für Luxusoptionen
• Sagen Sie 'mehr' für andere Empfehlungen
""",
            'es': """
💡 **Puedes:**
• Decir 'añadir comida' para incluir un nuevo interés
• Decir 'quitar museos' para excluir una categoría
• Decir 'cambiar presupuesto a alto' para opciones de lujo
• Decir 'más' para diferentes recomendaciones
""",
            'it': """
💡 **Puoi:**
• Dire 'aggiungi cibo' per includere un nuovo interesse
• Dire 'rimuovi musei' per escludere una categoria
• Dire 'cambia budget in alto' per opzioni di lusso
• Dire 'altro' per diverse raccomandazioni
""",
            'ru': """
💡 **Вы можете:**
• Сказать 'добавить еду' для нового интереса
• Сказать 'удалить музеи' для исключения категории
• Сказать 'изменить бюджет на высокий' для люксовых вариантов
• Сказать 'ещё' для других рекомендаций
""",
            'zh': """
💡 **您可以:**
• 说"添加美食"以包含新兴趣
• 说"删除博物馆"以排除类别
• 说"将预算改为高"以获取豪华选项
• 说"更多"以获取不同推荐
""",
            'ja': """
💡 **できること:**
• 「食べ物を追加」で新しい興味を追加
• 「博物館を削除」でカテゴリを除外
• 「予算を高に変更」で豪華オプション
• 「もっと」で別のおすすめ
""",
            'ko': """
💡 **할 수 있는 것:**
• '음식 추가'로 새로운 관심사 추가
• '박물관 제거'로 카테고리 제외
• '예산을 높음으로 변경'으로 럭셔리 옵션
• '더 보기'로 다른 추천
""",
        }
        
        response += tips.get(lang, tips['en'])
        
        return response
    
    def _handle_add_preference(self, user_input: str) -> str:
        """Handle adding a preference - Multilingual"""
        
        lang = self.user_language
        text_lower = user_input.lower()
        added = []
        
        keywords = ['museum', 'shop', 'outdoor', 'adventure', 'nature', 'park',
                   'landmark', 'pyramid', 'temple', 'monument', 'zoo', 'aquarium',
                   'concert', 'show', 'fun', 'game', 'water', 'amusement', 'food', 'restaurant']
        
        for keyword in keywords:
            if keyword in text_lower:
                if self.profile_manager.add_preference(keyword):
                    added.append(keyword)
        
        if added:
            added_msgs = {
                'en': f"✅ Added: {', '.join(added)}\n\n",
                'ar': f"✅ تمت الإضافة: {', '.join(added)}\n\n",
                'fr': f"✅ Ajouté: {', '.join(added)}\n\n",
                'de': f"✅ Hinzugefügt: {', '.join(added)}\n\n",
                'es': f"✅ Añadido: {', '.join(added)}\n\n",
                'it': f"✅ Aggiunto: {', '.join(added)}\n\n",
                'ru': f"✅ Добавлено: {', '.join(added)}\n\n",
                'zh': f"✅ 已添加: {', '.join(added)}\n\n",
                'ja': f"✅ 追加: {', '.join(added)}\n\n",
                'ko': f"✅ 추가됨: {', '.join(added)}\n\n",
            }
            response = added_msgs.get(lang, added_msgs['en'])
            response += self._generate_recommendations()
        else:
            ask_msgs = {
                'en': "What would you like to add? (e.g., food, museums, adventure, shopping)",
                'ar': "ماذا تريد أن تضيف؟ (مثل: طعام، متاحف، مغامرة، تسوق)",
                'fr': "Que voulez-vous ajouter? (ex: gastronomie, musées, aventure, shopping)",
                'de': "Was möchten Sie hinzufügen? (z.B. Essen, Museen, Abenteuer, Shopping)",
                'es': "¿Qué te gustaría añadir? (ej: comida, museos, aventura, compras)",
                'it': "Cosa vorresti aggiungere? (es: cibo, musei, avventura, shopping)",
                'ru': "Что вы хотите добавить? (напр: еда, музеи, приключения, шоппинг)",
                'zh': "您想添加什么？(如：美食、博物馆、冒险、购物)",
                'ja': "何を追加しますか？(例：食べ物、博物館、冒険、ショッピング)",
                'ko': "무엇을 추가하시겠어요? (예: 음식, 박물관, 모험, 쇼핑)",
            }
            response = ask_msgs.get(lang, ask_msgs['en'])
        
        return response
    
    def _handle_remove_preference(self, user_input: str) -> str:
        """Handle removing a preference - Multilingual"""
        
        lang = self.user_language
        text_lower = user_input.lower()
        removed = []
        
        for pref in list(self.profile_manager.profile['user_preferences']):
            if pref.lower() in text_lower or any(word in text_lower for word in pref.lower().split()):
                if self.profile_manager.remove_preference(pref):
                    removed.append(pref)
        
        if removed:
            removed_msgs = {
                'en': f"✅ Removed: {', '.join(removed)}\n\n",
                'ar': f"✅ تمت الإزالة: {', '.join(removed)}\n\n",
                'fr': f"✅ Supprimé: {', '.join(removed)}\n\n",
                'de': f"✅ Entfernt: {', '.join(removed)}\n\n",
                'es': f"✅ Eliminado: {', '.join(removed)}\n\n",
                'it': f"✅ Rimosso: {', '.join(removed)}\n\n",
                'ru': f"✅ Удалено: {', '.join(removed)}\n\n",
                'zh': f"✅ 已删除: {', '.join(removed)}\n\n",
                'ja': f"✅ 削除: {', '.join(removed)}\n\n",
                'ko': f"✅ 제거됨: {', '.join(removed)}\n\n",
            }
            response = removed_msgs.get(lang, removed_msgs['en'])
            
            if self.profile_manager.profile['user_preferences']:
                response += self._generate_recommendations()
            else:
                new_interest_msgs = {
                    'en': "What are your new interests?",
                    'ar': "ما هي اهتماماتك الجديدة؟",
                    'fr': "Quels sont vos nouveaux intérêts?",
                    'de': "Was sind Ihre neuen Interessen?",
                    'es': "¿Cuáles son tus nuevos intereses?",
                    'it': "Quali sono i tuoi nuovi interessi?",
                    'ru': "Какие у вас новые интересы?",
                    'zh': "您的新兴趣是什么？",
                    'ja': "新しい興味は何ですか？",
                    'ko': "새로운 관심사는 무엇인가요?",
                }
                response += new_interest_msgs.get(lang, new_interest_msgs['en'])
        else:
            ask_remove_msgs = {
                'en': "What would you like to remove?",
                'ar': "ماذا تريد أن تزيل؟",
                'fr': "Que voulez-vous supprimer?",
                'de': "Was möchten Sie entfernen?",
                'es': "¿Qué te gustaría eliminar?",
                'it': "Cosa vorresti rimuovere?",
                'ru': "Что вы хотите удалить?",
                'zh': "您想删除什么？",
                'ja': "何を削除しますか？",
                'ko': "무엇을 제거하시겠어요?",
            }
            response = ask_remove_msgs.get(lang, ask_remove_msgs['en'])
        
        return response
    
    def _handle_change_budget(self, user_input: str) -> str:
        """Handle budget change - Multilingual"""
        
        lang = self.user_language
        text_lower = user_input.lower()
        
        # Budget labels in multiple languages
        budget_labels = {
            'low': {'en': 'Low', 'ar': 'منخفضة', 'fr': 'Bas', 'de': 'Niedrig', 'es': 'Bajo', 
                   'it': 'Basso', 'ru': 'Низкий', 'zh': '低', 'ja': '低', 'ko': '낮음'},
            'medium': {'en': 'Medium', 'ar': 'متوسطة', 'fr': 'Moyen', 'de': 'Mittel', 'es': 'Medio',
                      'it': 'Medio', 'ru': 'Средний', 'zh': '中', 'ja': '中', 'ko': '중간'},
            'high': {'en': 'High', 'ar': 'عالية', 'fr': 'Élevé', 'de': 'Hoch', 'es': 'Alto',
                    'it': 'Alto', 'ru': 'Высокий', 'zh': '高', 'ja': '高', 'ko': '높음'}
        }
        
        if any(word in text_lower for word in ['low', 'cheap', 'منخفض', 'رخيص', 'bas', 'niedrig', 'bajo', 'basso', 'низкий', '低']):
            self.profile_manager.profile['user_budget'] = 'low'
            budget_key = 'low'
        elif any(word in text_lower for word in ['high', 'luxury', 'expensive', 'عالي', 'فاخر', 'élevé', 'hoch', 'alto', 'высокий', '高']):
            self.profile_manager.profile['user_budget'] = 'high'
            budget_key = 'high'
        else:
            self.profile_manager.profile['user_budget'] = 'medium'
            budget_key = 'medium'
        
        budget_label = budget_labels[budget_key].get(lang, budget_labels[budget_key]['en'])
        
        changed_msgs = {
            'en': f"✅ Budget changed to: {budget_label}\n\n",
            'ar': f"✅ تم تغيير الميزانية إلى: {budget_label}\n\n",
            'fr': f"✅ Budget changé en: {budget_label}\n\n",
            'de': f"✅ Budget geändert zu: {budget_label}\n\n",
            'es': f"✅ Presupuesto cambiado a: {budget_label}\n\n",
            'it': f"✅ Budget cambiato in: {budget_label}\n\n",
            'ru': f"✅ Бюджет изменен на: {budget_label}\n\n",
            'zh': f"✅ 预算已更改为: {budget_label}\n\n",
            'ja': f"✅ 予算を変更しました: {budget_label}\n\n",
            'ko': f"✅ 예산이 변경됨: {budget_label}\n\n",
        }
        
        response = changed_msgs.get(lang, changed_msgs['en'])
        return response + self._generate_recommendations()
    
    def _handle_change_travel_type(self, user_input: str) -> str:
        """Handle travel type change - Multilingual"""
        
        lang = self.user_language
        text_lower = user_input.lower()
        
        # Travel type labels in multiple languages
        type_labels = {
            'solo': {'en': 'Solo', 'ar': 'منفرد', 'fr': 'Solo', 'de': 'Allein', 'es': 'Solo',
                    'it': 'Solo', 'ru': 'Один', 'zh': '独自', 'ja': '一人', 'ko': '혼자'},
            'couple': {'en': 'Couple', 'ar': 'زوجين', 'fr': 'Couple', 'de': 'Paar', 'es': 'Pareja',
                      'it': 'Coppia', 'ru': 'Пара', 'zh': '情侣', 'ja': 'カップル', 'ko': '커플'},
            'family': {'en': 'Family', 'ar': 'عائلة', 'fr': 'Famille', 'de': 'Familie', 'es': 'Familia',
                      'it': 'Famiglia', 'ru': 'Семья', 'zh': '家庭', 'ja': '家族', 'ko': '가족'},
            'luxury': {'en': 'Luxury', 'ar': 'فاخر', 'fr': 'Luxe', 'de': 'Luxus', 'es': 'Lujo',
                      'it': 'Lusso', 'ru': 'Люкс', 'zh': '豪华', 'ja': '豪華', 'ko': '럭셔리'}
        }
        
        if any(word in text_lower for word in ['solo', 'alone', 'منفرد', 'seul', 'allein', 'один', '独自', '一人']):
            self.profile_manager.profile['user_travel_type'] = 'solo'
            type_key = 'solo'
        elif any(word in text_lower for word in ['couple', 'partner', 'زوجين', 'paar', 'pareja', 'coppia', 'пара', '情侣', 'カップル']):
            self.profile_manager.profile['user_travel_type'] = 'couple'
            type_key = 'couple'
        elif any(word in text_lower for word in ['family', 'kids', 'عائلة', 'famille', 'familia', 'famiglia', 'семья', '家庭', '家族']):
            self.profile_manager.profile['user_travel_type'] = 'family'
            type_key = 'family'
        else:
            self.profile_manager.profile['user_travel_type'] = 'luxury'
            type_key = 'luxury'
        
        type_label = type_labels[type_key].get(lang, type_labels[type_key]['en'])
        
        changed_msgs = {
            'en': f"✅ Travel type changed to: {type_label}\n\n",
            'ar': f"✅ تم تغيير نوع السفر إلى: {type_label}\n\n",
            'fr': f"✅ Type de voyage changé en: {type_label}\n\n",
            'de': f"✅ Reisetyp geändert zu: {type_label}\n\n",
            'es': f"✅ Tipo de viaje cambiado a: {type_label}\n\n",
            'it': f"✅ Tipo di viaggio cambiato in: {type_label}\n\n",
            'ru': f"✅ Тип путешествия изменен на: {type_label}\n\n",
            'zh': f"✅ 旅行类型已更改为: {type_label}\n\n",
            'ja': f"✅ 旅行タイプを変更しました: {type_label}\n\n",
            'ko': f"✅ 여행 유형이 변경됨: {type_label}\n\n",
        }
        
        response = changed_msgs.get(lang, changed_msgs['en'])
        return response + self._generate_recommendations()
    
    def _handle_more_recommendations(self) -> str:
        """Handle request for more recommendations"""
        
        if self.user_language == 'ar':
            response = "🔄 **إليك خيارات أخرى:**\n\n"
        else:
            response = "🔄 **Here are more options:**\n\n"
        
        return response + self._generate_recommendations()
    
    def _handle_show_profile(self) -> str:
        """Show current user profile"""
        
        profile = self.profile_manager.profile
        
        if self.user_language == 'ar':
            response = "📋 **ملفك الشخصي:**\n\n"
            response += f"• العمر: {profile['user_age'] or 'غير محدد'}\n"
            response += f"• الميزانية: {profile['user_budget'] or 'غير محددة'}\n"
            response += f"• نوع السفر: {profile['user_travel_type'] or 'غير محدد'}\n"
            response += f"• الاهتمامات: {', '.join(profile['user_preferences']) or 'غير محددة'}\n"
        else:
            response = "📋 **Your Profile:**\n\n"
            response += f"• Age: {profile['user_age'] or 'Not set'}\n"
            response += f"• Budget: {profile['user_budget'] or 'Not set'}\n"
            response += f"• Travel Type: {profile['user_travel_type'] or 'Not set'}\n"
            response += f"• Interests: {', '.join(profile['user_preferences']) or 'Not set'}\n"
        
        return response
    
    def _handle_reset(self) -> str:
        """Reset profile and start fresh"""
        
        self.profile_manager.reset()
        self.current_recommendations = []
        self.state = 'general'
        
        if self.user_language == 'ar':
            return "✅ تم إعادة تعيين ملفك الشخصي. كيف يمكنني مساعدتك؟"
        return "✅ Your profile has been reset. How can I help you?"
    
    def _handle_general_conversation(self, user_input: str) -> str:
        """Handle general conversation using Ollama"""
        
        # Try Ollama first
        if self.ollama.is_available:
            messages = [{"role": "system", "content": self.system_prompt}]
            
            # Add recent history
            for msg in self.conversation_history[-6:]:
                messages.append(msg)
            
            # Pass detected language to Ollama
            response = self.ollama.chat(messages, response_language=self.user_language)
            if response:
                return response
        
        # Fallback to rule-based responses
        return self._get_fallback_response(user_input)
    
    def _get_fallback_response(self, user_input: str) -> str:
        """Rule-based fallback responses - Multilingual"""
        
        text_lower = user_input.lower()
        lang = self.user_language
        
        # Multilingual greeting responses
        greetings = {
            'en': "Hello! 👋 How can I help you with your Egyptian adventure today?",
            'ar': "مرحباً! 👋 كيف يمكنني مساعدتك في رحلتك إلى مصر؟",
            'fr': "Bonjour! 👋 Comment puis-je vous aider pour votre voyage en Égypte?",
            'de': "Hallo! 👋 Wie kann ich Ihnen bei Ihrer Ägyptenreise helfen?",
            'es': "¡Hola! 👋 ¿Cómo puedo ayudarte con tu viaje a Egipto?",
            'it': "Ciao! 👋 Come posso aiutarti con il tuo viaggio in Egitto?",
            'pt': "Olá! 👋 Como posso ajudá-lo com sua viagem ao Egito?",
            'ru': "Привет! 👋 Как я могу помочь вам с поездкой в Египет?",
            'zh': "你好！👋 我能如何帮助您的埃及之旅？",
            'ja': "こんにちは！👋 エジプト旅行のお手伝いをしましょうか？",
            'ko': "안녕하세요! 👋 이집트 여행을 어떻게 도와드릴까요?",
            'nl': "Hallo! 👋 Hoe kan ik u helpen met uw reis naar Egypte?",
            'pl': "Cześć! 👋 Jak mogę pomóc w Twojej podróży do Egiptu?",
            'tr': "Merhaba! 👋 Mısır seyahatinizde size nasıl yardımcı olabilirim?",
            'sv': "Hej! 👋 Hur kan jag hjälpa dig med din Egyptenresa?",
            'hi': "नमस्ते! 👋 मैं आपकी मिस्र यात्रा में कैसे मदद कर सकता हूं?",
            'th': "สวัสดี! 👋 ฉันจะช่วยอะไรคุณเกี่ยวกับการเดินทางไปอียิปต์ได้บ้าง?",
            'vi': "Xin chào! 👋 Tôi có thể giúp gì cho chuyến du lịch Ai Cập của bạn?",
            'id': "Halo! 👋 Bagaimana saya bisa membantu perjalanan Anda ke Mesir?",
            'el': "Γεια σας! 👋 Πώς μπορώ να σας βοηθήσω με το ταξίδι σας στην Αίγυπτο;",
            'he': "שלום! 👋 איך אוכל לעזור לך במסע שלך למצרים?",
        }
        
        # Check for greetings in multiple languages
        greeting_words = ['hello', 'hi', 'hey', 'مرحبا', 'اهلا', 'السلام', 'bonjour', 'salut',
                         'hallo', 'guten tag', 'hola', 'ciao', 'olá', 'привет', '你好', 
                         'こんにちは', '안녕', 'hej', 'cześć', 'merhaba', 'xin chào', 
                         'halo', 'γεια', 'שלום', 'नमस्ते', 'สวัสดี']
        
        if any(word in text_lower for word in greeting_words):
            return greetings.get(lang, greetings['en'])
        
        # Pyramids info - Multilingual
        pyramid_keywords = ['pyramid', 'giza', 'هرم', 'اهرامات', 'pyramide', 'pirámide', 
                          'piramide', 'пирамид', '金字塔', 'ピラミッド', '피라미드']
        
        if any(word in text_lower for word in pyramid_keywords):
            pyramid_responses = {
                'en': """🏛️ **Pyramids of Giza**

The last remaining wonder of the ancient world! Built around 4,500 years ago.

📍 Location: Giza Plateau, Cairo
⏰ Best time: Early morning to avoid crowds and heat
💡 Tip: Don't miss the Sound & Light show at night!

Would you like personalized recommendations for your trip?""",
                'ar': """🏛️ **أهرامات الجيزة**

آخر عجائب الدنيا السبع القديمة الباقية! بُنيت منذ حوالي 4,500 سنة.

📍 الموقع: هضبة الجيزة، القاهرة
⏰ أفضل وقت للزيارة: الصباح الباكر
💡 نصيحة: لا تفوت عرض الصوت والضوء ليلاً!

هل تريد توصيات مخصصة لرحلتك؟""",
                'fr': """🏛️ **Pyramides de Gizeh**

La dernière merveille du monde antique encore debout! Construites il y a environ 4 500 ans.

📍 Lieu: Plateau de Gizeh, Le Caire
⏰ Meilleur moment: Tôt le matin pour éviter la foule
💡 Conseil: Ne manquez pas le spectacle Son et Lumière!

Voulez-vous des recommandations personnalisées?""",
                'de': """🏛️ **Pyramiden von Gizeh**

Das letzte verbliebene Weltwunder der Antike! Vor etwa 4.500 Jahren erbaut.

📍 Lage: Gizeh-Plateau, Kairo
⏰ Beste Zeit: Früher Morgen, um Menschenmassen zu vermeiden
💡 Tipp: Verpassen Sie nicht die Sound & Light Show!

Möchten Sie personalisierte Empfehlungen?""",
                'es': """🏛️ **Pirámides de Giza**

¡La última maravilla del mundo antiguo que queda! Construidas hace unos 4.500 años.

📍 Ubicación: Meseta de Giza, El Cairo
⏰ Mejor momento: Temprano por la mañana
💡 Consejo: ¡No te pierdas el espectáculo de Luz y Sonido!

¿Te gustaría recibir recomendaciones personalizadas?""",
                'it': """🏛️ **Piramidi di Giza**

L'ultima meraviglia del mondo antico rimasta! Costruite circa 4.500 anni fa.

📍 Posizione: Altopiano di Giza, Il Cairo
⏰ Momento migliore: Prima mattina per evitare la folla
💡 Consiglio: Non perdere lo spettacolo Suoni e Luci!

Vorresti raccomandazioni personalizzate?""",
                'ru': """🏛️ **Пирамиды Гизы**

Последнее из сохранившихся чудес древнего мира! Построены около 4500 лет назад.

📍 Расположение: Плато Гиза, Каир
⏰ Лучшее время: Раннее утро, чтобы избежать толпы
💡 Совет: Не пропустите световое шоу ночью!

Хотите персональные рекомендации?""",
                'zh': """🏛️ **吉萨金字塔**

古代世界七大奇迹中唯一幸存的！建于约4500年前。

📍 位置：开罗吉萨高原
⏰ 最佳时间：清晨，避开人群
💡 小贴士：不要错过夜间的声光表演！

您想要个性化的旅行推荐吗？""",
                'ja': """🏛️ **ギザのピラミッド**

古代世界の七不思議で唯一現存するもの！約4,500年前に建設されました。

📍 場所：カイロ、ギザ高原
⏰ ベストタイム：早朝、混雑を避けるため
💡 ヒント：夜の音と光のショーをお見逃しなく！

パーソナライズされたおすすめが欲しいですか？""",
                'ko': """🏛️ **기자의 피라미드**

고대 세계 7대 불가사의 중 유일하게 남아있는 것! 약 4,500년 전에 건설되었습니다.

📍 위치: 카이로, 기자 고원
⏰ 최적의 시간: 이른 아침, 인파를 피하기 위해
💡 팁: 밤의 사운드 앤 라이트 쇼를 놓치지 마세요!

맞춤 추천을 원하시나요?""",
            }
            return pyramid_responses.get(lang, pyramid_responses['en'])
        
        # Default response - Multilingual
        default_responses = {
            'en': """I can help you with:
🏛️ Information about landmarks & monuments
📜 Ancient Egyptian history
🗺️ Personalized travel recommendations
💡 Practical travel tips

What would you like to know?""",
            'ar': """أنا هنا لمساعدتك في:
🏛️ معلومات عن المعالم والمتاحف
📜 التاريخ المصري القديم
🗺️ توصيات سفر مخصصة
💡 نصائح عملية للسفر

كيف يمكنني مساعدتك؟""",
            'fr': """Je peux vous aider avec:
🏛️ Informations sur les monuments
📜 Histoire de l'Égypte ancienne
🗺️ Recommandations personnalisées
💡 Conseils pratiques de voyage

Que souhaitez-vous savoir?""",
            'de': """Ich kann Ihnen helfen mit:
🏛️ Informationen über Sehenswürdigkeiten
📜 Altägyptische Geschichte
🗺️ Personalisierte Reiseempfehlungen
💡 Praktische Reisetipps

Was möchten Sie wissen?""",
            'es': """Puedo ayudarte con:
🏛️ Información sobre monumentos
📜 Historia del antiguo Egipto
🗺️ Recomendaciones personalizadas
💡 Consejos prácticos de viaje

¿Qué te gustaría saber?""",
            'it': """Posso aiutarti con:
🏛️ Informazioni sui monumenti
📜 Storia dell'antico Egitto
🗺️ Raccomandazioni personalizzate
💡 Consigli pratici di viaggio

Cosa vorresti sapere?""",
            'ru': """Я могу помочь вам с:
🏛️ Информация о достопримечательностях
📜 История Древнего Египта
🗺️ Персональные рекомендации
💡 Практические советы

Что бы вы хотели узнать?""",
            'zh': """我可以帮助您：
🏛️ 地标和古迹信息
📜 古埃及历史
🗺️ 个性化旅行推荐
💡 实用旅行建议

您想了解什么？""",
            'ja': """お手伝いできること：
🏛️ ランドマークと記念碑の情報
📜 古代エジプトの歴史
🗺️ パーソナライズされた旅行のおすすめ
💡 実用的な旅行のヒント

何を知りたいですか？""",
            'ko': """도움을 드릴 수 있는 것:
🏛️ 랜드마크 및 기념물 정보
📜 고대 이집트 역사
🗺️ 맞춤 여행 추천
💡 실용적인 여행 팁

무엇을 알고 싶으신가요?""",
        }
        
        return default_responses.get(lang, default_responses['en'])
    
    def handle_chat(self, user_input: str, history: list) -> str:
        """
        Called by API layer.
        history comes from Supabase (last N messages).
        """
        self.conversation_history = history or []
        return self.chat(user_input)

    def _get_farewell(self) -> str:
        """Get farewell message - Multilingual"""
        farewells = {
            'en': "Goodbye! 🐫 Have an amazing Egyptian adventure! ✨",
            'ar': "مع السلامة! 🐫 أتمنى لك رحلة سعيدة في مصر! ✨",
            'fr': "Au revoir! 🐫 Passez une merveilleuse aventure en Égypte! ✨",
            'de': "Auf Wiedersehen! 🐫 Haben Sie ein tolles Ägypten-Abenteuer! ✨",
            'es': "¡Adiós! 🐫 ¡Que tengas una increíble aventura en Egipto! ✨",
            'it': "Arrivederci! 🐫 Buona avventura in Egitto! ✨",
            'pt': "Adeus! 🐫 Tenha uma incrível aventura no Egito! ✨",
            'ru': "До свидания! 🐫 Желаю вам прекрасного путешествия по Египту! ✨",
            'zh': "再见！🐫 祝您在埃及旅途愉快！✨",
            'ja': "さようなら！🐫 エジプトで素晴らしい冒険を！✨",
            'ko': "안녕히 가세요! 🐫 이집트에서 멋진 모험을 하세요! ✨",
            'nl': "Tot ziens! 🐫 Geniet van je Egyptische avontuur! ✨",
            'pl': "Do widzenia! 🐫 Życzymy wspaniałej przygody w Egipcie! ✨",
            'tr': "Hoşça kalın! 🐫 Mısır'da harika bir macera dileriz! ✨",
            'sv': "Hejdå! 🐫 Ha ett fantastiskt Egypten-äventyr! ✨",
            'hi': "अलविदा! 🐫 मिस्र में एक शानदार साहसिक यात्रा की शुभकामनाएं! ✨",
            'th': "ลาก่อน! 🐫 ขอให้มีการผจญภัยที่ยอดเยี่ยมในอียิปต์! ✨",
            'vi': "Tạm biệt! 🐫 Chúc bạn có chuyến phiêu lưu tuyệt vời ở Ai Cập! ✨",
            'id': "Selamat tinggal! 🐫 Semoga perjalanan Anda di Mesir menyenangkan! ✨",
            'el': "Αντίο! 🐫 Καλή περιπέτεια στην Αίγυπτο! ✨",
            'he': "להתראות! 🐫 שיהיה לך הרפתקה מדהימה במצרים! ✨",
        }
        return farewells.get(self.user_language, farewells['en'])

# ============================================================================
# MAIN FUNCTION
# ============================================================================

def main():
    """Main entry point"""
    
    # Create chatbot
    fahmy = UltimateFahmy()
    
    # Chat loop
    while True:
        try:
            # Get user input
            user_input = input("\n👤 You: ").strip()
            
            if not user_input:
                continue
            
            # Get response
            response = fahmy.chat(user_input)
            
            # Check for exit
            if 'Goodbye' in response or 'مع السلامة' in response or 'Au revoir' in response or '再见' in response:
                StreamingPrinter.print_response(response)
                break
            
            # Print response with streaming effect
            StreamingPrinter.print_response(response)
            
        except KeyboardInterrupt:
            print("\n\n🐫 Goodbye! Have an amazing Egyptian adventure! ✨")
            break
        except Exception as e:
            print(f"\n⚠️ Error: {e}")
            if CONFIG["debug_mode"]:
                import traceback
                traceback.print_exc()

if __name__ == "__main__":
    main()
# ====================================================================
# API ADAPTER (FOR FASTAPI / SUPABASE / FLY.IO)
# ====================================================================

_fahmy_instance = None

import uuid

def handle_chat_request(payload: dict) -> dict:
    message = payload.get("message", "")
    session_id = payload.get("session_id")

    if not session_id:
        session_id = str(uuid.uuid4())

    if session_id not in SESSIONS:
        SESSIONS[session_id] = UltimateFahmy()

    bot = SESSIONS[session_id]
    reply = bot.chat(message)

    return {
        "type": "message",
        "message": reply,
        "session_id": session_id
    }
