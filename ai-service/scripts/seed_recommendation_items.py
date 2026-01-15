import pandas as pd
import json
import mysql.connector
import os

# ─────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CSV_PATH = os.path.join(BASE_DIR, "assets", "landmarks.csv")

# ─────────────────────────────────────────────
# DB Config
# ─────────────────────────────────────────────

DB_CONFIG = {
    "host": "localhost",
    "user": "tourasna",
    "password": "strongpassword",
    "database": "tourasna",
    "auth_plugin": "mysql_native_password",
}

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

def parse_list(val):
    """
    Convert stringified list to Python list.
    Example: '["solo","family"]' → ["solo","family"]
    """
    try:
        if isinstance(val, str):
            return json.loads(val.replace("'", '"'))
        return []
    except Exception:
        return []


def normalize_budget(budget: str) -> str:
    b = budget.lower()
    if "low" in b:
        return "low"
    if "medium" in b:
        return "medium"
    return "high"

# ─────────────────────────────────────────────
# Load CSV
# ─────────────────────────────────────────────

df = pd.read_csv(CSV_PATH)

# Keep ONLY landmark columns used by inference.py
df = df[
    [
        "landmark_name",
        "landmark_category",
        "landmark_rate",
        "landmark_budget",
        "landmark_Suitable_Travel_Type",
    ]
]

# Deduplicate by name
df = df.drop_duplicates(subset=["landmark_name"])

print(f"Seeding {len(df)} unique landmarks")

# ─────────────────────────────────────────────
# Connect DB
# ─────────────────────────────────────────────

conn = mysql.connector.connect(**DB_CONFIG)
cursor = conn.cursor()

# ─────────────────────────────────────────────
# Insert SQL (NO id column)
# ─────────────────────────────────────────────

sql = """
INSERT INTO recommendation_items
(name, category, budget, rating, travel_types)
VALUES (%s, %s, %s, %s, %s)
ON DUPLICATE KEY UPDATE
  category = VALUES(category),
  budget = VALUES(budget),
  rating = VALUES(rating),
  travel_types = VALUES(travel_types)
"""

# ─────────────────────────────────────────────
# Insert rows
# ─────────────────────────────────────────────

for _, row in df.iterrows():
    cursor.execute(
        sql,
        (
            row["landmark_name"],
            row["landmark_category"],
            normalize_budget(row["landmark_budget"]),
            float(row["landmark_rate"]),
            json.dumps(parse_list(row["landmark_Suitable_Travel_Type"])),
        ),
    )

conn.commit()
cursor.close()
conn.close()

print("✅ recommendation_items seeded successfully")
