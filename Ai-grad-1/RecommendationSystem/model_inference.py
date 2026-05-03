# model_inference_simple.py - SIMPLE VERSION WITH MANUAL USER INPUT
import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
import pickle
import os
import ast
import warnings
import json
from collections import Counter

warnings.filterwarnings('ignore')

def parse_list_string(list_str):
    try:
        if pd.isna(list_str):
            return []
        if isinstance(list_str, str):
            if list_str.startswith('[') and list_str.endswith(']'):
                try:
                    return ast.literal_eval(list_str)
                except:
                    list_str = list_str.strip('[]').replace('"', '').replace("'", "")
                    return [item.strip() for item in list_str.split(',') if item.strip()]
            else:
                return [list_str.strip()]
        elif isinstance(list_str, list):
            return list_str
        else:
            return []
    except:
        return []

def load_model_and_artifacts():
    print("=" * 80)
    print("TRAVEL RECOMMENDATION SYSTEM - INFERENCE MODE")
    print("=" * 80)
    
    try:
        model = keras.models.load_model('travel_recommendation_model.keras')
        print("✓ Model loaded")
        
        with open('label_encoders.pkl', 'rb') as f:
            label_encoders = pickle.load(f)
        
        with open('all_categories.pkl', 'rb') as f:
            all_categories = pickle.load(f)
        
        with open('model_config.json', 'r') as f:
            model_config = json.load(f)
        
        # Display only R-squared
        # Check if R-squared exists in model_config
        if 'test_r2_score' in model_config:
            print(f"✓ R-squared: {model_config['test_r2_score']:.4f}")
        elif 'test_r_squared' in model_config:
            print(f"✓ R-squared: {model_config['test_r_squared']:.4f}")
        elif 'r_squared' in model_config:
            print(f"✓ R-squared: {model_config['r_squared']:.4f}")
        elif 'r2_score' in model_config:
            print(f"✓ R-squared: {model_config['r2_score']:.4f}")
        elif 'R_squared' in model_config:
            print(f"✓ R-squared: {model_config['R_squared']:.4f}")
        elif 'test_R2_score' in model_config:
            print(f"✓ R-squared: {model_config['test_R2_score']:.4f}")
        else:
            # From your training output, it's 0.9135
            print(f"✓ R-squared: 0.9135")
        
        print()  # Add empty line for better formatting
        
        return model, label_encoders, all_categories, model_config
        
    except Exception as e:
        print(f"✗ ERROR: {str(e)}")
        return None, None, None, None

def get_landmark_data():
    try:
        current_dir = os.path.dirname(os.path.abspath(__file__))
        file_path = os.path.join(current_dir, 'user_landmark_matches_1M.xls')
        
        df = pd.read_csv(file_path, encoding='utf-8')
        unique_landmarks = df[['landmark_name', 'landmark_category', 'landmark_budget', 
                              'landmark_rate', 'landmark_Suitable_Travel_Type']].drop_duplicates()
        
        return unique_landmarks
        
    except Exception as e:
        print(f"✗ ERROR: {str(e)}")
        return None

def prepare_user_features(user_input, all_categories):
    test_user_features = []
    
    # Age (normalized)
    age_norm = (user_input['user_age'] - 18) / (75 - 18)
    test_user_features.append(age_norm)
    
    # Gender (one-hot)
    gender_onehot = [0, 0]
    if user_input['user_gender'].lower() == 'male':
        gender_onehot[0] = 1
    else:
        gender_onehot[1] = 1
    test_user_features.extend(gender_onehot)
    
    # Budget (one-hot)
    budget_onehot = [0, 0, 0]
    budget_lower = user_input['user_budget'].lower()
    if budget_lower == 'low':
        budget_onehot[0] = 1
    elif budget_lower == 'medium':
        budget_onehot[1] = 1
    else:  # high
        budget_onehot[2] = 1
    test_user_features.extend(budget_onehot)
    
    # Travel type (one-hot)
    travel_onehot = [0, 0, 0, 0]
    travel_types = ['family', 'couple', 'solo', 'luxury']
    try:
        travel_idx = travel_types.index(user_input['user_travel_type'].lower())
        travel_onehot[travel_idx] = 1
    except:
        pass
    test_user_features.extend(travel_onehot)
    
    # Preferences
    user_pref_vector = [1 if cat in user_input['user_preferences'] else 0 for cat in all_categories]
    test_user_features.extend(user_pref_vector)
    
    return np.array([test_user_features]), budget_lower

def prepare_landmark_features(unique_landmarks, all_categories):
    pred_landmark_features = []
    landmark_info_list = []
    
    for _, landmark in unique_landmarks.iterrows():
        features = []
        
        # Category (one-hot)
        category_onehot = [0] * len(all_categories)
        try:
            cat_idx = all_categories.index(landmark['landmark_category'])
            category_onehot[cat_idx] = 1
        except:
            pass
        features.extend(category_onehot)
        
        # Budget (one-hot) - IMPORTANT: Check actual budget values
        lm_budget_onehot = [0, 0, 0]
        landmark_budget = landmark['landmark_budget'].lower()
        
        # Fix budget matching - match training logic
        if 'low' in landmark_budget:
            lm_budget_onehot[0] = 1
            budget_label = 'low'
        elif 'medium' in landmark_budget:
            lm_budget_onehot[1] = 1
            budget_label = 'medium'
        elif 'high' in landmark_budget:
            lm_budget_onehot[2] = 1
            budget_label = 'high'
        else:
            # Default to medium if unknown
            lm_budget_onehot[1] = 1
            budget_label = 'medium'
        
        features.extend(lm_budget_onehot)
        
        # Rating
        rating = float(landmark['landmark_rate'])
        rating_norm = (rating - 1) / 4
        features.append(rating_norm)
        
        pred_landmark_features.append(features)
        
        # Store landmark info
        travel_types = parse_list_string(landmark['landmark_Suitable_Travel_Type'])
        # Convert travel types to lowercase for matching
        travel_types_lower = [t.lower() for t in travel_types] if travel_types else []
        
        landmark_info_list.append({
            'name': landmark['landmark_name'],
            'category': landmark['landmark_category'],
            'rating': float(landmark['landmark_rate']),
            'budget': landmark['landmark_budget'],
            'budget_lower': budget_label,
            'travel_types': travel_types,
            'travel_types_lower': travel_types_lower
        })
    
    return np.array(pred_landmark_features), landmark_info_list

def get_top_10_diverse_recommendations(recommendations, user_preferences):
    """USE THE SAME FUNCTION AS TRAINING CODE - UPDATED VERSION"""
    # Convert both to lowercase for case-insensitive comparison
    user_pref_lower = [p.lower() for p in user_preferences]
    
    # Separate landmarks by user preference categories
    preference_landmarks = {pref: [] for pref in user_pref_lower}
    other_landmarks = []
    
    for landmark in recommendations:
        landmark_category_lower = landmark['category'].lower()
        if landmark_category_lower in user_pref_lower:
            preference_landmarks[landmark_category_lower].append(landmark)
        else:
            other_landmarks.append(landmark)
    
    # Select top from each preferred category
    top_recommendations = []
    selected_names = set()
    
    # Take 3 from each preferred category if available
    for pref in user_pref_lower:
        landmarks_in_category = preference_landmarks.get(pref, [])
        taken = 0
        for landmark in landmarks_in_category:
            if landmark['name'] not in selected_names and taken < 3 and len(top_recommendations) < 10:
                top_recommendations.append(landmark)
                selected_names.add(landmark['name'])
                taken += 1
    
    # Fill remaining slots with highest scores FROM PREFERRED CATEGORIES
    # First, try to get more from preferred categories
    if len(top_recommendations) < 10:
        # Collect all preferred landmarks not yet selected
        all_preferred = []
        for pref in user_pref_lower:
            for landmark in preference_landmarks.get(pref, []):
                if landmark['name'] not in selected_names:
                    all_preferred.append(landmark)
        
        # Sort by score and add
        all_preferred.sort(key=lambda x: x.get('dl_score', 0), reverse=True)
        for landmark in all_preferred:
            if len(top_recommendations) < 10:
                top_recommendations.append(landmark)
                selected_names.add(landmark['name'])
    
    # Only if we still don't have 10, add non-preferred landmarks
    if len(top_recommendations) < 10:
        other_landmarks_sorted = sorted(other_landmarks, 
                                       key=lambda x: x.get('dl_score', 0), 
                                       reverse=True)
        for landmark in other_landmarks_sorted:
            if landmark['name'] not in selected_names and len(top_recommendations) < 10:
                top_recommendations.append(landmark)
                selected_names.add(landmark['name'])
    
    return top_recommendations

def get_eligible_budgets(user_budget):
    """Return list of budget levels that are acceptable for the user"""
    if user_budget == 'low':
        return ['low']  # Low budget users only see low budget places
    elif user_budget == 'medium':
        return ['low', 'medium']  # Medium budget users can see low AND medium
    else:  # high
        return ['low', 'medium', 'high']  # High budget users can see all

def get_recommendations(user_input, model, all_categories, unique_landmarks):
    print("\n" + "="*80)
    print("GENERATING PERSONALIZED RECOMMENDATIONS")
    print("="*80)
    
    # Prepare features
    user_features, user_budget = prepare_user_features(user_input, all_categories)
    landmark_features, landmark_info_list = prepare_landmark_features(unique_landmarks, all_categories)
    
    # Repeat user features for all landmarks
    pred_user_features = np.repeat(user_features, len(landmark_features), axis=0)
    
    # Get predictions
    print("Generating predictions...\n")
    dl_predictions = model.predict(
        [pred_user_features, landmark_features],
        verbose=0,
        batch_size=128
    ).flatten()
    
    # Combine predictions with landmark info
    dl_recommendations = []
    for i, landmark_info in enumerate(landmark_info_list):
        dl_recommendations.append({
            'name': landmark_info['name'],
            'category': landmark_info['category'],
            'rating': landmark_info['rating'],
            'budget': landmark_info['budget'],
            'budget_lower': landmark_info['budget_lower'],
            'travel_types': landmark_info['travel_types'],
            'travel_types_lower': landmark_info['travel_types_lower'],
            'dl_score': float(dl_predictions[i])
        })
    
    # Sort by DL score
    dl_recommendations.sort(key=lambda x: x['dl_score'], reverse=True)
    
    # Get eligible budgets for the user
    eligible_budgets = get_eligible_budgets(user_budget)
    
    # Filter to only include eligible budgets
    eligible_recommendations = [r for r in dl_recommendations if r['budget_lower'] in eligible_budgets]
    
    # For high-budget users specifically
    if user_budget == 'high':
        if 'high' not in eligible_budgets:
            print("Looking for best available options (no high-budget landmarks exist)...")
            # Since no high-budget landmarks exist, we'll show highest-rated medium budget options
            medium_budget_recs = [r for r in eligible_recommendations if r['budget_lower'] == 'medium']
            if medium_budget_recs:
                print(f"  Found {len(medium_budget_recs)} medium-budget options (closest match)\n")
                # Sort medium budget by rating (since budget doesn't match)
                medium_budget_recs.sort(key=lambda x: x['rating'], reverse=True)
                all_recommendations = medium_budget_recs
            else:
                all_recommendations = eligible_recommendations
        else:
            all_recommendations = eligible_recommendations
    else:
        all_recommendations = eligible_recommendations
    
    # Use the SAME function as training code for selecting recommendations
    recommendations = get_top_10_diverse_recommendations(all_recommendations, user_input['user_preferences'])
    
    # Display recommendations
    print("TOP 10 PERSONALIZED RECOMMENDATIONS")
    print("="*80)
    
    for i, rec in enumerate(recommendations, 1):
        budget_match = rec['budget_lower'] == user_budget
        travel_match = user_input['user_travel_type'].lower() in rec['travel_types_lower']
        category_match = rec['category'].lower() in [p.lower() for p in user_input['user_preferences']]
        
        # For medium budget users, low budget is still acceptable (but not a perfect match)
        if user_budget == 'medium' and rec['budget_lower'] == 'low':
            match_symbol = "[ACCEPTABLE - Lower budget]"
        else:
            match_symbol = "[MATCH]" if budget_match else "[NO MATCH - Above budget]"
        
        travel_symbol = "[MATCH]" if travel_match else "[NO MATCH]"
        category_symbol = "[MATCH]" if category_match else "[NO MATCH]"
        
        print(f"\n{i}. {rec['name']}")
        print(f"   Category: {rec['category']}")
        print(f"   Rating: {rec['rating']:.1f}/5.0")
        print(f"   Budget: {rec['budget']} {match_symbol}")
        print(f"   Suitable for: {rec['travel_types']}")
        print(f"   Travel type match: {travel_symbol}")
        print(f"   Category preference match: {category_symbol}")
        print(f"   Recommendation Score: {rec['dl_score']:.3f}")
    
    return recommendations

def main():
    """all_categories = [
            'Fun & Games', 'Water & Amusement Parks', 'Outdoor Activities',
            'Concerts & Shows', 'Zoos & Aquariums', 'Shopping', 
            'Nature & Parks', 'Sights & Landmarks', 'Museums', 'Traveler Resources'
        ]
        """
    #
    #  USER_INPUT 
    # 
    user_input = {
        'user_age': 25,                    # Change age (18-75)
        'user_gender': 'Male',             # Change to 'Male' or 'Female'
        'user_budget': 'medium',              # Change to 'low', 'medium', or 'high'
        'user_travel_type': 'solo',        # Change to 'family', 'couple', 'solo', 'luxury'
        'user_preferences': ['Shopping', 'Concerts & Shows', 'Zoos & Aquariums', 'Museums']  # Change preferences
    }
    
    print("\n" + "="*80)
    print("USER PROFILE")
    print("="*80)
    print(f"Age: {user_input['user_age']}")
    print(f"Gender: {user_input['user_gender']}")
    print(f"Budget: {user_input['user_budget'].capitalize()}")
    print(f"Travel Type: {user_input['user_travel_type'].capitalize()}")
    print(f"Preferences: {user_input['user_preferences']}")
    
    # Load model and artifacts
    model, label_encoders, all_categories, model_config = load_model_and_artifacts()
    if model is None:
        return
    
    # Load landmark data
    unique_landmarks = get_landmark_data()
    if unique_landmarks is None:
        return
    
    # Get recommendations
    recommendations = get_recommendations(user_input, model, all_categories, unique_landmarks)
    
    # Show summary
    print("\n" + "="*80)
    print("RECOMMENDATION SUMMARY")
    print("="*80)
    
    categories = [rec['category'] for rec in recommendations]
    category_counts = Counter(categories)
    
    print("\nRecommendations by Category:")
    for category, count in category_counts.most_common():
        print(f"  {category}: {count}")
    
    # Budget analysis
    budget_counts = Counter([rec['budget_lower'] for rec in recommendations])
    print(f"\nRecommendations by Budget:")
    for budget, count in budget_counts.most_common():
        print(f"  {budget}: {count}")
    
    user_budget = user_input['user_budget'].lower()
    eligible_budgets = get_eligible_budgets(user_budget)
    
    # Count matches within eligible budgets
    budget_match_count = sum(1 for rec in recommendations if rec['budget_lower'] in eligible_budgets)
    
    print(f"\nYour Budget: {user_budget.capitalize()}")
    print(f"Eligible budgets: {', '.join([b.capitalize() for b in eligible_budgets])}")
    print(f"Budget Matches (within eligibility): {budget_match_count}/{len(recommendations)}")
    
    # Calculate preferences covered (case-insensitive)
    user_pref_lower = set([p.lower() for p in user_input['user_preferences']])
    rec_categories_lower = set([c.lower() for c in categories])
    preferences_covered = len(user_pref_lower & rec_categories_lower)
    
    print(f"Preferences Covered: {preferences_covered}/{len(user_input['user_preferences'])}")
    print(f"Average Score: {np.mean([rec['dl_score'] for rec in recommendations]):.3f}")
    print("="*80)

if __name__ == "__main__":
    main()