# fahmy_advanced.py - COMPLETE FIX WITH STREAMING OUTPUT
import ollama
import requests
import json
import os
import sys
import re
import time
import threading
from typing import Dict, List, Optional
from queue import Queue

print("=" * 70)
print("🤖 FAHMY - Advanced Egyptian Travel Assistant")
print("=" * 70)
print("\n💬 Natural conversation with streaming responses")
print("🌟 Uses your actual recommendation model")
print("🔄 Smart edit/add/remove understanding")
print("🌍 True multilingual support")
print("❌ Type 'exit' to quit\n")
print("=" * 70)

# ============================================================================
# STREAMING OUTPUT HANDLER
# ============================================================================

class StreamingPrinter:
    """Prints text with typing effect"""
    
    @staticmethod
    def print_stream(text, delay=0.02):
        """Print text with typing effect"""
        for char in text:
            print(char, end='', flush=True)
            time.sleep(delay)
        print()
    
    @staticmethod
    def print_bot_response(text):
        """Print bot response with formatting"""
        print("\n" + "═" * 60)
        print("🤖 Fahmy: ", end='', flush=True)
        StreamingPrinter.print_stream(text, delay=0.01)
        print("─" * 60)

# ============================================================================
# FIXED RECOMMENDER WITH ACTUAL MODEL INTEGRATION
# ============================================================================

class FixedRecommender:
    def __init__(self):
        self.model = None
        self.all_categories = None
        self.unique_landmarks = None
        self.is_initialized = False
        self.model_config = None
        
    def initialize(self):
        """Initialize with FIXED paths"""
        if self.is_initialized:
            return True
            
        print("[INIT] Loading recommendation engine...")
        
        try:
            # FIXED: Use correct path to RecommendationSystem
            current_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Try multiple possible locations
            possible_paths = [
                os.path.join(current_dir, "..", "RecommendationSystem"),  # Parent folder
                os.path.join(current_dir, "RecommendationSystem"),  # Same folder
                r"H:\Ai\RecommendationSystem",  # Absolute path
                os.path.join(os.path.dirname(current_dir), "RecommendationSystem"),
            ]
            
            for path in possible_paths:
                if os.path.exists(path):
                    print(f"[FOUND] Model at: {path}")
                    sys.path.append(path)
                    
                    # Check for required files
                    required_files = [
                        "travel_recommendation_model.keras",
                        "all_categories.pkl", 
                        "label_encoders.pkl",
                        "user_landmark_matches_1M.xls"
                    ]
                    
                    missing = []
                    for file in required_files:
                        file_path = os.path.join(path, file)
                        if not os.path.exists(file_path):
                            missing.append(file)
                    
                    if missing:
                        print(f"[WARN] Missing files: {missing}")
                        # Try to find files in other locations
                        for file in missing:
                            # Look in current directory
                            if os.path.exists(os.path.join(current_dir, file)):
                                print(f"[INFO] Found {file} in current directory")
                    
                    try:
                        # Import the actual model_inference
                        from model_inference import (
                            load_model_and_artifacts,
                            get_landmark_data,
                            get_recommendations as get_recs_from_model,
                            get_top_10_diverse_recommendations
                        )
                        
                        print("[LOAD] Loading model and data...")
                        self.model, _, self.all_categories, self.model_config = load_model_and_artifacts()
                        self.unique_landmarks = get_landmark_data()
                        
                        if self.model is not None:
                            self.is_initialized = True
                            print(f"[SUCCESS] Loaded model and {len(self.unique_landmarks)} landmarks!")
                            print(f"[INFO] Available categories: {self.all_categories}")
                            return True
                            
                    except ImportError as e:
                        print(f"[ERROR] Import failed: {e}")
                        continue
                    except Exception as e:
                        print(f"[ERROR] Loading failed: {e}")
                        continue
            
            print("[INFO] Using enhanced mock data with proper user profile format")
            self.all_categories = [
                'Fun & Games', 'Water & Amusement Parks', 'Outdoor Activities',
                'Concerts & Shows', 'Zoos & Aquariums', 'Shopping', 
                'Nature & Parks', 'Sights & Landmarks', 'Museums', 'Traveler Resources'
            ]
            self.model_config = {"version": "mock_1.0"}
            return True
            
        except Exception as e:
            print(f"[FATAL] Initialization error: {e}")
            return False
    
    def get_recommendations(self, user_profile: Dict, limit: int = 15) -> List[Dict]:
        """Get recommendations using ACTUAL user profile format"""
        print(f"\n[REC] Generating for profile: {user_profile}")
        
        # Ensure profile matches model_inference.py format
        formatted_profile = self._format_user_profile(user_profile)
        
        # Try actual model
        if self.is_initialized and self.model:
            try:
                from model_inference import get_recommendations as get_recs_from_model
                
                print("[REC] Using actual model...")
                recommendations = get_recs_from_model(
                    formatted_profile,
                    self.model,
                    self.all_categories,
                    self.unique_landmarks
                )
                
                print(f"[SUCCESS] Got {len(recommendations)} recommendations")
                return recommendations[:limit] if limit else recommendations
                
            except Exception as e:
                print(f"[ERROR] Model failed: {e}")
        
        # Enhanced mock data with proper format
        return self._get_enhanced_mock_recommendations(formatted_profile, limit)
    
    def _format_user_profile(self, profile: Dict) -> Dict:
        """Format profile to match model_inference.py expected format"""
        formatted = {
            'user_age': profile.get('user_age', 25),
            'user_gender': profile.get('user_gender', 'Not specified'),
            'user_budget': profile.get('user_budget', 'medium'),
            'user_travel_type': profile.get('user_travel_type', 'solo'),
            'user_preferences': profile.get('user_preferences', ['Museums', 'Sights & Landmarks'])
        }
        
        # Ensure preferences are from available categories
        if self.all_categories:
            formatted['user_preferences'] = [
                pref for pref in formatted['user_preferences'] 
                if pref in self.all_categories
            ]
        
        # If no valid preferences, use defaults
        if not formatted['user_preferences']:
            formatted['user_preferences'] = ['Museums', 'Sights & Landmarks']
        
        return formatted
    
    def _get_enhanced_mock_recommendations(self, user_profile: Dict, limit: int = 15) -> List[Dict]:
        """Enhanced mock data matching actual model format"""
        # All available places with proper categories
        all_places = []
        
        # Add places from each category
        categories = self.all_categories or [
            'Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks',
            'Sights & Landmarks', 'Zoos & Aquariums', 'Concerts & Shows',
            'Fun & Games', 'Water & Amusement Parks', 'Traveler Resources'
        ]
        
        # Generate places for each category
        place_templates = {
            'Museums': ['Egyptian Museum', 'Coptic Museum', 'Islamic Art Museum', 'Nubian Museum'],
            'Shopping': ['Khan el-Khalili', 'City Stars Mall', 'Arcadia Mall', 'Maadi Grand Mall'],
            'Outdoor Activities': ['Nile Cruise', 'Desert Safari', 'Red Sea Diving', 'Hot Air Balloon'],
            'Sights & Landmarks': ['Pyramids of Giza', 'Luxor Temple', 'Valley of Kings', 'Abu Simbel'],
            'Nature & Parks': ['Al-Azhar Park', 'Ras Mohammed', 'Wadi Degla', 'Qattara Depression'],
            'Zoos & Aquariums': ['Giza Zoo', 'Alexandria Aquarium', 'Dolphin Show', 'Bird Garden'],
            'Concerts & Shows': ['Cairo Opera House', 'Sound & Light Show', 'Sufi Dance', 'Traditional Music'],
            'Fun & Games': ['KidZania', 'Magic Planet', 'Boomerang Park', 'Cairo Festival City'],
            'Water & Amusement Parks': ['Dream Park', 'Aqua Park', 'Sindbad', 'Fagnoon'],
            'Traveler Resources': ['Tourist Information', 'Guided Tours', 'Transport Hub', 'Visitor Center']
        }
        
        # Create places
        for category, names in place_templates.items():
            for i, name in enumerate(names):
                # Determine budget based on index
                budgets = ['low', 'medium', 'high']
                budget = budgets[i % 3]
                
                # Determine travel types
                travel_types = []
                if category in ['Museums', 'Sights & Landmarks', 'Nature & Parks']:
                    travel_types = ['family', 'couple', 'solo', 'luxury']
                elif category in ['Shopping', 'Fun & Games']:
                    travel_types = ['family', 'couple', 'solo']
                elif category in ['Outdoor Activities', 'Water & Amusement Parks']:
                    travel_types = ['family', 'couple']
                elif category in ['Concerts & Shows', 'Traveler Resources']:
                    travel_types = ['couple', 'luxury']
                else:
                    travel_types = ['family', 'solo']
                
                # Create place
                place = {
                    'name': f"{name}",
                    'category': category,
                    'rating': 4.0 + (i * 0.1) + (0.3 if 'Museum' in name or 'Pyramid' in name else 0),
                    'budget': budget,
                    'travel_types': travel_types,
                    'budget_lower': budget,
                    'travel_types_lower': [t.lower() for t in travel_types]
                }
                all_places.append(place)
        
        # Score and filter based on user profile
        scored_places = []
        for place in all_places:
            score = 0.5  # Base score
            
            # Category match (40 points like in model)
            if place['category'] in user_profile['user_preferences']:
                score += 0.4
            
            # Budget match (30 points like in model)
            if place['budget_lower'] == user_profile['user_budget'].lower():
                score += 0.3
            
            # Travel type match (30 points like in model)
            if user_profile['user_travel_type'].lower() in place['travel_types_lower']:
                score += 0.3
            
            # Age adjustment
            age = user_profile['user_age']
            if age < 25 and place['category'] in ['Outdoor Activities', 'Fun & Games']:
                score += 0.1
            elif age > 40 and place['category'] in ['Museums', 'Nature & Parks']:
                score += 0.1
            
            place['dl_score'] = min(score, 1.0)
            scored_places.append(place)
        
        # Sort by score
        scored_places.sort(key=lambda x: x['dl_score'], reverse=True)
        
        # Apply diversity like get_top_10_diverse_recommendations
        return self._apply_diversity(scored_places[:limit*2], user_profile['user_preferences'])[:limit]
    
    def _apply_diversity(self, places: List[Dict], user_prefs: List[str]) -> List[Dict]:
        """Apply diversity algorithm similar to training code"""
        if not places:
            return places
        
        # Convert to lowercase for comparison
        user_prefs_lower = [p.lower() for p in user_prefs]
        
        # Separate by category
        pref_places = {pref: [] for pref in user_prefs_lower}
        other_places = []
        
        for place in places:
            place_cat_lower = place['category'].lower()
            if place_cat_lower in user_prefs_lower:
                pref_places[place_cat_lower].append(place)
            else:
                other_places.append(place)
        
        # Select diverse set
        selected = []
        selected_names = set()
        
        # Take from each preferred category
        for pref in user_prefs_lower:
            category_places = pref_places.get(pref, [])
            taken = 0
            for place in category_places:
                if place['name'] not in selected_names and taken < 2 and len(selected) < 10:
                    selected.append(place)
                    selected_names.add(place['name'])
                    taken += 1
        
        # Fill with highest scores from preferred categories
        if len(selected) < 10:
            all_pref = []
            for pref in user_prefs_lower:
                for place in pref_places.get(pref, []):
                    if place['name'] not in selected_names:
                        all_pref.append(place)
            
            all_pref.sort(key=lambda x: x['dl_score'], reverse=True)
            for place in all_pref:
                if len(selected) < 10:
                    selected.append(place)
                    selected_names.add(place['name'])
        
        # Add from other categories if needed
        if len(selected) < 10:
            other_places.sort(key=lambda x: x['dl_score'], reverse=True)
            for place in other_places:
                if place['name'] not in selected_names and len(selected) < 10:
                    selected.append(place)
                    selected_names.add(place['name'])
        
        return selected

# ============================================================================
# ADVANCED CHATBOT WITH CONTEXT MEMORY
# ============================================================================

class AdvancedFahmy:
    def __init__(self):
        self.recommender = FixedRecommender()
        self.conversation = []
        self.current_recs = []
        self.user_profile = {
            'user_age': 25,
            'user_gender': 'Not specified',
            'user_budget': 'medium',
            'user_travel_type': 'solo',
            'user_preferences': ['Museums', 'Sights & Landmarks']
        }
        self.conversation_state = "general"  # general, collecting_profile, showing_recs, editing
        
        # Initialize recommender
        print("\n[INIT] Loading systems...")
        success = self.recommender.initialize()
        if success:
            print("[SUCCESS] All systems ready! ✅")
        else:
            print("[INFO] Enhanced mode active ⚠️")
        
        # Advanced system prompt
        self.system_prompt = """You are Fahmy, an expert Egyptian travel guide having a natural conversation.

IMPORTANT RULES:
1. NEVER introduce yourself unless asked
2. Continue conversations naturally without repeating
3. Use contextual responses based on chat history
4. Be concise but warm and human-like
5. Detect and respond in user's language
6. Use natural expressions: "hmm", "actually", "you know"

CONVERSATION STATES:
- GENERAL: Answer travel questions about Egypt
- PROFILE_COLLECTION: Ask for age, budget, travel type, preferences
- SHOWING_RECS: Showing recommendations, offer edits
- EDITING: Handle add/remove/change requests

EDIT UNDERSTANDING:
- "Edit" or "change": Modify existing preferences
- "Add" or "include": Add new preferences  
- "Remove" or "delete": Remove preferences
- "More" or "different": Show more options

EXAMPLE FLOWS:
User: "Hi, recommend places"
You: "Sure! To personalize: what's your age and travel style?"

User: "I'm 25, solo, medium budget"
You: "Great! What interests you? Museums, shopping, adventures?"

User: "Add food tours"
You: "Got it, adding food experiences. Here's your updated list..."

User: "مرحبا"
You: "أهلاً! كيف يمكنني مساعدتك في رحلتك إلى مصر؟"

Be natural, contextual, and helpful!"""

    def chat(self, user_input: str) -> str:
        """Process user input with context awareness"""
        self.conversation.append({"role": "user", "content": user_input})
        
        # Exit check
        if user_input.lower() in ['exit', 'quit', 'bye', 'خروج']:
            return "شكراً لك! رحلة سعيدة إلى مصر 🐫✨\nThanks! Have a wonderful trip to Egypt!"
        
        # Parse intent
        intent = self._parse_intent(user_input)
        
        # Handle based on intent and state
        if intent == "recommendation_request":
            self.conversation_state = "collecting_profile"
            return self._handle_recommendation_start(user_input)
        
        elif intent == "edit_request":
            return self._handle_edit_request(user_input)
        
        elif intent == "add_request":
            return self._handle_add_request(user_input)
        
        elif intent == "remove_request":
            return self._handle_remove_request(user_input)
        
        elif intent == "change_budget":
            return self._handle_change_budget(user_input)
        
        elif intent == "change_travel_type":
            return self._handle_change_travel_type(user_input)
        
        elif intent == "more_request":
            return self._handle_more_request(user_input)
        
        elif self.conversation_state == "collecting_profile":
            return self._collect_profile_info(user_input)
        
        else:
            # General conversation
            return self._get_ollama_response(user_input)
    
    def _parse_intent(self, text: str) -> str:
        """Parse user intent accurately"""
        text_lower = text.lower()
        
        # Recommendation requests
        rec_keywords = ['recommend', 'suggest', 'places to', 'where should', 
                       'what to see', 'itinerary', 'plan my trip', 'توصيات']
        if any(kw in text_lower for kw in rec_keywords):
            return "recommendation_request"
        
        # Edit/change
        if any(kw in text_lower for kw in ['edit', 'change', 'modify', 'update']):
            if 'budget' in text_lower:
                return "change_budget"
            elif any(kw in text_lower for kw in ['travel', 'type', 'solo', 'couple', 'family', 'luxury']):
                return "change_travel_type"
            else:
                return "edit_request"
        
        # Add/include
        if any(kw in text_lower for kw in ['add', 'include', 'also want', 'plus']):
            return "add_request"
        
        # Remove/delete
        if any(kw in text_lower for kw in ['remove', 'delete', 'exclude', 'no more', 'less']):
            return "remove_request"
        
        # More/different
        if any(kw in text_lower for kw in ['more', 'another', 'other', 'different', 'alternatives']):
            return "more_request"
        
        return "general"
    
    def _handle_recommendation_start(self, user_input: str) -> str:
        """Start recommendation flow"""
        # Try to extract info from initial message
        extracted = self._extract_profile_from_text(user_input)
        self.user_profile.update(extracted)
        
        # Check what we need
        needed = self._get_needed_info()
        
        if not needed:
            # Have all info, generate recs
            self.conversation_state = "showing_recs"
            return self._generate_recommendations()
        else:
            # Ask for missing info
            questions = {
                'age': "How young are you feeling? (Age helps me tailor suggestions)",
                'travel_type': "Who's joining? Solo, couple, family, or luxury travel?",
                'budget': "Budget level: low, medium, or high?",
                'preferences': "What excites you? Museums, shopping, adventures, food?"
            }
            
            response = "To personalize your recommendations:\n"
            for item in needed[:2]:  # Ask max 2 at once
                if item in questions:
                    response += f"• {questions[item]}\n"
            
            return response
    
    def _collect_profile_info(self, user_input: str) -> str:
        """Collect profile information"""
        # Extract info
        extracted = self._extract_profile_from_text(user_input)
        self.user_profile.update(extracted)
        
        # Check if we have all info
        needed = self._get_needed_info()
        
        if not needed:
            self.conversation_state = "showing_recs"
            return self._generate_recommendations()
        else:
            # Ask for remaining info
            questions = {
                'age': "What's your age?",
                'travel_type': "Traveling solo, as a couple, with family, or luxury?",
                'budget': "Budget: low, medium, or high?",
                'preferences': "Interests? (e.g., history, shopping, food)"
            }
            
            response = "Great! Next:\n"
            for item in needed[:1]:  # Ask one at a time
                if item in questions:
                    response += f"{questions[item]}"
            
            return response
    
    def _extract_profile_from_text(self, text: str) -> Dict:
        """Extract profile from text with accurate parsing"""
        profile_updates = {}
        text_lower = text.lower()
        
        # Age
        age_match = re.search(r'(\d+)\s*(years?|y\.?o\.?|yo|age)', text_lower)
        if age_match:
            try:
                profile_updates['user_age'] = int(age_match.group(1))
            except:
                pass
        
        # Travel type
        if any(kw in text_lower for kw in ['couple', 'romantic', 'partner', 'boyfriend', 'girlfriend']):
            profile_updates['user_travel_type'] = 'couple'
        elif any(kw in text_lower for kw in ['family', 'kids', 'children', 'with family']):
            profile_updates['user_travel_type'] = 'family'
        elif any(kw in text_lower for kw in ['luxury', 'premium', '5-star']):
            profile_updates['user_travel_type'] = 'luxury'
        elif any(kw in text_lower for kw in ['solo', 'alone', 'by myself']):
            profile_updates['user_travel_type'] = 'solo'
        
        # Budget
        if any(kw in text_lower for kw in ['low budget', 'cheap', 'economical']):
            profile_updates['user_budget'] = 'low'
        elif any(kw in text_lower for kw in ['high budget', 'luxury', 'expensive']):
            profile_updates['user_budget'] = 'high'
        elif any(kw in text_lower for kw in ['medium', 'mid-range', 'moderate']):
            profile_updates['user_budget'] = 'medium'
        
        # Preferences
        categories = self.recommender.all_categories or [
            'Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks',
            'Sights & Landmarks', 'Zoos & Aquariums', 'Concerts & Shows',
            'Fun & Games', 'Water & Amusement Parks', 'Traveler Resources'
        ]
        
        found_prefs = []
        for category in categories:
            cat_lower = category.lower()
            # Check for category name or synonyms
            if cat_lower in text_lower:
                found_prefs.append(category)
            else:
                # Check synonyms
                synonyms = {
                    'Museums': ['museum', 'history', 'art', 'antique'],
                    'Shopping': ['shop', 'market', 'mall', 'bazaar'],
                    'Outdoor Activities': ['outdoor', 'adventure', 'hiking', 'cruise'],
                    'Sights & Landmarks': ['sight', 'landmark', 'pyramid', 'temple'],
                    'Nature & Parks': ['nature', 'park', 'garden', 'walk'],
                    'Food': ['food', 'eat', 'cuisine', 'restaurant', 'cooking']
                }
                if category in synonyms:
                    for synonym in synonyms[category]:
                        if synonym in text_lower:
                            found_prefs.append(category)
                            break
        
        if found_prefs:
            profile_updates['user_preferences'] = found_prefs
        
        return profile_updates
    
    def _get_needed_info(self) -> List[str]:
        """Check what profile info is still needed"""
        needed = []
        
        if 'user_age' not in self.user_profile or self.user_profile['user_age'] == 25:
            needed.append('age')
        
        if 'user_travel_type' not in self.user_profile:
            needed.append('travel_type')
        
        if 'user_budget' not in self.user_profile:
            needed.append('budget')
        
        if 'user_preferences' not in self.user_profile or len(self.user_profile['user_preferences']) < 2:
            needed.append('preferences')
        
        return needed
    
    def _generate_recommendations(self) -> str:
        """Generate and format recommendations"""
        self.conversation_state = "showing_recs"
        
        print(f"\n[PROFILE] Using: {self.user_profile}")
        
        # Get recommendations
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        
        if not self.current_recs:
            return "Hmm, let me adjust the criteria. What are you most interested in?"
        
        # Format response
        response = "🎯 **Based on your preferences, here are personalized recommendations:**\n\n"
        
        for i, rec in enumerate(self.current_recs, 1):
            # Emojis
            emojis = {
                'Museums': '🏛️', 'Shopping': '🛍️', 'Outdoor Activities': '🚵',
                'Nature & Parks': '🌳', 'Sights & Landmarks': '🗽',
                'Zoos & Aquariums': '🐠', 'Concerts & Shows': '🎭',
                'Fun & Games': '🎪', 'Water & Amusement Parks': '🎢',
                'Traveler Resources': 'ℹ️'
            }
            emoji = emojis.get(rec['category'], '📍')
            
            response += f"{i}. {emoji} **{rec['name']}**\n"
            response += f"   📍 {rec['category']} | ⭐ {rec.get('rating', 4.5):.1f}/5.0 | 💰 {rec.get('budget', 'medium')}\n"
            
            # Match score
            if 'dl_score' in rec:
                match = rec['dl_score'] * 100
                response += f"   🎯 Match: {match:.0f}%"
            
            # Travel type indicator
            travel_type = self.user_profile.get('user_travel_type', 'solo')
            if travel_type in rec.get('travel_types', []):
                response += f" | ✅ Perfect for {travel_type}"
            
            response += "\n\n"
        
        response += "**💬 You can:**\n"
        response += "• **Edit**: 'Change budget to high'\n"
        response += "• **Add**: 'Include food experiences'\n"
        response += "• **Remove**: 'No shopping please'\n"
        response += "• **Details**: 'Tell me about #3'\n"
        response += "• **More**: 'Show different options'\n"
        
        return response
    
    def _handle_edit_request(self, user_input: str) -> str:
        """Handle edit requests"""
        self.conversation_state = "editing"
        
        # Extract what to edit
        if 'preference' in user_input.lower() or 'interest' in user_input.lower():
            return "What would you like to change about your interests?"
        
        # If we're already showing recs, regenerate with current profile
        if self.current_recs:
            return self._generate_recommendations()
        
        return "What would you like to edit? (Budget, travel type, or interests)"
    
    def _handle_add_request(self, user_input: str) -> str:
        """Handle add requests"""
        text_lower = user_input.lower()
        
        # Find what to add
        categories = self.recommender.all_categories or [
            'Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks',
            'Sights & Landmarks', 'Food'
        ]
        
        added = []
        for category in categories:
            cat_lower = category.lower()
            if cat_lower in text_lower or any(word in text_lower for word in cat_lower.split()):
                if 'user_preferences' not in self.user_profile:
                    self.user_profile['user_preferences'] = []
                
                if category not in self.user_profile['user_preferences']:
                    self.user_profile['user_preferences'].append(category)
                    added.append(category)
        
        if added:
            response = f"✅ Added {', '.join(added)} to your interests!\n\n"
        else:
            response = "What would you like to add? (e.g., 'add outdoor adventures')\n"
        
        # Regenerate recommendations
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        response += self._generate_recommendations()
        
        return response
    
    def _handle_remove_request(self, user_input: str) -> str:
        """Handle remove requests"""
        text_lower = user_input.lower()
        
        removed = []
        if 'user_preferences' in self.user_profile:
            categories = self.recommender.all_categories or [
                'Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks',
                'Sights & Landmarks', 'Food'
            ]
            
            for category in categories[:]:  # Copy list
                cat_lower = category.lower()
                if cat_lower in text_lower or any(word in text_lower for word in cat_lower.split()):
                    if category in self.user_profile['user_preferences']:
                        self.user_profile['user_preferences'].remove(category)
                        removed.append(category)
        
        if removed:
            response = f"✅ Removed {', '.join(removed)} from your interests.\n\n"
        else:
            response = "What would you like to remove? (e.g., 'remove museums')\n"
        
        # Regenerate recommendations
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        response += self._generate_recommendations()
        
        return response
    
    def _handle_change_budget(self, user_input: str) -> str:
        """Handle budget change"""
        text_lower = user_input.lower()
        
        if 'low' in text_lower:
            self.user_profile['user_budget'] = 'low'
            response = "✅ Switched to budget-friendly options!\n\n"
        elif 'high' in text_lower:
            self.user_profile['user_budget'] = 'high'
            response = "✅ Switched to luxury selections!\n\n"
        else:
            self.user_profile['user_budget'] = 'medium'
            response = "✅ Switched to mid-range options!\n\n"
        
        # Regenerate
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        response += self._generate_recommendations()
        
        return response
    
    def _handle_change_travel_type(self, user_input: str) -> str:
        """Handle travel type change"""
        text_lower = user_input.lower()
        
        if 'couple' in text_lower:
            self.user_profile['user_travel_type'] = 'couple'
            response = "✅ Now showing couple-friendly spots!\n\n"
        elif 'family' in text_lower:
            self.user_profile['user_travel_type'] = 'family'
            response = "✅ Now showing family-friendly options!\n\n"
        elif 'luxury' in text_lower:
            self.user_profile['user_travel_type'] = 'luxury'
            response = "✅ Now showing premium experiences!\n\n"
        else:
            self.user_profile['user_travel_type'] = 'solo'
            response = "✅ Now showing solo traveler favorites!\n\n"
        
        # Regenerate
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        response += self._generate_recommendations()
        
        return response
    
    def _handle_more_request(self, user_input: str) -> str:
        """Handle requests for more/different options"""
        # Just regenerate with current profile
        self.current_recs = self.recommender.get_recommendations(self.user_profile, limit=12)
        return "🔄 **Here are more options for you:**\n\n" + self._generate_recommendations()
    
    def _get_ollama_response(self, user_input: str) -> str:
        """Get Ollama response with conversation context"""
        try:
            # Prepare messages with system prompt
            messages = [{"role": "system", "content": self.system_prompt}]
            
            # Add conversation history (last 4 exchanges)
            start_idx = max(0, len(self.conversation) - 8)
            messages.extend(self.conversation[start_idx:])
            
            # Ensure last message is current
            if messages[-1]["role"] != "user":
                messages.append({"role": "user", "content": user_input})
            
            # Get response
            response = ollama.chat(
                model="mistral:7b",
                messages=messages,
                options={
                    "temperature": 0.8,
                    "top_p": 0.9,
                    "num_predict": 300,
                    "repeat_penalty": 1.1
                }
            )
            
            return response['message']['content']
            
        except Exception as e:
            return f"Hmm, let me try that again... (Technical: {str(e)[:50]})"

# ============================================================================
# MAIN WITH STREAMING OUTPUT
# ============================================================================

def main():
    print("🚀 Initializing advanced Fahmy...\n")
    
    # Create chatbot
    fahmy = AdvancedFahmy()
    
    print("✅ Ready! Chat naturally:\n")
    
    while True:
        try:
            # Get user input
            user_input = input("👤 You: ").strip()
            if not user_input:
                continue
            
            # Get response
            response = fahmy.chat(user_input)
            
            # Print with streaming effect
            StreamingPrinter.print_bot_response(response)
            
        except KeyboardInterrupt:
            print("\n\n🐫 مع السلامة! Have an amazing Egyptian adventure! ✨")
            break
        except Exception as e:
            print(f"\n⚠ Error: {e}")

if __name__ == "__main__":
    main()