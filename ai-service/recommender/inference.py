import numpy as np
import ast
import pandas as pd

from .model_loader import load_model
from .data_loader import load_landmarks


# -------------------------
# Helpers
# -------------------------

def parse_list_string(value):
    if pd.isna(value):
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, str):
        try:
            return ast.literal_eval(value)
        except:
            return [v.strip() for v in value.strip("[]").split(",")]
    return []


# -------------------------
# Feature preparation
# -------------------------

def prepare_user_features(user_input, all_categories):
    features = []

    # Age (normalized)
    age_norm = (user_input["user_age"] - 18) / (75 - 18)
    features.append(age_norm)

    # Gender
    features.extend(
        [1, 0] if user_input["user_gender"].lower() == "male" else [0, 1]
    )

    # Budget
    budget = user_input["user_budget"].lower()
    features.extend([
        1 if budget == "low" else 0,
        1 if budget == "medium" else 0,
        1 if budget == "high" else 0,
    ])

    # Travel type
    travel_types = ["family", "couple", "solo", "luxury"]
    travel_vec = [0] * 4
    if user_input["user_travel_type"].lower() in travel_types:
        travel_vec[
            travel_types.index(user_input["user_travel_type"].lower())
        ] = 1
    features.extend(travel_vec)

    # Preferences
    pref_vec = [
        1 if c in user_input["user_preferences"] else 0
        for c in all_categories
    ]
    features.extend(pref_vec)

    return np.array([features]), budget


def prepare_landmark_features(df, all_categories):
    features = []
    meta = []

    for _, lm in df.iterrows():
        row = []

        # Category one-hot
        cat_vec = [0] * len(all_categories)
        if lm["landmark_category"] in all_categories:
            cat_vec[
                all_categories.index(lm["landmark_category"])
            ] = 1
        row.extend(cat_vec)

        # Budget
        budget_raw = str(lm["landmark_budget"]).lower()
        if "low" in budget_raw:
            row.extend([1, 0, 0])
            budget_label = "low"
        elif "medium" in budget_raw:
            row.extend([0, 1, 0])
            budget_label = "medium"
        else:
            row.extend([0, 0, 1])
            budget_label = "high"

        # Rating (normalized)
        rating_norm = (float(lm["landmark_rate"]) - 1) / 4
        row.append(rating_norm)

        features.append(row)

        meta.append({
            "name": lm["landmark_name"],
            "category": lm["landmark_category"],
            "budget": budget_label,
        })

    return np.array(features), meta


# -------------------------
# Recommendation logic
# -------------------------

def get_eligible_budgets(user_budget):
    if user_budget == "low":
        return ["low"]
    if user_budget == "medium":
        return ["low", "medium"]
    return ["low", "medium", "high"]


# -------------------------
# Diversity logic (OPTION A)
# -------------------------

def diversify(results, user_preferences, limit=10, per_category=3):
    final = []
    counts = {}

    prefs = set(p.lower() for p in user_preferences)

    # 1️⃣ Prefer user categories first
    for r in results:
        cat = r["category"].lower()
        if cat not in prefs:
            continue

        counts.setdefault(cat, 0)
        if counts[cat] < per_category:
            final.append(r)
            counts[cat] += 1

        if len(final) == limit:
            return final

    # 2️⃣ Fill remaining slots
    for r in results:
        cat = r["category"].lower()
        counts.setdefault(cat, 0)

        if counts[cat] < per_category:
            final.append(r)
            counts[cat] += 1

        if len(final) == limit:
            break

    return final


def recommend(user_input: dict):
    model, all_categories = load_model()
    landmarks = load_landmarks()

    user_vec, user_budget = prepare_user_features(user_input, all_categories)
    lm_vec, lm_meta = prepare_landmark_features(landmarks, all_categories)

    user_vec = np.repeat(user_vec, len(lm_vec), axis=0)

    scores = model.predict(
        [user_vec, lm_vec],
        batch_size=128
    ).flatten()

    results = []
    for i, lm in enumerate(lm_meta):
        if lm["budget"] not in get_eligible_budgets(user_budget):
            continue

        results.append({
            "name": lm["name"],
            "category": lm["category"],
            "budget": lm["budget"],
            "score": float(scores[i]),
        })

    results.sort(key=lambda x: x["score"], reverse=True)

    return diversify(results, user_input["user_preferences"])
