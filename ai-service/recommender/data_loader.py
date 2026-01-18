# recommender/data_loader.py
import pandas as pd

LANDMARKS = None

def load_landmarks():
    global LANDMARKS

    if LANDMARKS is not None:
        return LANDMARKS

    df = pd.read_csv("assets/landmarks.csv")

    LANDMARKS = df[
        [
            "landmark_name",
            "landmark_category",
            "landmark_budget",
            "landmark_rate",
            "landmark_Suitable_Travel_Type"
        ]
    ].drop_duplicates()

    return LANDMARKS
