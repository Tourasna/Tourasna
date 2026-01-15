# recommender/model_loader.py
import pickle
import json
from tensorflow import keras

MODEL = None
ALL_CATEGORIES = None

def load_model():
    global MODEL, ALL_CATEGORIES

    if MODEL is not None:
        return MODEL, ALL_CATEGORIES

    MODEL = keras.models.load_model(
        "assets/travel_recommendation_model.keras"
    )

    with open("assets/all_categories.pkl", "rb") as f:
        ALL_CATEGORIES = pickle.load(f)

    return MODEL, ALL_CATEGORIES
