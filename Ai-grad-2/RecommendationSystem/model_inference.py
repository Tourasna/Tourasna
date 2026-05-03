# model_inference.py — Inference Pipeline v4.0
# ============================================================================
# Travel Recommendation System - Inference Pipeline
# ============================================================================
# Uses shared utilities from utils.py for consistency with training code.
# Compatible with models trained by travel_recommendation_training.py v4.0.
# ============================================================================

import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
import pickle
import os
import json
import warnings
from typing import Dict, Any
from collections import Counter

from utils import (
    prepare_user_features_single,
    prepare_landmark_features_batch,
    get_top_n_diverse_recommendations,
    get_eligible_budgets,
    validate_user_input,
    ALL_CATEGORIES,
    RATING_MIN,
    RATING_MAX,
)

warnings.filterwarnings('ignore')

# All file paths are relative to this script's directory
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def load_model_and_artifacts():
    """Load trained model and all associated artifacts.

    Uses ``compile=False`` so the model loads without needing the custom
    CompositeHuberMAELoss class — inference only needs the forward pass.

    Returns:
        (model, label_encoders, all_categories, model_config) or (None, None, None, None) on error
    """
    print("=" * 80)
    print("TRAVEL RECOMMENDATION SYSTEM - INFERENCE MODE v4.0")
    print("=" * 80)

    try:
        model_path = os.path.join(SCRIPT_DIR, 'travel_recommendation_model.keras')
        # compile=False: we only need the forward pass for inference,
        # so there is no need to reconstruct the training loss/optimizer.
        model = keras.models.load_model(model_path, compile=False)
        print("Model loaded")

        with open(os.path.join(SCRIPT_DIR, 'label_encoders.pkl'), 'rb') as f:
            label_encoders = pickle.load(f)

        with open(os.path.join(SCRIPT_DIR, 'all_categories.pkl'), 'rb') as f:
            all_categories = pickle.load(f)

        with open(os.path.join(SCRIPT_DIR, 'model_config.json'), 'r') as f:
            model_config = json.load(f)

        # Display R-squared from config — check nested 'metrics' dict (v4.0)
        # and flat keys (v3.0) for backward compatibility
        r2_value = None
        if 'metrics' in model_config and isinstance(model_config['metrics'], dict):
            r2_value = model_config['metrics'].get('test_r2_score')
        if r2_value is None:
            for key in ['test_r2_score', 'test_r_squared', 'r_squared', 'r2_score']:
                if key in model_config:
                    r2_value = model_config[key]
                    break

        if r2_value is not None:
            print(f"R-squared: {r2_value:.4f}")
        else:
            print("R-squared: Not available in config")

        print()  # Add empty line for better formatting

        return model, label_encoders, all_categories, model_config

    except FileNotFoundError as e:
        print(f"ERROR: Required file not found: {e}")
        return None, None, None, None
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return None, None, None, None


def get_landmark_data():
    """Load unique landmarks from the training dataset.

    Returns:
        DataFrame of unique landmarks, or None on error
    """
    try:
        file_path = os.path.join(SCRIPT_DIR, 'synthetic_user_landmarks.csv')

        # Only read the columns we need — much faster for large CSVs
        df = pd.read_csv(
            file_path, encoding='utf-8',
            usecols=['landmark_name', 'landmark_category', 'landmark_budget',
                     'landmark_rate', 'landmark_Suitable_Travel_Type'],
        )
        unique_landmarks = df.drop_duplicates()
        del df

        return unique_landmarks

    except FileNotFoundError as e:
        print(f"ERROR: Dataset file not found: {e}")
        return None
    except Exception as e:
        print(f"ERROR: {str(e)}")
        return None


def validate_plan_input(user_input: Dict[str, Any]):
    """Validate plan_type and trip_days requirements."""
    plan_type = user_input.get('plan_type', 'DayPlan')
    if plan_type not in ['DayPlan', 'TripPlan']:
        raise ValueError(f"Invalid plan_type '{plan_type}'. Accepted: 'DayPlan', 'TripPlan'")
    
    if plan_type == 'TripPlan':
        trip_days = user_input.get('trip_days')
        if not isinstance(trip_days, int) or not (1 <= trip_days <= 14):
            raise ValueError(f"trip_days must be an integer between 1 and 14 for TripPlan. Got: {trip_days}")

class RecommendationEngine:
    def __init__(self, model, all_categories, unique_landmarks):
        self.model = model
        self.all_categories = all_categories
        self.unique_landmarks = unique_landmarks
        self.log_file = os.path.join(SCRIPT_DIR, 'real_user_interactions.csv')

    def _build_affinity_from_history(self, user_preferences, interaction_history):
        """Build a real affinity dictionary from survey preferences
        updated with actual user like/dislike behavioral history.

        Args:
            user_preferences:  list of category strings from user survey
            interaction_history: list of dicts, each containing
                                 'category' and 'affinity_signal'

        Returns:
            dict mapping each category to an affinity float (0.05 - 1.0)
        """
        # Step 1: Build base affinity from survey preferences
        affinity = {}
        for cat in ALL_CATEGORIES:
            if cat in user_preferences:
                idx = user_preferences.index(cat)
                affinity[cat] = max(0.4, 0.8 - (0.1 * idx))
            else:
                affinity[cat] = 0.05

        # Step 2: Update with real behavioral history
        for interaction in interaction_history:
            category = interaction.get('category', '')
            signal = float(interaction.get('affinity_signal', 0.0))
            if category in affinity:
                affinity[category] += signal

        # Step 3: Clip all values to 0.05-1.0
        # Minimum 0.05 so disliked categories never fully disappear
        for cat in affinity:
            affinity[cat] = float(np.clip(affinity[cat], 0.05, 1.0))

        return affinity

    def _get_popularity_score(self, landmark_info: Dict[str, Any]) -> float:
        """Normalized popularity based on actual ratings + deterministic hash variety.
        Ensures landmarks with similar budgets/ratings don't have massive arbitrary spreads.
        """
        import hashlib
        name = landmark_info['name']
        rating = landmark_info['rating']
        
        # Foundation: Normalized Rating (0.0 to 1.0)
        rating_base = (rating - RATING_MIN) / (RATING_MAX - RATING_MIN)
        
        # Variety: Deterministic hash (0% to 20% influence)
        h = int(hashlib.md5(str(name).encode('utf-8')).hexdigest()[:8], 16)
        hash_noise = (h / 0xffffffff) * 0.2
        
        return np.clip(rating_base * 0.8 + hash_noise, 0.0, 1.0)

    def get_recommendations(self, user_input, user_id="anonymous",
                            interaction_count=0, top_n=10,
                            interaction_history=None):
        print("\n" + "=" * 80)
        print(f"GENERATING {user_input.get('plan_type', 'DayPlan').upper()} (User: {user_id} | Interactions: {interaction_count})")
        print("=" * 80)

        # Apply real interaction history to affinity vector if provided
        if interaction_history is None:
            interaction_history = []

        if interaction_history:
            updated_affinity = self._build_affinity_from_history(
                user_input['user_preferences'],
                interaction_history
            )
            user_input['user_affinity_dict'] = updated_affinity
            
            # Re-order preferences based on behavioral affinity
            # This ensures diversity pulls from categories with higher real-world affinity first
            user_input['user_preferences'] = sorted(
                user_input['user_preferences'],
                key=lambda x: updated_affinity.get(x, 0),
                reverse=True
            )

        # ------------------------------------------------------------------
        # 1. Adaptive Blending (using log-like smoothing)
        # ------------------------------------------------------------------
        k = 20
        dl_weight = interaction_count / (interaction_count + k)
        dl_weight = max(0.2, dl_weight)  # Even cold start gets 20% personal
        pop_weight = 1.0 - dl_weight

        if interaction_count < 5:
            print(f"COLD START ACTIVE: Blending {pop_weight*100:.0f}% Popularity / {dl_weight*100:.0f}% Personalization")
        else:
            print(f"PERSONALIZED ACTIVE: Blending {pop_weight*100:.0f}% Popularity / {dl_weight*100:.0f}% Personalization")

        # 2. Add continuous behavioral metrics
        user_input['interaction_count_norm'] = min(1.0, interaction_count / 50.0)
        user_input['recency_norm'] = 0.0

        # 3. Model Inference
        user_features, user_budget = prepare_user_features_single(user_input, self.all_categories)
        landmark_features, landmark_info_list = prepare_landmark_features_batch(self.unique_landmarks, self.all_categories)

        pred_user_features = np.repeat(user_features, len(landmark_features), axis=0)

        dl_predictions = self.model.predict(
            [pred_user_features, landmark_features],
            verbose=0, batch_size=512
        ).flatten()

        # 4. Normalize DL scores (Ensures scores from both systems are on same scale [0,1])
        dl_min, dl_max = np.min(dl_predictions), np.max(dl_predictions)
        dl_norm = (dl_predictions - dl_min) / (dl_max - dl_min + 1e-8)

        # 5. Blend scores
        combined_results = []
        for i, info in enumerate(landmark_info_list):
            dl_score = float(dl_norm[i])
            pop_score = self._get_popularity_score(info)
            
            # The Magic Blend
            blended_score = (dl_score * dl_weight) + (pop_score * pop_weight)

            combined_results.append({
                **info,
                'dl_score': dl_score,
                'pop_score': pop_score,
                'final_score': blended_score
            })

        # ------------------------------------------------------------------
        # 6. Ranking + Filtering (Fix #1: Secondary Rating Tie-breaker)
        # ------------------------------------------------------------------
        # Sort by final score descending, and use rating as the secondary tie-breaker
        combined_results.sort(key=lambda x: (x['final_score'], x['rating']), reverse=True)

        eligible_budgets = get_eligible_budgets(user_budget)
        
        # Fix #2: Budget-lower capping (Max 2 out of 10)
        matching_budget_recs = [r for r in combined_results if r['budget_lower'] == user_budget]
        lower_budget_recs = [r for r in combined_results if r['budget_lower'] in eligible_budgets and r['budget_lower'] != user_budget]
        
        # Combine matching budget with ONLY up to 2 lower budget options
        # We take a large enough buffer to allow the diversity layer to work
        final_pool = matching_budget_recs + lower_budget_recs[:10] # Buffer for diversity
        
        # Shared diversity logic
        recommendations = get_top_n_diverse_recommendations(final_pool, user_input['user_preferences'], n=top_n+10)

        # Final correction: strictly enforce the 2-lower limit after diversity
        low_count = 0
        limit_lower = 2 if user_input.get('plan_type') == 'DayPlan' else (user_input['trip_days'] * 2)
        
        final_formatted = []
        for r in recommendations:
            if r['budget_lower'] != user_budget:
                if low_count < limit_lower:
                    final_formatted.append(r)
                    low_count += 1
            else:
                final_formatted.append(r)
        
        # Fill/Trim to exactly top_n
        if len(final_formatted) < top_n:
            existing_names = {r['name'] for r in final_formatted}
            for r in matching_budget_recs:
                if r['name'] not in existing_names and len(final_formatted) < top_n:
                    final_formatted.append(r)
                    existing_names.add(r['name'])
        
        final_formatted = final_formatted[:top_n]

        # ------------------------------------------------------------------
        # 8. Output Formatting
        # ------------------------------------------------------------------
        plan_type = user_input.get('plan_type', 'DayPlan')
        
        if plan_type == 'TripPlan':
            days = user_input['trip_days']
            print(f"\nTRIP PLAN — {days} Days | {len(final_formatted)} Landmarks Total")
            print("=" * 80)
            for d in range(days):
                print(f"\nDAY {d+1}:")
                day_recs = final_formatted[d*5:(d+1)*5]
                for j, rec in enumerate(day_recs, 1):
                    idx = (d * 5) + j
                    print(f"{idx:2d}. {rec['name']:<30} (Score: {rec['final_score']:.3f} | Cat: {rec['category']:<15} | Rating: {rec['rating']:.1f})")
        else:
            print("\nTOP 10 PERSONALIZED RECOMMENDATIONS")
            print("-" * 80)
            for i, rec in enumerate(final_formatted, 1):
                budget_flag = "[LOWER BUDGET]" if rec['budget_lower'] != user_budget else ""
                print(f"{i:2d}. {rec['name']} (Score: {rec['final_score']:.3f} | DL: {rec['dl_score']:.3f} | PB: {rec['pop_score']:.3f}) {budget_flag}")
                print(f"    Cat: {rec['category']:<20} Rating: {rec['rating']:.1f}   Budget: {rec['budget']}")

        return final_formatted

    def log_interaction(self, user_id: str, landmark_name: str, event_type: str = "like"):
        """Feedback Loop: Log genuine user behavior to disk for future re-training.

        Args:
            user_id:       The user's unique identifier
            landmark_name: The landmark the user reacted to
            event_type:    'like'    → +0.8 affinity (strong positive signal)
                           'dislike' → -0.3 affinity (negative signal, lowers
                                       category ranking in future visits)

        Signal weights:
            like    = +0.8  strong positive push toward this category
            dislike = -0.3  moderate negative push away from this category
                            (not -0.8 to prevent one accidental dislike
                             destroying a category the user selected in survey)
        """
        # Check if file exists to write headers
        file_exists = os.path.isfile(self.log_file)
        
        # NEW — replace with this
        if event_type == "like":
            affinity_signal = 0.8
        elif event_type == "dislike":
            affinity_signal = -0.3
        else:
            raise ValueError(
                f"Invalid event_type '{event_type}'. Accepted: 'like', 'dislike'"
            )

        import datetime
        timestamp = datetime.datetime.now().isoformat()

        import csv
        with open(self.log_file, 'a', newline='', encoding='utf-8') as f:
            writer = csv.writer(f)
            if not file_exists:
                writer.writerow(['timestamp', 'user_id', 'landmark_name',
                                 'landmark_category', 'event_type', 'affinity_signal'])
            
            # Look up category from landmark database
            landmark_row = self.unique_landmarks[
                self.unique_landmarks['landmark_name'] == landmark_name
            ]
            landmark_category = landmark_row['landmark_category'].values[0] \
                if len(landmark_row) > 0 else 'Unknown'

            writer.writerow([timestamp, user_id, landmark_name,
                             landmark_category, event_type, affinity_signal])
            
        print(f"\n[FEEDBACK LOGGED] User {user_id} "
              f"{'liked' if event_type == 'like' else 'disliked'} "
              f"'{landmark_name}' ({landmark_category}) "
              f"({'+'if affinity_signal > 0 else ''}{affinity_signal} affinity)")

def main():
    """Main inference pipeline."""
    # Test Case 1 — DayPlan, new user, no history:
    user_day = {
        'plan_type': 'DayPlan',
        'user_id': 'U2001',
        'interaction_count': 5,
        'user_age': 25,
        'user_gender': 'Male',
        'user_budget': 'medium',
        'user_travel_type': 'solo',
        'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise']
    }
    history_day = []

    # Test Case 2 — TripPlan 2 days, no history:
    user_trip_2 = {
        'plan_type': 'TripPlan',
        'trip_days': 2,
        'user_id': 'U2002',
        'interaction_count': 0,
        'user_age': 30,
        'user_gender': 'Female',
        'user_budget': 'high',
        'user_travel_type': 'couple',
        'user_preferences': ['Art Gallery', 'Ancient Monument', 'Traditional Restaurant']
    }
    history_trip_2 = []

    # Test Case 3 — TripPlan 3 days, with real like/dislike history:
    user_trip_3 = {
        'plan_type': 'TripPlan',
        'trip_days': 3,
        'user_id': 'U2003',
        'interaction_count': 15,
        'user_age': 22,
        'user_gender': 'Male',
        'user_budget': 'medium',
        'user_travel_type': 'family',
        'user_preferences': ['Museum', 'Pharaonic Site', 'Park / Garden', 'Zoo / Aquarium']
    }
    history_trip_3 = [
        {'category': 'Museum',        'affinity_signal':  0.8},
        {'category': 'Museum',        'affinity_signal':  0.8},
        {'category': 'Park / Garden', 'affinity_signal': -0.3},
        {'category': 'Zoo / Aquarium','affinity_signal':  0.8},
    ]

    # Test Case 4 — Personalization proof, same profile different history:
    # Same profile — User A loves Museums, dislikes Nile Cruise
    user_a = {
        'plan_type': 'DayPlan',
        'user_id': 'U_A',
        'interaction_count': 10,
        'user_age': 28,
        'user_gender': 'Male',
        'user_budget': 'medium',
        'user_travel_type': 'solo',
        'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise']
    }
    history_a = [
        {'category': 'Museum',      'affinity_signal':  0.8},
        {'category': 'Museum',      'affinity_signal':  0.8},
        {'category': 'Nile Cruise', 'affinity_signal': -0.3},
    ]

    # Same profile — User B loves Nile Cruise, dislikes Museums
    user_b = {
        'plan_type': 'DayPlan',
        'user_id': 'U_B',
        'interaction_count': 10,
        'user_age': 28,
        'user_gender': 'Male',
        'user_budget': 'medium',
        'user_travel_type': 'solo',
        'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise']
    }
    history_b = [
        {'category': 'Nile Cruise', 'affinity_signal':  0.8},
        {'category': 'Nile Cruise', 'affinity_signal':  0.8},
        {'category': 'Museum',      'affinity_signal': -0.3},
    ]

    # Load model and artifacts
    model, label_encoders, all_categories, model_config = load_model_and_artifacts()
    if model is None: return

    unique_landmarks = get_landmark_data()
    if unique_landmarks is None: return

    engine = RecommendationEngine(model, all_categories, unique_landmarks)

    # Test 1 — DayPlan
    validate_user_input(user_day)
    validate_plan_input(user_day)
    engine.get_recommendations(
        user_day, user_id='U2001',
        interaction_count=5, top_n=10,
        interaction_history=history_day
    )

    # Test 2 — TripPlan 2 days
    validate_user_input(user_trip_2)
    validate_plan_input(user_trip_2)
    engine.get_recommendations(
        user_trip_2, user_id='U2002',
        interaction_count=0, top_n=10,
        interaction_history=history_trip_2
    )

    # Test 3 — TripPlan 3 days with history
    validate_user_input(user_trip_3)
    validate_plan_input(user_trip_3)
    engine.get_recommendations(
        user_trip_3, user_id='U2003',
        interaction_count=15, top_n=15,
        interaction_history=history_trip_3
    )

    # Test 4 — Personalization proof
    print("\n" + "=" * 80)
    print("--- TEST 4A: User who likes Museums, dislikes Nile Cruise ---")
    recs_a = engine.get_recommendations(
        user_a, user_id='U_A',
        interaction_count=10, top_n=10,
        interaction_history=history_a
    )

    print("\n--- TEST 4B: User who likes Nile Cruise, dislikes Museums ---")
    recs_b = engine.get_recommendations(
        user_b, user_id='U_B',
        interaction_count=10, top_n=10,
        interaction_history=history_b
    )

    # Verification
    print("\n" + "=" * 80)
    print("PERSONALIZATION VERIFICATION")
    print("=" * 80)
    top3_a = [r['name'] for r in recs_a[:3]]
    top3_b = [r['name'] for r in recs_b[:3]]
    print(f"User A top 3 (Museum lover):     {top3_a}")
    print(f"User B top 3 (Nile Cruise lover): {top3_b}")
    if top3_a != top3_b:
        print("PASS: Real personalization working -- different users get different results")
    else:
        print("WARN: Top 3 identical -- personalization signal may be too weak")

    # Feedback simulation
    print("\n--- FEEDBACK SIMULATION ---")
    engine.log_interaction('U2003', recs_a[0]['name'], event_type='like')
    engine.log_interaction('U2003', recs_a[1]['name'], event_type='dislike')


if __name__ == "__main__":
    main()