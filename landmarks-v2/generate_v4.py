"""
generate_v4.py — Synthetic user–landmark dataset (5,000,000 rows)
=================================================================
Best-of-all-versions: combines fixes from v1, v2, and v3.

Key features:
  ✓ Fully vectorised landmark sampling (np.unique grouping, ~81 groups)    [from v3]
  ✓ Fully vectorised preference string building (no row-level loop)        [from v2]
  ✓ Raw category indices passed directly — no string parsing               [from v2/v3]
  ✓ Gender added to preference weight matrix (×1.8/×1.6 multipliers)       [from v3]
  ✓ 52 nationalities with matched probabilities + assertion guard          [from v2]
  ✓ Dead cat_idx column removed                                            [from v2]
  ✓ Per-chunk timing with rate + ETA using perf_counter                    [from v3]
  ✓ Post-generation validation (memory-safe, sample-based)                 [combined]
  ✓ Configurable paths, seed, chunk size                                   [from v2]
  ✓ Type hints on all functions                                            [from v3]

Output columns:
  user_id, user_age, user_gender, user_nationality, user_budget,
  user_travel_type, user_preferences, landmark_name, landmark_category,
  landmark_rate, landmark_budget, landmark_Suitable_Travel_Type
"""

import time
import numpy as np
import pandas as pd

# ─────────────────────────────────────────────────────────────────────────────
# 0.  Configuration
# ─────────────────────────────────────────────────────────────────────────────
INPUT_CSV  = "data_with_price_categories.csv"
OUTPUT_CSV = "synthetic_user_landmarks.csv"
N_ROWS     = 5_000_000
CHUNK      = 500_000        # rows per chunk — tune for available RAM
SEED       = 42
# NOTE: changing CHUNK with the same seed will produce different output
#       because the RNG state flows sequentially across chunks.

RNG = np.random.default_rng(SEED)

# ─────────────────────────────────────────────────────────────────────────────
# 1.  Load & clean landmark reference data
# ─────────────────────────────────────────────────────────────────────────────
print("Loading landmark data …", flush=True)
lm = pd.read_csv(INPUT_CSV)
lm["price ranges"] = lm["price ranges"].str.strip().str.lower()
lm["Category"]     = lm["Category"].str.strip()
lm = (
    lm[["Name", "Category", "Rating", "price ranges"]]
    .rename(columns={
        "Name":         "landmark_name",
        "Category":     "landmark_category",
        "Rating":       "landmark_rate",
        "price ranges": "landmark_budget",
    })
    .reset_index(drop=True)
)
N_LM = len(lm)
print(f"  → {N_LM} landmarks across {lm['landmark_category'].nunique()} categories.\n",
      flush=True)

# ─────────────────────────────────────────────────────────────────────────────
# 2.  Suitable-travel-type — precomputed per landmark row
# ─────────────────────────────────────────────────────────────────────────────
def suitable(cat: str, bud: str) -> str:
    """Assign suitable travel types per the prompt's category × budget rules."""
    if cat == "Rooftop Restaurant":
        return "['couple', 'luxury']"          if bud == "high" else "['couple', 'family']"
    if cat in ("Landmark", "Traditional Restaurant"):
        return "['solo', 'couple', 'family', 'luxury']"
    if cat in ("Islamic Monument", "Coptic Site", "Cultural Center",
               "Ancient Monument", "Pharaonic Site"):
        return "['solo', 'couple', 'family']"
    if cat in ("Activity", "Zoo / Aquarium", "Nature Reserve"):
        return "['solo', 'couple', 'family']"
    if cat == "Shopping Mall":
        return ("['solo', 'family', 'couple', 'luxury']" if bud == "high"
                else "['solo', 'family', 'couple']")
    if cat == "Park / Garden":
        return ("['solo', 'family', 'couple', 'luxury']" if bud == "high"
                else "['solo', 'family', 'couple']")
    if cat == "Nile View Restaurant":
        return "['couple', 'luxury']"          if bud == "high" else "['couple', 'family']"
    if cat == "Nile Cruise":
        return ("['couple', 'family', 'luxury']" if bud == "high"
                else "['solo', 'couple', 'family']")
    if cat == "Antiques":
        return ("['solo', 'couple', 'family', 'luxury']" if bud == "high"
                else "['solo', 'couple', 'family']")
    if cat == "Theme Park":
        return "['solo', 'family']"
    if cat == "Escape Room":
        return "['couple', 'family']"
    if cat == "Day Trip Site":
        return "['couple', 'family', 'solo']"
    if cat == "Bazaar / Souq":
        return "['solo', 'family']"
    if cat == "Museum":
        return ("['solo', 'couple', 'family', 'luxury']" if bud in ("medium", "high")
                else "['solo', 'couple', 'family']")
    if cat == "Horse Riding":
        return "['family', 'luxury']" if bud == "high" else "['family']"
    if cat == "Art Gallery":
        return "['solo', 'couple', 'luxury']" if bud == "high" else "['solo', 'couple']"
    if cat == "Gold & Jewelry Market":
        return "['couple', 'luxury']" if bud == "high" else "['couple']"
    # Fallback for categories not explicitly listed (Souvenir Shop, Sport & Rec, Food Tour)
    return "['solo', 'couple', 'family']"

lm["landmark_Suitable_Travel_Type"] = lm.apply(
    lambda r: suitable(r["landmark_category"], r["landmark_budget"]), axis=1
)

# ─────────────────────────────────────────────────────────────────────────────
# 3.  Category / budget index structures
# ─────────────────────────────────────────────────────────────────────────────
ALL_CATS = [
    "Activity", "Ancient Monument", "Antiques", "Art Gallery", "Bazaar / Souq",
    "Coptic Site", "Cultural Center", "Day Trip Site", "Escape Room", "Food Tour",
    "Gold & Jewelry Market", "Horse Riding", "Islamic Monument", "Landmark",
    "Museum", "Nature Reserve", "Nile Cruise", "Nile View Restaurant", "Park / Garden",
    "Pharaonic Site", "Rooftop Restaurant", "Shopping Mall", "Souvenir Shop",
    "Sport & Recreation", "Theme Park", "Traditional Restaurant", "Zoo / Aquarium",
]
N_CATS  = len(ALL_CATS)                          # 27
CAT_IDX = {c: i for i, c in enumerate(ALL_CATS)}

BUD_MAP = {"low": 0, "medium": 1, "high": 2}
lm_bud  = lm["landmark_budget"].map(BUD_MAP).fillna(1).to_numpy(dtype=np.int8)
lm_cat  = lm["landmark_category"].map(CAT_IDX).fillna(-1).astype(np.int16).to_numpy()

# Reusable empty-pool sentinel — defined BEFORE any function that uses it
_EMPTY = np.array([], dtype=np.int32)

# Map: (budget_code, cat_idx) → array of landmark row indices
lm_pool: dict[tuple[int, int], np.ndarray] = {}
for _b in (0, 1, 2):
    for _ci in range(N_CATS):
        _mask = (lm_bud == _b) & (lm_cat == _ci)
        lm_pool[(_b, _ci)] = np.where(_mask)[0].astype(np.int32)

# Map: cat_idx → array of landmark row indices (any budget)
lm_pool_cat: dict[int, np.ndarray] = {}
for _ci in range(N_CATS):
    lm_pool_cat[_ci] = np.where(lm_cat == _ci)[0].astype(np.int32)

# ─────────────────────────────────────────────────────────────────────────────
# 4.  User demographic distributions
# ─────────────────────────────────────────────────────────────────────────────
# 52 nationalities with 52 matched probabilities (assertion-guarded)
NAT_NAMES = [
    "Egypt", "United States", "United Kingdom", "Germany", "France",
    "Saudi Arabia", "UAE", "Italy", "Spain", "China",
    "Japan", "India", "Brazil", "Canada", "Australia",
    "Russia", "Turkey", "Netherlands", "Sweden", "Switzerland",
    "Belgium", "Poland", "South Korea", "Mexico", "Argentina",
    "South Africa", "Nigeria", "Morocco", "Tunisia", "Jordan",
    "Lebanon", "Kuwait", "Qatar", "Iraq", "Iran",
    "Pakistan", "Bangladesh", "Indonesia", "Malaysia", "Thailand",
    "Philippines", "Vietnam", "Singapore", "New Zealand", "Ireland",
    "Portugal", "Greece", "Czech Republic", "Hungary", "Romania",
    "Ukraine", "Israel",
]
NAT_PROBS = np.array([
    0.250,  # Egypt — local tourism is dominant
    0.080,  # United States
    0.060,  # United Kingdom
    0.050,  # Germany
    0.050,  # France
    0.040,  # Saudi Arabia
    0.030,  # UAE
    0.030,  # Italy
    0.020,  # Spain
    0.030,  # China
    0.020,  # Japan
    0.030,  # India
    0.020,  # Brazil
    0.020,  # Canada
    0.020,  # Australia
    0.020,  # Russia
    0.020,  # Turkey
    0.010,  # Netherlands
    0.010,  # Sweden
    0.010,  # Switzerland
    0.010,  # Belgium
    0.010,  # Poland
    0.010,  # South Korea
    0.010,  # Mexico
    0.010,  # Argentina
    0.010,  # South Africa
    0.010,  # Nigeria
    0.010,  # Morocco
    0.010,  # Tunisia
    0.010,  # Jordan
    0.010,  # Lebanon
    0.005,  # Kuwait
    0.005,  # Qatar
    0.005,  # Iraq
    0.005,  # Iran
    0.005,  # Pakistan
    0.005,  # Bangladesh
    0.005,  # Indonesia
    0.005,  # Malaysia
    0.005,  # Thailand
    0.005,  # Philippines
    0.005,  # Vietnam
    0.005,  # Singapore
    0.005,  # New Zealand
    0.005,  # Ireland
    0.005,  # Portugal
    0.005,  # Greece
    0.005,  # Czech Republic
    0.005,  # Hungary
    0.005,  # Romania
    0.005,  # Ukraine
    0.005,  # Israel
], dtype=np.float64)
assert len(NAT_NAMES) == len(NAT_PROBS), (
    f"Nationality mismatch: {len(NAT_NAMES)} names vs {len(NAT_PROBS)} probs"
)
NAT_PROBS /= NAT_PROBS.sum()   # normalise to exactly 1.0

BUDGETS      = np.array(["low", "medium", "high"])
BUD_PROBS    = np.array([0.30, 0.50, 0.20])

TRAVELS      = np.array(["solo", "couple", "family", "luxury"])
TRAVEL_PROBS = np.array([0.30, 0.35, 0.25, 0.10])

GENDERS      = np.array(["male", "female"])

# Realistic age distribution — Gaussian centred at 35, clipped to [18, 75]
_AGES   = np.arange(18, 76)
_AGE_W  = np.exp(-0.5 * ((_AGES - 35) / 12) ** 2)
_AGE_W /= _AGE_W.sum()

# Preference count distribution: 1–5 categories per user
PREF_COUNT_PROBS = np.array([0.10, 0.30, 0.35, 0.15, 0.10])

# Pre-build numpy array of category name strings (used in preference formatting)
_CATS_ARR = np.array(ALL_CATS)

# ─────────────────────────────────────────────────────────────────────────────
# 5.  Preference weight matrix — vectorised, correlates with
#     age, gender, budget, and travel type
# ─────────────────────────────────────────────────────────────────────────────
def build_weight_matrix(
    age_arr:    np.ndarray,   # (n,) int
    gender_arr: np.ndarray,   # (n,) str  "male" | "female"
    bud_code:   np.ndarray,   # (n,) int8  0/1/2
    trav_code:  np.ndarray,   # (n,) int8  0/1/2/3
) -> np.ndarray:              # returns (n, N_CATS) float32
    """
    Build a weight matrix that biases each user toward certain landmark
    categories based on their demographics.

    Higher weight → user more likely to list that category in preferences.

    Correlations applied (multiplicative, so they stack):
      Age:    young (<30)  → activities, escape rooms, theme parks       ×2.0
              older (≥50)  → museums, monuments, culture                 ×2.5
      Gender: female       → shopping, jewelry, art, souvenirs           ×1.8
              male         → sport, activities, horse riding, nature     ×1.6
      Budget: high         → Nile cruise, rooftop, jewelry, art, malls  ×2.5
              low          → bazaars, traditional food, souvenirs        ×1.8
      Travel: family       → theme parks, zoos, parks, day trips        ×3.0
              luxury       → Nile cruises, rooftop, jewelry, art        ×3.0
              couple       → Nile restaurants, cruises, rooftop          ×2.5
              solo         → landmarks, monuments, museums, nature       ×2.0
    """
    n = len(age_arr)
    W = np.ones((n, N_CATS), dtype=np.float32)
    ci = CAT_IDX    # shorthand

    # ── Age ──────────────────────────────────────────────────────────────────
    young = age_arr < 30
    older = age_arr >= 50

    for c in ("Activity", "Escape Room", "Theme Park", "Rooftop Restaurant",
              "Bazaar / Souq", "Souvenir Shop", "Sport & Recreation"):
        if c in ci:
            W[young, ci[c]] *= 2.0

    for c in ("Museum", "Ancient Monument", "Pharaonic Site", "Islamic Monument",
              "Coptic Site", "Cultural Center", "Art Gallery", "Antiques"):
        if c in ci:
            W[older, ci[c]] *= 2.5

    # ── Gender ───────────────────────────────────────────────────────────────
    female = gender_arr == "female"
    male   = gender_arr == "male"

    for c in ("Shopping Mall", "Gold & Jewelry Market", "Art Gallery",
              "Souvenir Shop", "Nile View Restaurant"):
        if c in ci:
            W[female, ci[c]] *= 1.8

    for c in ("Sport & Recreation", "Activity", "Horse Riding",
              "Nature Reserve", "Day Trip Site"):
        if c in ci:
            W[male, ci[c]] *= 1.6

    # ── Budget ───────────────────────────────────────────────────────────────
    high_b = bud_code == 2
    low_b  = bud_code == 0

    for c in ("Nile Cruise", "Rooftop Restaurant", "Gold & Jewelry Market",
              "Art Gallery", "Shopping Mall"):
        if c in ci:
            W[high_b, ci[c]] *= 2.5

    for c in ("Bazaar / Souq", "Traditional Restaurant", "Souvenir Shop",
              "Day Trip Site", "Antiques"):
        if c in ci:
            W[low_b, ci[c]] *= 1.8

    # ── Travel type ──────────────────────────────────────────────────────────
    is_family = trav_code == 2
    is_luxury = trav_code == 3
    is_couple = trav_code == 1
    is_solo   = trav_code == 0

    for c in ("Theme Park", "Zoo / Aquarium", "Park / Garden",
              "Day Trip Site", "Nature Reserve"):
        if c in ci:
            W[is_family, ci[c]] *= 3.0

    for c in ("Nile Cruise", "Rooftop Restaurant", "Gold & Jewelry Market",
              "Art Gallery", "Shopping Mall"):
        if c in ci:
            W[is_luxury, ci[c]] *= 3.0

    for c in ("Nile View Restaurant", "Nile Cruise", "Rooftop Restaurant",
              "Gold & Jewelry Market"):
        if c in ci:
            W[is_couple, ci[c]] *= 2.5

    for c in ("Landmark", "Ancient Monument", "Pharaonic Site",
              "Museum", "Art Gallery", "Nature Reserve"):
        if c in ci:
            W[is_solo, ci[c]] *= 2.0

    return W


# ─────────────────────────────────────────────────────────────────────────────
# 6.  Vectorised preference sampling — Gumbel-max trick
#     Returns raw integer indices AND fully vectorised string representations
# ─────────────────────────────────────────────────────────────────────────────
def sample_preferences(
    W:   np.ndarray,             # (n, N_CATS) float32  weight matrix
    rng: np.random.Generator,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """
    Sample 1–5 preferred categories per user using the Gumbel-max trick
    for approximate sampling without replacement.

    Returns
    -------
    top5_sorted : (n, 5) int16   — top-5 category indices, best-first, padded
    n_prefs     : (n,)   int8    — how many of those 5 are actually used
    pref_str    : (n,)   object  — string representation e.g. "['Museum', 'Landmark']"
    """
    n = W.shape[0]

    # Row-normalise weights to probabilities
    P = W / W.sum(axis=1, keepdims=True)

    # Gumbel-max trick: argmax(log p_i + Gumbel_i) ≈ sample without replacement
    log_P  = np.log(P + 1e-12).astype(np.float32)
    gumbel = -np.log(-np.log(
        rng.random(P.shape, dtype=np.float32).clip(1e-12, 1 - 1e-12)
    ))
    scores = log_P + gumbel                                  # (n, N_CATS)

    # Top-5 indices per row (unsorted)
    top5 = np.argpartition(scores, -5, axis=1)[:, -5:]       # (n, 5)

    # Sort those 5 by descending score → index 0 = most preferred
    row_idx     = np.arange(n)[:, None]
    order       = np.argsort(scores[row_idx, top5], axis=1)[:, ::-1]
    top5_sorted = top5[row_idx, order].astype(np.int16)      # (n, 5)

    # How many preferences each user keeps: 1–5
    n_prefs = rng.choice(
        np.array([1, 2, 3, 4, 5], dtype=np.int8),
        size=n,
        p=PREF_COUNT_PROBS,
    )

    # ── Build preference strings — FULLY VECTORISED (no row-level loop) ──────
    # Strategy: for each possible k=1..5, select all users with that n_prefs
    # and build strings via NumPy string concatenation (runs in C, not Python).
    cat_names_2d = _CATS_ARR[top5_sorted]                    # (n, 5) of strings
    pref_str     = np.empty(n, dtype=object)

    for k in range(1, 6):
        mask = n_prefs == k
        if not mask.any():
            continue
        sub = cat_names_2d[mask, :k]    # (m, k) array of category name strings

        # Build "['cat1', 'cat2', ...]" using vectorised np.char operations.
        # Only 5 branches (k=1..5), each is a single vectorised op on arrays.
        if k == 1:
            pref_str[mask] = "['" + sub[:, 0] + "']"
        elif k == 2:
            pref_str[mask] = ("['" + sub[:, 0] + "', '"
                              + sub[:, 1] + "']")
        elif k == 3:
            pref_str[mask] = ("['" + sub[:, 0] + "', '"
                              + sub[:, 1] + "', '"
                              + sub[:, 2] + "']")
        elif k == 4:
            pref_str[mask] = ("['" + sub[:, 0] + "', '"
                              + sub[:, 1] + "', '"
                              + sub[:, 2] + "', '"
                              + sub[:, 3] + "']")
        else:  # k == 5
            pref_str[mask] = ("['" + sub[:, 0] + "', '"
                              + sub[:, 1] + "', '"
                              + sub[:, 2] + "', '"
                              + sub[:, 3] + "', '"
                              + sub[:, 4] + "']")

    return top5_sorted, n_prefs, pref_str


# ─────────────────────────────────────────────────────────────────────────────
# 7.  Fully vectorised landmark sampling — group-based batch approach
#     (no per-row Python loop)
# ─────────────────────────────────────────────────────────────────────────────
def sample_landmarks(
    bud_code:   np.ndarray,   # (n,) int8    user budget code
    pref_idx:   np.ndarray,   # (n, 5) int16 top-5 preference indices
    n_prefs:    np.ndarray,   # (n,) int8    number of valid preferences
    rng:        np.random.Generator,
) -> np.ndarray:              # (n,) int32   landmark row indices
    """
    Three-tier landmark selection, fully vectorised via group-based batching:

    Tier 1 (50%):  landmark whose category matches user's top preference
                   AND whose budget matches user's budget.
    Tier 2 (30%):  landmark whose category matches user's top preference
                   (any budget).
    Tier 3 (20%):  uniformly random landmark.

    For Tiers 1–2, if the matching pool is empty for a particular (budget, cat)
    combination, that user "falls through" to the next tier.

    Groups users by (budget, top_cat) → at most 3 × 27 = 81 groups.
    Within each group, all sampling is a single rng.integers() call.
    """
    n    = len(bud_code)
    out  = np.full(n, -1, dtype=np.int32)
    roll = rng.random(n)

    # User's #1 preferred category
    top_cat = pref_idx[:, 0].astype(np.int32)

    # Group users by (budget, top_cat) for batch processing
    group_keys, inv = np.unique(
        np.stack([bud_code, top_cat], axis=1), axis=0, return_inverse=True
    )   # group_keys: (G, 2);  inv: (n,) maps each user to its group

    # ── Tier 1: budget + category match (target: roll < 0.50) ────────────────
    t1_want = roll < 0.50       # which users *want* tier 1
    if t1_want.any():
        for g, (bc, cc) in enumerate(group_keys):
            pool = lm_pool.get((int(bc), int(cc)), _EMPTY)
            if len(pool) == 0:
                continue
            # Users in this group who want tier 1
            g_mask = (inv == g) & t1_want
            g_count = g_mask.sum()
            if g_count == 0:
                continue
            out[g_mask] = pool[rng.integers(0, len(pool), size=g_count)]

        # Users who wanted tier 1 but got nothing (empty pool) → push to tier 2
        t1_fail = t1_want & (out < 0)
        roll[t1_fail] = 0.60    # slide into tier-2 band

    # ── Tier 2: category only, any budget (target: 0.50 ≤ roll < 0.80) ───────
    t2_want = (roll >= 0.50) & (roll < 0.80) & (out < 0)
    if t2_want.any():
        unique_cats = np.unique(top_cat[t2_want])
        for cc in unique_cats:
            pool = lm_pool_cat.get(int(cc), _EMPTY)
            if len(pool) == 0:
                continue
            c_mask = t2_want & (top_cat == cc)
            c_count = c_mask.sum()
            if c_count == 0:
                continue
            out[c_mask] = pool[rng.integers(0, len(pool), size=c_count)]

    # ── Tier 3: uniformly random fallback ────────────────────────────────────
    t3_mask = out < 0
    if t3_mask.any():
        out[t3_mask] = rng.integers(0, N_LM, size=t3_mask.sum(), dtype=np.int32)

    return out


# ─────────────────────────────────────────────────────────────────────────────
# 8.  Main generation loop — chunked writes with progress tracking
# ─────────────────────────────────────────────────────────────────────────────
total_chunks = (N_ROWS + CHUNK - 1) // CHUNK
print(f"Generating {N_ROWS:,} rows in {total_chunks} chunks of {CHUNK:,} …\n", flush=True)

first_chunk  = True
total_start  = time.perf_counter()

for chunk_start in range(0, N_ROWS, CHUNK):
    t0        = time.perf_counter()
    chunk_end = min(chunk_start + CHUNK, N_ROWS)
    n         = chunk_end - chunk_start
    chunk_num = chunk_start // CHUNK + 1

    # ── Demographics ─────────────────────────────────────────────────────────
    ages         = RNG.choice(_AGES, size=n, p=_AGE_W)
    genders      = RNG.choice(GENDERS, size=n, p=[0.51, 0.49])
    nats         = RNG.choice(NAT_NAMES, size=n, p=NAT_PROBS)
    bud_codes    = RNG.choice(np.array([0, 1, 2], dtype=np.int8), size=n, p=BUD_PROBS)
    travel_codes = RNG.choice(np.array([0, 1, 2, 3], dtype=np.int8), size=n, p=TRAVEL_PROBS)

    budgets      = BUDGETS[bud_codes]
    travel_types = TRAVELS[travel_codes]

    # ── Preferences (fully vectorised) ───────────────────────────────────────
    W = build_weight_matrix(ages, genders, bud_codes, travel_codes)
    pref_idx, n_prefs, prefs = sample_preferences(W, RNG)

    # ── Landmark selection (fully vectorised) ────────────────────────────────
    lm_sel_idx = sample_landmarks(bud_codes, pref_idx, n_prefs, RNG)
    lm_sel     = lm.iloc[lm_sel_idx].reset_index(drop=True)

    # ── User IDs (vectorised via np.char) ────────────────────────────────────
    uid_nums = np.arange(chunk_start + 1, chunk_end + 1, dtype=np.int32)
    user_ids = np.char.add("U", np.char.zfill(uid_nums.astype(str), 7))

    # ── Assemble DataFrame ───────────────────────────────────────────────────
    df_chunk = pd.DataFrame({
        "user_id"                      : user_ids,
        "user_age"                     : ages,
        "user_gender"                  : genders,
        "user_nationality"             : nats,
        "user_budget"                  : budgets,
        "user_travel_type"             : travel_types,
        "user_preferences"             : prefs,
        "landmark_name"                : lm_sel["landmark_name"].values,
        "landmark_category"            : lm_sel["landmark_category"].values,
        "landmark_rate"                : lm_sel["landmark_rate"].values,
        "landmark_budget"              : lm_sel["landmark_budget"].values,
        "landmark_Suitable_Travel_Type": lm_sel["landmark_Suitable_Travel_Type"].values,
    })

    # ── Write chunk to CSV (append mode after first) ─────────────────────────
    df_chunk.to_csv(
        OUTPUT_CSV,
        index=False,
        mode="w" if first_chunk else "a",
        header=first_chunk,
    )
    first_chunk = False

    # ── Progress ─────────────────────────────────────────────────────────────
    elapsed_chunk = time.perf_counter() - t0
    elapsed_total = time.perf_counter() - total_start
    rows_done     = chunk_end
    rate          = rows_done / elapsed_total
    eta           = (N_ROWS - rows_done) / rate if rate > 0 else 0

    print(
        f"  [{chunk_num:>2}/{total_chunks}]  "
        f"rows {chunk_start:>9,} – {chunk_end:>9,}  │  "
        f"chunk {elapsed_chunk:5.1f}s  │  "
        f"total {elapsed_total:6.1f}s  │  "
        f"{rate:>8,.0f} rows/s  │  "
        f"ETA {eta:5.0f}s",
        flush=True,
    )

total_elapsed = time.perf_counter() - total_start
print(f"\n{'═' * 72}")
print(f"  ✓ Generation complete in {total_elapsed:.1f}s  "
      f"({N_ROWS / total_elapsed:,.0f} rows/s)")
print(f"  ✓ Output: {OUTPUT_CSV}")
print(f"{'═' * 72}")

# ─────────────────────────────────────────────────────────────────────────────
# 9.  Post-generation validation (memory-safe: reads only a sample)
# ─────────────────────────────────────────────────────────────────────────────
VALIDATION_ROWS = 200_000     # enough for statistical confidence, ~50 MB

print(f"\n── Validation (sampling {VALIDATION_ROWS:,} rows) ──────────────────────\n",
      flush=True)

val = pd.read_csv(OUTPUT_CSV, nrows=VALIDATION_ROWS)

_pass = 0
_fail = 0


def check(label: str, condition: bool, detail: str = "") -> None:
    """Print a single validation check result."""
    global _pass, _fail
    if condition:
        _pass += 1
        icon = "✓"
    else:
        _fail += 1
        icon = "✗"
    suffix = f"  [{detail}]" if detail else ""
    print(f"  {icon}  {label}{suffix}")


# ── Row count (via line counting, no full load) ─────────────────────────────
# Count lines in the CSV without loading the entire file
line_count = 0
with open(OUTPUT_CSV, "r", encoding="utf-8") as f:
    for _ in f:
        line_count += 1
actual_rows = line_count - 1   # subtract header
check("Row count == 5,000,000",
      actual_rows == N_ROWS,
      f"got {actual_rows:,}")

# ── Data quality checks on sample ───────────────────────────────────────────
check("No NaN values",
      val.isna().sum().sum() == 0,
      f"{val.isna().sum().sum()} NaNs")

check("User IDs sequential from U0000001",
      val["user_id"].iloc[0] == "U0000001"
      and val["user_id"].iloc[-1] == f"U{VALIDATION_ROWS:07d}")

check("User ID format (U + 7 digits)",
      val["user_id"].str.match(r"^U\d{7}$").all())

# ── Distribution checks (tolerance ±1% — robust for any N_ROWS ≥ 10K) ─────
TOL = 0.01

bud_dist = val["user_budget"].value_counts(normalize=True)
check("Budget: low ≈ 30%",
      abs(bud_dist.get("low",    0) - 0.30) < TOL,
      f"{bud_dist.get('low', 0):.3f}")
check("Budget: medium ≈ 50%",
      abs(bud_dist.get("medium", 0) - 0.50) < TOL,
      f"{bud_dist.get('medium', 0):.3f}")
check("Budget: high ≈ 20%",
      abs(bud_dist.get("high",   0) - 0.20) < TOL,
      f"{bud_dist.get('high', 0):.3f}")

trv_dist = val["user_travel_type"].value_counts(normalize=True)
check("Travel: solo ≈ 30%",
      abs(trv_dist.get("solo",   0) - 0.30) < TOL,
      f"{trv_dist.get('solo', 0):.3f}")
check("Travel: couple ≈ 35%",
      abs(trv_dist.get("couple", 0) - 0.35) < TOL,
      f"{trv_dist.get('couple', 0):.3f}")
check("Travel: family ≈ 25%",
      abs(trv_dist.get("family", 0) - 0.25) < TOL,
      f"{trv_dist.get('family', 0):.3f}")
check("Travel: luxury ≈ 10%",
      abs(trv_dist.get("luxury", 0) - 0.10) < TOL,
      f"{trv_dist.get('luxury', 0):.3f}")

gen_dist = val["user_gender"].value_counts(normalize=True)
check("Gender: male ≈ 51%",
      abs(gen_dist.get("male",   0) - 0.51) < TOL,
      f"{gen_dist.get('male', 0):.3f}")
check("Gender: female ≈ 49%",
      abs(gen_dist.get("female", 0) - 0.49) < TOL,
      f"{gen_dist.get('female', 0):.3f}")

check("Age range [18, 75]",
      val["user_age"].between(18, 75).all(),
      f"min={val['user_age'].min()} max={val['user_age'].max()}")

age_mean = val["user_age"].mean()
check("Age mean ≈ 35",
      30 <= age_mean <= 40,
      f"mean={age_mean:.1f}")

check("All landmark categories valid",
      val["landmark_category"].isin(lm["landmark_category"].unique()).all())

check("No null landmark names",
      val["landmark_name"].notna().all())

# ── Preference string validity ──────────────────────────────────────────────
import ast

try:
    _sample_prefs = val["user_preferences"].head(2000).apply(ast.literal_eval)
    all_valid = _sample_prefs.apply(
        lambda x: isinstance(x, list)
                  and 1 <= len(x) <= 5
                  and all(c in ALL_CATS for c in x)
    ).all()
    check("Preference strings parseable & valid categories", all_valid)
except Exception as e:
    check("Preference strings parseable", False, str(e))

# ── Summary ──────────────────────────────────────────────────────────────────
print(f"\n  {'─' * 50}")
print(f"  Passed: {_pass}   Failed: {_fail}   Total: {_pass + _fail}")
print(f"\n  Age  mean={val['user_age'].mean():.1f}  "
      f"std={val['user_age'].std():.1f}  (target ≈ 35 / ~10)")
print(f"  Gender  {val['user_gender'].value_counts(normalize=True).round(3).to_dict()}")
print(f"  Top nationalities  "
      f"{val['user_nationality'].value_counts(normalize=True).head(5).round(3).to_dict()}")
print(f"\n{'All checks passed ✓' if _fail == 0 else f'{_fail} check(s) FAILED ✗'}")
