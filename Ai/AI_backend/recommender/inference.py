# recommender/inference.py

import numpy as np
import tensorflow as tf
import pickle
import json
import os

# ---------------- LOAD ARTIFACTS ONCE ---------------- #

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
MODEL_DIR = os.path.join(BASE_DIR, "model")

model = tf.keras.models.load_model(
    os.path.join(MODEL_DIR, "travel_recommendation_model.keras")
)

with open(os.path.join(MODEL_DIR, "all_categories.pkl"), "rb") as f:
    ALL_CATEGORIES = pickle.load(f)

# ---------------- FEATURE HELPERS ---------------- #

def normalize_age(age: int) -> float:
    return (age - 18) / (75 - 18)

def one_hot(value, allowed):
    vec = [0] * len(allowed)
    if value in allowed:
        vec[allowed.index(value)] = 1
    return vec

def prepare_user_features(payload):
    features = []

    # age
    features.append(normalize_age(payload["age"]))

    # gender
    features.extend(one_hot(payload["gender"], ["male", "female"]))

    # budget
    features.extend(one_hot(payload["budget"], ["low", "medium", "high"]))

    # travel type
    features.extend(one_hot(
        payload["travel_type"],
        ["family", "couple", "solo", "luxury"]
    ))

    # preferences
    prefs = set(payload["preferences"])
    pref_vector = [1 if cat in prefs else 0 for cat in ALL_CATEGORIES]
    features.extend(pref_vector)

    return np.array(features)

def prepare_landmark_features(landmark):
    features = []

    # category one-hot
    cat_vec = [0] * len(ALL_CATEGORIES)
    if landmark["category"] in ALL_CATEGORIES:
        cat_vec[ALL_CATEGORIES.index(landmark["category"])] = 1
    features.extend(cat_vec)

    # budget
    features.extend(one_hot(
        landmark["budget"],
        ["low", "medium", "high"]
    ))

    # rating normalized
    features.append((landmark["rating"] - 1) / 4)

    return np.array(features)

# ---------------- MAIN INFERENCE ---------------- #

def recommend(payload: dict) -> dict:
    user_vec = prepare_user_features(payload)

    scores = []

    for lm in payload["landmarks"]:
        lm_vec = prepare_landmark_features(lm)

        user_batch = np.expand_dims(user_vec, axis=0)
        lm_batch = np.expand_dims(lm_vec, axis=0)

        score = model.predict(
            [user_batch, lm_batch],
            verbose=0
        )[0][0]

        scores.append((lm["id"], score))

    scores.sort(key=lambda x: x[1], reverse=True)

    top_ids = [lm_id for lm_id, _ in scores[:10]]

    return {
        "place_ids": top_ids
    }
