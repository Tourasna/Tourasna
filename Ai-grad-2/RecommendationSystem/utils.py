# utils.py — Shared Utilities for Travel Recommendation System
# ============================================================================
# Version: 2.0 (Refactored)
#
# Contains common constants, parsing helpers, feature engineering functions,
# scoring logic, and recommendation selection used by both training and
# inference scripts.
#
# Changes from v1.0:
#   - Added lru_cache to parse_list_string / normalize_budget (~100x faster
#     on repeated calls, critical for 5M-row datasets)
#   - Extracted magic numbers to named constants (AGE_MIN/MAX, RATING_MIN/MAX)
#   - Added validate_user_input() for shared input validation
#   - Added __all__ for explicit public API
#   - Ensured consistent float32 dtypes throughout
#   - Reorganized into clearly delimited sections
#
# Sections:
#   1. Constants & Configuration
#   2. Parsing & Normalization Utilities (cached)
#   3. Input Validation
#   4. Feature Engineering (single-sample & batch)
#   5. Scoring & Recommendation Selection
# ============================================================================

from __future__ import annotations

import ast
import functools
import logging
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Public API — every symbol listed here is safe to import in other modules.
# ---------------------------------------------------------------------------
__all__ = [
    # Constants
    'ALL_CATEGORIES', 'TRAVEL_TYPES', 'BUDGET_LEVELS',
    'AGE_MIN', 'AGE_MAX', 'RATING_MIN', 'RATING_MAX',
    'FEATURE_DIMS',
    # Parsing & normalization
    'parse_list_string', 'normalize_budget', 'encode_user_preferences',
    # Validation
    'validate_user_input',
    # Feature engineering
    'prepare_user_features_single', 'prepare_landmark_features_batch',
    # Scoring & recommendations
    'get_eligible_budgets', 'calculate_landmark_score',
    'get_top_10_diverse_recommendations',
]


# ============================================================================
# 1. CONSTANTS & CONFIGURATION
# ============================================================================

ALL_CATEGORIES: List[str] = [
    'Activity', 'Ancient Monument', 'Antiques', 'Art Gallery',
    'Bazaar / Souq', 'Coptic Site', 'Cultural Center', 'Day Trip Site',
    'Escape Room', 'Food Tour', 'Gold & Jewelry Market', 'Horse Riding',
    'Islamic Monument', 'Landmark', 'Museum', 'Nature Reserve',
    'Nile Cruise', 'Nile View Restaurant', 'Park / Garden',
    'Pharaonic Site', 'Rooftop Restaurant', 'Shopping Mall',
    'Souvenir Shop', 'Sport & Recreation', 'Theme Park',
    'Traditional Restaurant', 'Zoo / Aquarium',
]

TRAVEL_TYPES: List[str] = ['family', 'couple', 'solo', 'luxury']
BUDGET_LEVELS: List[str] = ['low', 'medium', 'high']

# Normalization bounds — used consistently across training and inference
# to guarantee feature alignment.
AGE_MIN: int = 18
AGE_MAX: int = 75
RATING_MIN: float = 1.0
RATING_MAX: float = 5.0

# Pre-computed set for O(1) category lookups
_CATEGORY_SET: frozenset = frozenset(ALL_CATEGORIES)
_CATEGORY_LOWER_SET: frozenset = frozenset(c.lower() for c in ALL_CATEGORIES)

# Expected feature dimensions — kept in sync with feature-engineering funcs.
# user  = 1 (age) + 2 (gender) + 3 (budget) + len(TRAVEL_TYPES) + len(ALL_CATEGORIES)
# landmark = len(ALL_CATEGORIES) + 3 (budget) + 1 (rating)
FEATURE_DIMS: Dict[str, int] = {
    'user': 39,  # age(1) + gen(2) + bud(3) + travel(4) + int(1) + rec(1) + prefs(27)
    'landmark': 31,
    'total': 70, # 39 + 31
}


# ============================================================================
# 2. PARSING & NORMALIZATION UTILITIES (cached)
# ============================================================================

@functools.lru_cache(maxsize=16384)
def _parse_str_cached(s: str) -> Tuple[str, ...]:
    """Parse a string representation of a list — cached, returns immutable tuple.

    Internal helper.  The public ``parse_list_string`` wraps this to handle
    non-hashable / non-string inputs and returns a mutable list.
    """
    stripped = s.strip()
    if stripped.startswith('[') and stripped.endswith(']'):
        try:
            parsed = ast.literal_eval(stripped)
            if isinstance(parsed, list):
                return tuple(str(item) for item in parsed)
        except (ValueError, SyntaxError):
            # Fallback: manual comma-split for malformed list literals
            inner = stripped[1:-1].replace('"', '').replace("'", "")
            return tuple(item.strip() for item in inner.split(',') if item.strip())
    elif stripped:
        return (stripped,)
    return ()


def parse_list_string(list_str: Any) -> List[str]:
    """Parse a string representation of a list into an actual Python list.

    Handles multiple formats:
    - Python list strings: ``"['a', 'b']"``
    - Plain strings: ``"a"``
    - Already-parsed lists
    - NaN / None values

    Internally cached via ``_parse_str_cached`` — repeated values (very common
    in large datasets) hit the cache and avoid redundant parsing.

    Returns:
        List of strings (empty list on unparseable input).
    """
    # Fast path: None
    if list_str is None:
        return []

    # Check for pandas NaN
    try:
        if pd.isna(list_str):
            return []
    except (TypeError, ValueError):
        # pd.isna raises TypeError for certain non-scalar inputs
        pass

    # Already a list — return as-is
    if isinstance(list_str, list):
        return list_str

    # String → cached parse → convert tuple back to list
    if isinstance(list_str, str):
        return list(_parse_str_cached(list_str))

    return []


@functools.lru_cache(maxsize=64)
def normalize_budget(budget_str: Any) -> str:
    """Normalize a budget value to one of: ``'low'``, ``'medium'``, ``'high'``.

    Handles variations like ``'Low Budget'``, ``'MEDIUM'``, ``'high-end'``, etc.
    Defaults to ``'medium'`` for unrecognised values.

    Cached — there are typically ≤6 unique budget strings in any dataset,
    so every call after the first few is a dict lookup.
    """
    budget_lower = str(budget_str).lower().strip()
    if 'low' in budget_lower:
        return 'low'
    if 'high' in budget_lower:
        return 'high'
    if 'medium' in budget_lower or 'med' in budget_lower:
        return 'medium'
    return 'medium'  # safe default


def encode_user_preferences(
    pref_str: Any,
    categories: Optional[List[str]] = None,
) -> List[int]:
    """Encode user preferences as a binary vector over *categories*.

    Uses **case-insensitive** matching so ``'museum'`` matches ``'Museum'``.
    """
    if categories is None:
        categories = ALL_CATEGORIES
    pref_list = parse_list_string(pref_str)
    # Build a lowercase set for O(1) case-insensitive lookup
    pref_lower = {p.lower() for p in pref_list}
    return [1 if cat.lower() in pref_lower else 0 for cat in categories]


# ============================================================================
# 3. INPUT VALIDATION
# ============================================================================

def validate_user_input(user_input: Dict[str, Any]) -> None:
    """Validate a user-input dict for inference or scoring.

    Checks for required keys, value ranges, and known categories.
    Logs warnings for soft issues; raises ``ValueError`` for hard failures.
    """
    required_keys = [
        'user_age', 'user_gender', 'user_budget',
        'user_travel_type', 'user_preferences',
    ]
    missing = [k for k in required_keys if k not in user_input]
    if missing:
        raise ValueError(f"Missing required key(s): {missing}")

    # Age range check (advisory — will be clipped during normalization)
    age = int(user_input['user_age'])
    if not (AGE_MIN <= age <= AGE_MAX):
        logger.warning(
            "Age %d outside expected range [%d, %d]; "
            "it will be clipped during feature normalization.",
            age, AGE_MIN, AGE_MAX,
        )

    # Gender check
    gender = str(user_input['user_gender']).strip().lower()
    if gender not in ('male', 'female'):
        logger.warning("Unknown gender '%s' — will be treated as non-male.", gender)

    # Budget check
    budget = normalize_budget(user_input['user_budget'])
    if budget not in BUDGET_LEVELS:
        logger.warning("Unrecognised budget '%s' — defaulting to 'medium'.", user_input['user_budget'])

    # Travel type check
    travel = str(user_input['user_travel_type']).lower().strip()
    if travel not in TRAVEL_TYPES:
        logger.warning(
            "Unknown travel type '%s'; valid options: %s",
            user_input['user_travel_type'], TRAVEL_TYPES,
        )

    # Preferences check
    prefs = user_input['user_preferences']
    if isinstance(prefs, str):
        prefs = parse_list_string(prefs)
    if not isinstance(prefs, list) or len(prefs) == 0:
        logger.warning("Empty or invalid preferences list.")
    else:
        unknown = [p for p in prefs if p not in _CATEGORY_SET]
        if unknown:
            logger.warning("Unknown categories in preferences (case-sensitive): %s", unknown)


# ============================================================================
# 4. FEATURE ENGINEERING
# ============================================================================

def prepare_user_features_single(
    user_input: Dict[str, Any],
    categories: Optional[List[str]] = None,
) -> Tuple[np.ndarray, str]:
    """Prepare a feature vector for a **single** user profile (inference time).

    Feature order (must match training-time ``engineer_user_features``):
        [age_norm, gender_male, gender_female,
         budget_low, budget_medium, budget_high,
         travel_family, travel_couple, travel_solo, travel_luxury,
         interaction_count_norm, recency_norm,
         pref_cat_0, pref_cat_1, ..., pref_cat_N]

    Returns:
        (np.ndarray of shape ``(1, FEATURE_DIMS['user'])``, normalised budget string)
    """
    if categories is None:
        categories = ALL_CATEGORIES

    features: List[float] = []

    # Age — normalised to [0, 1] using shared constants
    age_norm = (float(user_input['user_age']) - AGE_MIN) / (AGE_MAX - AGE_MIN)
    features.append(np.clip(age_norm, 0.0, 1.0))

    # Gender — one-hot [male, female]
    is_male = 1.0 if str(user_input['user_gender']).lower() == 'male' else 0.0
    features.extend([is_male, 1.0 - is_male])

    # Budget — one-hot [low, medium, high]
    budget_lower = normalize_budget(user_input['user_budget'])
    budget_onehot = [0.0, 0.0, 0.0]
    try:
        budget_onehot[BUDGET_LEVELS.index(budget_lower)] = 1.0
    except ValueError:
        budget_onehot[1] = 1.0          # default medium
        budget_lower = 'medium'
    features.extend(budget_onehot)

    # Travel type — one-hot [family, couple, solo, luxury]
    travel_lower = str(user_input['user_travel_type']).lower()
    travel_onehot = [0.0] * len(TRAVEL_TYPES)
    try:
        travel_onehot[TRAVEL_TYPES.index(travel_lower)] = 1.0
    except ValueError:
        logger.warning("Unknown travel type: %s", user_input['user_travel_type'])
    features.extend(travel_onehot)

    # Implicit behavioral traits: interaction count & recency
    # Assume 0.5 (average) if not provided by the inference endpoint
    int_count = float(user_input.get('interaction_count_norm', 0.5))
    recency = float(user_input.get('recency_norm', 0.5))
    features.extend([np.clip(int_count, 0.0, 1.0), np.clip(recency, 0.0, 1.0)])

    # Affinity Vector (27 dimensions)
    # If explicit continuous affinities are provided (e.g. from a real user profile db)
    if 'user_affinity_dict' in user_input and isinstance(user_input['user_affinity_dict'], dict):
        affinity_dict = {str(k).lower(): float(v) for k, v in user_input['user_affinity_dict'].items()}
        prefs_vector = [affinity_dict.get(cat.lower(), 0.05) for cat in categories]
    else:
        # Fallback: estimate continuous affinities from explicit strings
        pref_str = user_input.get('user_preferences', '')
        parsed = [str(p).lower() for p in parse_list_string(pref_str)]
        prefs_vector = []
        for cat in categories:
            cat_lower = cat.lower()
            if cat_lower in parsed:
                idx = parsed.index(cat_lower)
                prefs_vector.append(max(0.4, 0.8 - (0.1 * idx)))
            else:
                prefs_vector.append(0.05)
                
    features.extend(prefs_vector)

    return np.array([features], dtype=np.float32), budget_lower


def prepare_landmark_features_batch(
    unique_landmarks: pd.DataFrame,
    categories: Optional[List[str]] = None,
) -> Tuple[np.ndarray, List[Dict[str, Any]]]:
    """Prepare feature vectors for all landmarks — **vectorised**.

    Feature order (must match training-time ``engineer_landmark_features``):
        [cat_onehot_0, ..., cat_onehot_N,
         budget_low, budget_medium, budget_high,
         rating_norm]

    Returns:
        (np.ndarray of shape ``(n_landmarks, FEATURE_DIMS['landmark'])``,
         list of landmark info dicts for display)
    """
    if categories is None:
        categories = ALL_CATEGORIES

    n = len(unique_landmarks)

    # --- Category one-hot (vectorised) ---
    category_matrix = np.zeros((n, len(categories)), dtype=np.float32)
    cat_values = unique_landmarks['landmark_category'].values
    for i, cat in enumerate(categories):
        category_matrix[:, i] = (cat_values == cat).astype(np.float32)

    # --- Budget one-hot (vectorised via pre-mapped dict) ---
    unique_budgets = unique_landmarks['landmark_budget'].unique()
    budget_map = {b: normalize_budget(b) for b in unique_budgets}
    budget_norm = unique_landmarks['landmark_budget'].map(budget_map)

    budget_matrix = np.zeros((n, 3), dtype=np.float32)
    for i, level in enumerate(BUDGET_LEVELS):
        budget_matrix[:, i] = (budget_norm.values == level).astype(np.float32)

    # --- Rating normalised to [0, 1] using shared constants ---
    rating_norm = np.clip(
        (unique_landmarks['landmark_rate'].astype(float).values - RATING_MIN)
        / (RATING_MAX - RATING_MIN),
        0.0, 1.0
    ).reshape(-1, 1).astype(np.float32)

    # Stack into final feature matrix
    landmark_features = np.hstack([category_matrix, budget_matrix, rating_norm])

    # --- Build info dicts (still need per-row travel-type parsing) ---
    landmark_info_list: List[Dict[str, Any]] = []
    travel_col = unique_landmarks['landmark_Suitable_Travel_Type'].values
    name_col = unique_landmarks['landmark_name'].values
    rate_col = unique_landmarks['landmark_rate'].values
    budget_raw_col = unique_landmarks['landmark_budget'].values
    budget_norm_col = budget_norm.values

    for idx in range(n):
        raw_travel = travel_col[idx]
        travel_types = parse_list_string(raw_travel) if pd.notna(raw_travel) else []
        landmark_info_list.append({
            'name': name_col[idx],
            'category': cat_values[idx],
            'rating': float(rate_col[idx]),
            'budget': budget_raw_col[idx],
            'budget_lower': budget_norm_col[idx],
            'travel_types': travel_types,
            'travel_types_lower': [str(t).lower() for t in travel_types] if travel_types else [],
        })

    return landmark_features, landmark_info_list


# ============================================================================
# 5. SCORING & RECOMMENDATION SELECTION
# ============================================================================

def get_eligible_budgets(user_budget: str) -> List[str]:
    """Return budget levels the user can afford (their level and below).

    - low    → ['low']
    - medium → ['low', 'medium']
    - high   → ['low', 'medium', 'high']

    Returns a **new list** each time (safe to mutate).
    """
    hierarchy = {
        'low': ['low'],
        'medium': ['low', 'medium'],
        'high': list(BUDGET_LEVELS),        # copy to avoid mutating constant
    }
    return hierarchy.get(user_budget.lower(), list(BUDGET_LEVELS))


def calculate_landmark_score(
    landmark: Dict[str, Any],
    user_input: Dict[str, Any],
) -> int:
    """Calculate a rule-based matching score between a landmark and user prefs.

    Scoring breakdown (max 100):
    - Budget match:              30 pts
    - Travel-type match:         30 pts
    - Category in preferences:   40 pts
    """
    score = 0

    # Budget match — 30 pts
    landmark_budget = normalize_budget(landmark.get('landmark_budget', ''))
    user_budget = normalize_budget(user_input['user_budget'])
    if landmark_budget == user_budget:
        score += 30

    # Travel-type match — 30 pts
    travel_types = parse_list_string(landmark.get('landmark_Suitable_Travel_Type', ''))
    travel_lower = {str(t).lower().strip() for t in travel_types}
    if str(user_input['user_travel_type']).lower() in travel_lower:
        score += 30

    # Category preference match — 40 pts (case-insensitive)
    landmark_cat_lower = str(landmark.get('landmark_category', '')).strip().lower()
    user_pref_lower = {p.strip().lower() for p in user_input['user_preferences']}
    if landmark_cat_lower in user_pref_lower:
        score += 40

    return score


def get_top_n_diverse_recommendations(
    recommendations: List[Dict[str, Any]],
    user_preferences: List[str],
    n: int = 10,
) -> List[Dict[str, Any]]:
    """Select top-n diverse recommendations prioritising user-preferred categories.

    Strategy:
      1. Take up to 3 from each preferred category (highest-scored first)
      2. Fill remaining slots from any preferred-category landmarks
      3. Fall back to non-preferred categories only as a last resort

    Args:
        recommendations: list of landmark dicts, each must have 'category',
                         'name', and a score key ('dl_score' or 'score').
        user_preferences: list of category strings the user likes.
        n: Total number of results to return.

    Returns:
        List of up to n landmark dicts.
    """
    user_pref_lower = [p.lower() for p in user_preferences]

    # Bucket landmarks by preference match
    preference_landmarks: Dict[str, list] = {pref: [] for pref in user_pref_lower}
    other_landmarks: List[Dict[str, Any]] = []

    for landmark in recommendations:
        cat_lower = landmark['category'].lower()
        if cat_lower in preference_landmarks:
            preference_landmarks[cat_lower].append(landmark)
        else:
            other_landmarks.append(landmark)

    top: List[Dict[str, Any]] = []
    selected_names: set = set()

    # Phase 1: up to 3 per preferred category
    for pref in user_pref_lower:
        taken = 0
        for lm in preference_landmarks.get(pref, []):
            if lm['name'] not in selected_names and taken < 3 and len(top) < n:
                top.append(lm)
                selected_names.add(lm['name'])
                taken += 1

    # Phase 2: remaining preferred-category landmarks by score
    if len(top) < n:
        remaining_pref = [
            lm
            for pref in user_pref_lower
            for lm in preference_landmarks.get(pref, [])
            if lm['name'] not in selected_names
        ]
        remaining_pref.sort(
            key=lambda x: x.get('dl_score', x.get('score', 0)), reverse=True
        )
        for lm in remaining_pref:
            if len(top) >= n:
                break
            top.append(lm)
            selected_names.add(lm['name'])

    # Phase 3: non-preferred categories
    if len(top) < n:
        other_landmarks.sort(
            key=lambda x: x.get('dl_score', x.get('score', 0)), reverse=True
        )
        for lm in other_landmarks:
            if len(top) >= n:
                break
            if lm['name'] not in selected_names:
                top.append(lm)
                selected_names.add(lm['name'])

    return top
