"""
Synthetic dataset generator — 5,000,000 user–landmark interaction rows.
Saves output to: synthetic_user_landmarks.csv

Fully vectorised — no Python loops over individual rows.

Improvements over v1:
  - Eliminated row-level Python loops in sample_preferences and sample_landmarks
  - Added gender-based preference correlation
  - Fixed nationality names/probabilities count mismatch
  - Added per-chunk timing and progress estimates
  - Added post-generation data validation
  - Configurable input/output paths
  - Passes raw category indices instead of parsing strings
"""

import time
import numpy as np
import pandas as pd

# ─────────────────────────────────────────────
# 0.  Config
# ─────────────────────────────────────────────
N_ROWS   = 5_000_000
CHUNK    = 500_000          # rows per chunk (tune for memory)
RNG      = np.random.default_rng(42)
# NOTE: Changing CHUNK with the same seed will produce different data
#       because the RNG state flows sequentially across chunks.

INPUT_CSV = "data_with_price_categories.csv"
OUTPUT    = "synthetic_user_landmarks.csv"

# ─────────────────────────────────────────────
# 1.  Load landmark reference data
# ─────────────────────────────────────────────
print("Loading landmark data...", flush=True)
lm = pd.read_csv(INPUT_CSV)
lm["price ranges"] = lm["price ranges"].str.strip().str.lower()
lm["Category"]     = lm["Category"].str.strip()
lm = lm[["Name", "Category", "Rating", "price ranges"]].rename(columns={
    "Name":         "landmark_name",
    "Category":     "landmark_category",
    "Rating":       "landmark_rate",
    "price ranges": "landmark_budget",
}).reset_index(drop=True)
N_LM = len(lm)
print(f"  Loaded {N_LM} landmarks.", flush=True)

# ─────────────────────────────────────────────
# 2.  Suitable travel type (precomputed per landmark)
# ─────────────────────────────────────────────
def suitable(cat: str, bud: str) -> str:
    """Assign suitable travel types based on category + budget rules."""
    if cat == "Rooftop Restaurant":
        return "['couple', 'luxury']" if bud == "high" else "['couple', 'family']"
    if cat in ("Landmark", "Traditional Restaurant"):
        return "['solo', 'couple', 'family', 'luxury']"
    if cat in ("Islamic Monument", "Coptic Site", "Cultural Center",
               "Ancient Monument", "Pharaonic Site"):
        return "['solo', 'couple', 'family']"
    if cat in ("Activity", "Zoo / Aquarium", "Nature Reserve"):
        return "['solo', 'couple', 'family']"
    if cat == "Shopping Mall":
        return "['solo', 'family', 'couple', 'luxury']" if bud == "high" else "['solo', 'family', 'couple']"
    if cat == "Park / Garden":
        return "['solo', 'family', 'couple', 'luxury']" if bud == "high" else "['solo', 'family', 'couple']"
    if cat == "Nile View Restaurant":
        return "['couple', 'luxury']" if bud == "high" else "['couple', 'family']"
    if cat == "Nile Cruise":
        return "['couple', 'family', 'luxury']" if bud == "high" else "['solo', 'couple', 'family']"
    if cat == "Antiques":
        return "['solo', 'couple', 'family', 'luxury']" if bud == "high" else "['solo', 'couple', 'family']"
    if cat == "Theme Park":
        return "['solo', 'family']"
    if cat == "Escape Room":
        return "['couple', 'family']"
    if cat == "Day Trip Site":
        return "['couple', 'family', 'solo']"
    if cat == "Bazaar / Souq":
        return "['solo', 'family']"
    if cat == "Museum":
        return "['solo', 'couple', 'family', 'luxury']" if bud in ("medium", "high") else "['solo', 'couple', 'family']"
    if cat == "Horse Riding":
        return "['family', 'luxury']" if bud == "high" else "['family']"
    if cat == "Art Gallery":
        return "['solo', 'couple', 'luxury']" if bud == "high" else "['solo', 'couple']"
    if cat == "Gold & Jewelry Market":
        return "['couple', 'luxury']" if bud == "high" else "['couple']"
    return "['solo', 'couple', 'family']"   # fallback

lm["landmark_Suitable_Travel_Type"] = lm.apply(
    lambda r: suitable(r["landmark_category"], r["landmark_budget"]), axis=1
)

# ─────────────────────────────────────────────
# 3.  Category & nationality lookups
# ─────────────────────────────────────────────
ALL_CATS = [
    "Activity", "Ancient Monument", "Antiques", "Art Gallery", "Bazaar / Souq",
    "Coptic Site", "Cultural Center", "Day Trip Site", "Escape Room", "Food Tour",
    "Gold & Jewelry Market", "Horse Riding", "Islamic Monument", "Landmark",
    "Museum", "Nature Reserve", "Nile Cruise", "Nile View Restaurant", "Park / Garden",
    "Pharaonic Site", "Rooftop Restaurant", "Shopping Mall", "Souvenir Shop",
    "Sport & Recreation", "Theme Park", "Traditional Restaurant", "Zoo / Aquarium",
]
N_CATS  = len(ALL_CATS)
CAT_IDX = {c: i for i, c in enumerate(ALL_CATS)}

# Map: category index → array of landmark row-indices
lm_by_cat_idx = {}
for ci, cat in enumerate(ALL_CATS):
    arr = lm.index[lm["landmark_category"] == cat].to_numpy(dtype=np.int32)
    lm_by_cat_idx[ci] = arr

# Landmark budget as integer code: low=0, medium=1, high=2
BUD_CODE = {"low": 0, "medium": 1, "high": 2}
lm_bud_code = lm["landmark_budget"].map(BUD_CODE).fillna(1).to_numpy(dtype=np.int8)

# Map: (budget_code, cat_idx) → array of landmark row-indices
lm_by_budcat = {}
for b_code in (0, 1, 2):
    for ci in range(N_CATS):
        cat_name = ALL_CATS[ci]
        arr = lm.index[
            (lm["landmark_category"] == cat_name) &
            (lm_bud_code == b_code)
        ].to_numpy(dtype=np.int32)
        lm_by_budcat[(b_code, ci)] = arr

# ── Flatten the (budget, cat) → landmark arrays for vectorised lookup ──
# We build a flat array and an offset table so we can do batch random indexing.
# For each (budget_code, cat_idx) key, store: offset into flat array, count.
_flat_parts = []
_offset_table = np.zeros((3, N_CATS), dtype=np.int64)   # start offsets
_count_table  = np.zeros((3, N_CATS), dtype=np.int32)    # counts
_cursor = 0
for b_code in (0, 1, 2):
    for ci in range(N_CATS):
        arr = lm_by_budcat[(b_code, ci)]
        _offset_table[b_code, ci] = _cursor
        _count_table[b_code, ci]  = len(arr)
        if len(arr):
            _flat_parts.append(arr)
            _cursor += len(arr)
FLAT_BUDCAT = np.concatenate(_flat_parts) if _flat_parts else np.array([], dtype=np.int32)

# Same for cat-only lookup (any budget)
_flat_cat_parts = []
_cat_offset = np.zeros(N_CATS, dtype=np.int64)
_cat_count  = np.zeros(N_CATS, dtype=np.int32)
_cursor = 0
for ci in range(N_CATS):
    arr = lm_by_cat_idx.get(ci, np.array([], dtype=np.int32))
    _cat_offset[ci] = _cursor
    _cat_count[ci]  = len(arr)
    if len(arr):
        _flat_cat_parts.append(arr)
        _cursor += len(arr)
FLAT_CAT = np.concatenate(_flat_cat_parts) if _flat_cat_parts else np.array([], dtype=np.int32)

# Nationalities — 52 countries with matched probabilities
NAT_NAMES = [
    "Egypt", "United States", "United Kingdom", "Germany", "France", "Saudi Arabia",
    "UAE", "Italy", "Spain", "China", "Japan", "India", "Brazil", "Canada", "Australia",
    "Russia", "Turkey", "Netherlands", "Sweden", "Switzerland", "Belgium", "Poland",
    "South Korea", "Mexico", "Argentina", "South Africa", "Nigeria", "Morocco",
    "Tunisia", "Jordan", "Lebanon", "Kuwait", "Qatar", "Iraq", "Iran", "Pakistan",
    "Bangladesh", "Indonesia", "Malaysia", "Thailand", "Philippines", "Vietnam",
    "Singapore", "New Zealand", "Ireland", "Portugal", "Greece", "Czech Republic",
    "Hungary", "Romania", "Ukraine", "Israel",
]
NAT_PROBS = np.array([
    0.25,  # Egypt (local tourism is dominant)
    0.08,  # United States
    0.06,  # United Kingdom
    0.05,  # Germany
    0.05,  # France
    0.04,  # Saudi Arabia
    0.03,  # UAE
    0.03,  # Italy
    0.02,  # Spain
    0.03,  # China
    0.02,  # Japan
    0.03,  # India
    0.02,  # Brazil
    0.02,  # Canada
    0.02,  # Australia
    0.02,  # Russia
    0.02,  # Turkey
    0.01,  # Netherlands
    0.01,  # Sweden
    0.01,  # Switzerland
    0.01,  # Belgium
    0.01,  # Poland
    0.01,  # South Korea
    0.01,  # Mexico
    0.01,  # Argentina
    0.01,  # South Africa
    0.01,  # Nigeria
    0.01,  # Morocco
    0.01,  # Tunisia
    0.01,  # Jordan
    0.01,  # Lebanon
    0.005, # Kuwait
    0.005, # Qatar
    0.005, # Iraq
    0.005, # Iran
    0.005, # Pakistan
    0.005, # Bangladesh
    0.005, # Indonesia
    0.005, # Malaysia
    0.005, # Thailand
    0.005, # Philippines
    0.005, # Vietnam
    0.005, # Singapore
    0.005, # New Zealand
    0.005, # Ireland
    0.005, # Portugal
    0.005, # Greece
    0.005, # Czech Republic
    0.005, # Hungary
    0.005, # Romania
    0.005, # Ukraine
    0.005, # Israel
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

# Realistic age distribution — Gaussian centred at 35, clipped to 18-75
_ages_range = np.arange(18, 76)
_age_w = np.exp(-0.5 * ((_ages_range - 35) / 12) ** 2)
_age_w /= _age_w.sum()

# Preference count distribution: 1 to 5 categories
PREF_COUNT_PROBS = np.array([0.10, 0.30, 0.35, 0.15, 0.10])

# ─────────────────────────────────────────────
# 4.  Category weight matrix (vectorised)
#     Correlates preferences with age, gender,
#     budget, and travel type.
# ─────────────────────────────────────────────
def build_weight_matrix(age_arr, gender_arr, budget_code_arr, travel_code_arr, n):
    """
    Build an (n, N_CATS) weight matrix for category preference sampling.
    Higher weight = user is more likely to prefer that category.
    
    Correlations:
      - Age:    young (<30) like activities/escape rooms/theme parks;
                older (≥50) like museums/monuments/cultural sites
      - Gender: female slightly prefers shopping/jewelry/art;
                male slightly prefers sport/activities
      - Budget: high-budget users prefer luxury categories;
                low-budget users prefer bazaars/traditional food
      - Travel: families prefer parks/zoos/theme parks;
                luxury travelers prefer Nile cruises/rooftop restaurants;
                couples prefer romantic venues;
                solo travelers prefer cultural/historical
    """
    W = np.ones((n, N_CATS), dtype=np.float32)
    ci = CAT_IDX

    # ── Age-based correlations ──
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

    # ── Gender-based correlations (new in v2) ──
    is_female = gender_arr == 1   # 0=male, 1=female (code-based)
    is_male   = gender_arr == 0
    for c in ("Shopping Mall", "Gold & Jewelry Market", "Art Gallery",
              "Souvenir Shop", "Nile Cruise"):
        if c in ci:
            W[is_female, ci[c]] *= 1.5
    for c in ("Sport & Recreation", "Activity", "Horse Riding",
              "Nature Reserve", "Day Trip Site"):
        if c in ci:
            W[is_male, ci[c]] *= 1.5

    # ── Budget-based correlations ──
    high = budget_code_arr == 2
    low  = budget_code_arr == 0
    for c in ("Nile Cruise", "Rooftop Restaurant", "Gold & Jewelry Market",
              "Art Gallery", "Shopping Mall"):
        if c in ci:
            W[high, ci[c]] *= 2.5
    for c in ("Bazaar / Souq", "Traditional Restaurant", "Souvenir Shop",
              "Day Trip Site", "Antiques"):
        if c in ci:
            W[low, ci[c]] *= 1.8

    # ── Travel-type correlations ──
    is_family = travel_code_arr == 2
    is_luxury = travel_code_arr == 3
    is_couple = travel_code_arr == 1
    is_solo   = travel_code_arr == 0
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
    for c in ("Landmark", "Ancient Monument", "Pharaonic Site", "Museum",
              "Art Gallery", "Nature Reserve"):
        if c in ci:
            W[is_solo, ci[c]] *= 2.0

    return W


# ─────────────────────────────────────────────
# 5.  Vectorised preference sampling (Gumbel-max)
#     Returns raw integer indices AND string
#     representations — no row-level loop.
# ─────────────────────────────────────────────
# Pre-build the strings for ALL_CATS once
_CATS_ARR = np.array(ALL_CATS)


def sample_preferences(W, rng):
    """
    Sample 1-5 preferred categories per user using the Gumbel-max trick
    for sampling without replacement.

    Returns:
        first_cat_idx: (n,) int32 — the index of the user's top preference
        pref_strings:  (n,) object array — string representation of preferences
    """
    n = W.shape[0]

    # Normalise weights to probabilities
    row_sums = W.sum(axis=1, keepdims=True)
    P = W / row_sums

    # How many preferences each user gets (1-5)
    n_prefs = rng.choice(np.arange(1, 6), size=n, p=PREF_COUNT_PROBS)

    # Gumbel-max trick: add Gumbel noise to log-probabilities.
    # For each row, the top-k indices by noisy score are an
    # approximate sample-without-replacement from the distribution.
    log_P = np.log(P + 1e-12)
    gumbel = -np.log(-np.log(rng.random(P.shape, dtype=np.float32) + 1e-12) + 1e-12)
    scores = log_P + gumbel   # (n, N_CATS)

    # Get top-5 indices per row (we always need at most 5)
    top5 = np.argpartition(scores, -5, axis=1)[:, -5:]   # (n, 5)

    # Sort within each row by descending score
    row_idx = np.arange(n)[:, None]
    top5_scores = scores[row_idx, top5]
    sort_order  = np.argsort(top5_scores, axis=1)[:, ::-1]
    top5_sorted = top5[row_idx, sort_order]   # (n, 5) — sorted best-first

    # The user's #1 preferred category (used for landmark matching later)
    first_cat_idx = top5_sorted[:, 0].astype(np.int32)

    # ── Build preference strings WITHOUT a Python row-loop ──
    # Strategy: for each possible pref-count (1-5), batch-build the
    # string for all users with that count at once.
    cat_names_2d = _CATS_ARR[top5_sorted]   # (n, 5) of category name strings

    pref_strings = np.empty(n, dtype=object)
    for k in range(1, 6):
        mask = n_prefs == k
        if not mask.any():
            continue
        # cat_names_2d[mask, :k] is (count, k) — convert each row to list string
        sub = cat_names_2d[mask, :k]   # (count, k)
        # Build strings in a vectorised-ish way using list comprehension on
        # small k-width slices (k is at most 5, so this is NOT row-level)
        if k == 1:
            pref_strings[mask] = "['" + sub[:, 0] + "']"
        elif k == 2:
            pref_strings[mask] = "['" + sub[:, 0] + "', '" + sub[:, 1] + "']"
        elif k == 3:
            pref_strings[mask] = ("['" + sub[:, 0] + "', '"
                                  + sub[:, 1] + "', '" + sub[:, 2] + "']")
        elif k == 4:
            pref_strings[mask] = ("['" + sub[:, 0] + "', '" + sub[:, 1]
                                  + "', '" + sub[:, 2] + "', '" + sub[:, 3] + "']")
        else:   # k == 5
            pref_strings[mask] = ("['" + sub[:, 0] + "', '" + sub[:, 1]
                                  + "', '" + sub[:, 2] + "', '" + sub[:, 3]
                                  + "', '" + sub[:, 4] + "']")

    return first_cat_idx, pref_strings


# ─────────────────────────────────────────────
# 6.  Vectorised landmark sampling
#     (no row-level Python loop)
# ─────────────────────────────────────────────
def sample_landmarks_vec(budget_code_arr, first_cat_idx, rng):
    """
    Vectorised landmark selection. For each user:
      - 50% chance: pick a landmark matching (first preferred category + user budget)
      - 30% chance: pick a landmark matching (first preferred category, any budget)
      - 20% chance: pick a completely random landmark

    Falls through to the next tier if the preferred pool is empty.

    Args:
        budget_code_arr: (n,) int8  — user budget code (0=low, 1=mid, 2=high)
        first_cat_idx:   (n,) int32 — index of user's top preferred category
        rng:             numpy Generator

    Returns:
        (n,) int32 — landmark row indices into the `lm` DataFrame
    """
    n = len(budget_code_arr)
    out = np.empty(n, dtype=np.int32)
    roll = rng.random(n)

    # ── Tier 1 (50%): budget + category match ──
    tier1_mask = roll < 0.50
    if tier1_mask.any():
        _assign_from_pool(
            out, tier1_mask, budget_code_arr, first_cat_idx,
            _offset_table, _count_table, FLAT_BUDCAT, rng
        )

    # ── Tier 2 (30%): category match, any budget ──
    tier2_mask = (~tier1_mask) & (roll < 0.80)
    # Also include tier-1 users who couldn't find a match (out still -1 sentinel)
    # We use a sentinel: initialise out to -1 before tier1
    # ... Actually let's just handle fallthrough properly:
    # Re-approach: process all, with fallthrough
    out[:] = -1
    _assign_from_pool_budcat(out, budget_code_arr, first_cat_idx, roll, rng)

    # Any remaining -1s get a uniformly random landmark
    remaining = out == -1
    if remaining.any():
        out[remaining] = rng.integers(0, N_LM, size=remaining.sum(), dtype=np.int32)

    return out


def _assign_from_pool_budcat(out, budget_code_arr, first_cat_idx, roll, rng):
    """
    Vectorised assignment with fallthrough tiers.
    Groups users by (budget, category) and batch-samples within each group.
    """
    n = len(out)

    # Process by unique (budget, category) pairs to avoid row-level loops
    # Build a composite key: budget * N_CATS + cat_idx
    composite = budget_code_arr.astype(np.int32) * N_CATS + first_cat_idx

    for b_code in range(3):
        for ci in range(N_CATS):
            key = b_code * N_CATS + ci

            # ── Tier 1: budget + category (roll < 0.50) ──
            t1_mask = (composite == key) & (roll < 0.50)
            count_t1 = _count_table[b_code, ci]
            if t1_mask.any() and count_t1 > 0:
                offset = _offset_table[b_code, ci]
                rand_idx = rng.integers(0, count_t1, size=t1_mask.sum())
                out[t1_mask] = FLAT_BUDCAT[offset + rand_idx]

            # ── Tier 2: category only (0.50 <= roll < 0.80) ──
            t2_mask = (composite == key) & (roll >= 0.50) & (roll < 0.80)
            # Also tier-1 fallthrough (where pool was empty)
            t1_miss = t1_mask & (out == -1)
            combined_t2 = t2_mask | t1_miss
            count_cat = _cat_count[ci]
            if combined_t2.any() and count_cat > 0:
                offset_c = _cat_offset[ci]
                rand_idx = rng.integers(0, count_cat, size=combined_t2.sum())
                out[combined_t2] = FLAT_CAT[offset_c + rand_idx]

            # ── Tier 3 (roll >= 0.80) handled globally after this function ──


# ─────────────────────────────────────────────
# 7.  Vectorised user_id generation
# ─────────────────────────────────────────────
def make_user_ids(start, end):
    """Generate user IDs like U0000001 .. U0000500 using NumPy string ops."""
    nums = np.arange(start + 1, end + 1)
    # np.char operations are faster than Python list comprehension
    return np.char.add("U", np.char.zfill(nums.astype(str), 7))


# ─────────────────────────────────────────────
# 8.  Main loop (chunked writes with timing)
# ─────────────────────────────────────────────
print(f"\nGenerating {N_ROWS:,} rows in chunks of {CHUNK:,}...\n", flush=True)
first_chunk = True
t_total_start = time.time()

for chunk_start in range(0, N_ROWS, CHUNK):
    t_chunk = time.time()
    chunk_end = min(chunk_start + CHUNK, N_ROWS)
    n = chunk_end - chunk_start
    chunk_num   = chunk_start // CHUNK + 1
    total_chunks = (N_ROWS + CHUNK - 1) // CHUNK

    # ── Demographics ──
    ages         = RNG.choice(_ages_range, size=n, p=_age_w)
    gender_codes = RNG.choice([0, 1], size=n, p=[0.51, 0.49])  # 0=male, 1=female
    genders      = GENDERS[gender_codes]
    nats         = RNG.choice(NAT_NAMES, size=n, p=NAT_PROBS)
    bud_codes    = RNG.choice([0, 1, 2], size=n, p=BUD_PROBS).astype(np.int8)
    travel_codes = RNG.choice([0, 1, 2, 3], size=n, p=TRAVEL_PROBS).astype(np.int8)

    budgets      = BUDGETS[bud_codes]
    travel_types = TRAVELS[travel_codes]

    # ── Preferences (vectorised) ──
    W = build_weight_matrix(ages, gender_codes, bud_codes, travel_codes, n)
    first_cat_idx, prefs = sample_preferences(W, RNG)

    # ── Landmark selection (vectorised) ──
    lm_idx = sample_landmarks_vec(bud_codes, first_cat_idx, RNG)
    lm_sel = lm.iloc[lm_idx].reset_index(drop=True)

    # ── User IDs (vectorised) ──
    user_ids = make_user_ids(chunk_start, chunk_end)

    # ── Assemble DataFrame ──
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

    # ── Write chunk ──
    df_chunk.to_csv(OUTPUT, index=False,
                    mode="w" if first_chunk else "a",
                    header=first_chunk)
    first_chunk = False

    # ── Progress ──
    elapsed_chunk = time.time() - t_chunk
    elapsed_total = time.time() - t_total_start
    rows_done     = chunk_end
    rate          = rows_done / elapsed_total
    eta           = (N_ROWS - rows_done) / rate if rate > 0 else 0

    print(
        f"  [{chunk_num}/{total_chunks}] "
        f"rows {chunk_start:>9,}–{chunk_end:>9,}  |  "
        f"chunk {elapsed_chunk:.1f}s  |  "
        f"total {elapsed_total:.1f}s  |  "
        f"rate {rate:,.0f} rows/s  |  "
        f"ETA {eta:.0f}s",
        flush=True,
    )

t_total = time.time() - t_total_start
print(f"\n✓ Generation complete in {t_total:.1f}s ({N_ROWS/t_total:,.0f} rows/s)")
print(f"  Output: {OUTPUT}")

# ─────────────────────────────────────────────
# 9.  Post-generation validation
# ─────────────────────────────────────────────
print("\nRunning validation checks...", flush=True)

# Read a sample to validate (don't load full 5M into RAM)
sample = pd.read_csv(OUTPUT, nrows=100_000)

checks_passed = 0
checks_total  = 0

# Check 1: No NaN values
checks_total += 1
nan_count = sample.isna().sum().sum()
if nan_count == 0:
    checks_passed += 1
    print("  ✓ No NaN values in sample")
else:
    print(f"  ✗ Found {nan_count} NaN values in sample")

# Check 2: Budget distribution ~30/50/20
checks_total += 1
bud_dist = sample["user_budget"].value_counts(normalize=True)
bud_ok = all(
    abs(bud_dist.get(b, 0) - e) < 0.02
    for b, e in [("low", 0.30), ("medium", 0.50), ("high", 0.20)]
)
if bud_ok:
    checks_passed += 1
    print(f"  ✓ Budget distribution OK: {dict(bud_dist.round(3))}")
else:
    print(f"  ✗ Budget distribution off: {dict(bud_dist.round(3))}")

# Check 3: Travel type distribution ~30/35/25/10
checks_total += 1
tt_dist = sample["user_travel_type"].value_counts(normalize=True)
tt_ok = all(
    abs(tt_dist.get(t, 0) - e) < 0.02
    for t, e in [("solo", 0.30), ("couple", 0.35), ("family", 0.25), ("luxury", 0.10)]
)
if tt_ok:
    checks_passed += 1
    print(f"  ✓ Travel type distribution OK: {dict(tt_dist.round(3))}")
else:
    print(f"  ✗ Travel type distribution off: {dict(tt_dist.round(3))}")

# Check 4: Gender distribution ~51/49
checks_total += 1
gen_dist = sample["user_gender"].value_counts(normalize=True)
gen_ok = all(
    abs(gen_dist.get(g, 0) - e) < 0.02
    for g, e in [("male", 0.51), ("female", 0.49)]
)
if gen_ok:
    checks_passed += 1
    print(f"  ✓ Gender distribution OK: {dict(gen_dist.round(3))}")
else:
    print(f"  ✗ Gender distribution off: {dict(gen_dist.round(3))}")

# Check 5: User IDs are sequential
checks_total += 1
first_id = sample["user_id"].iloc[0]
last_id  = sample["user_id"].iloc[-1]
if first_id == "U0000001" and last_id == f"U{len(sample):07d}":
    checks_passed += 1
    print(f"  ✓ User IDs sequential: {first_id} → {last_id}")
else:
    print(f"  ✗ User IDs unexpected: {first_id} → {last_id}")

# Check 6: All preference strings are parseable
checks_total += 1
try:
    import ast
    parsed = sample["user_preferences"].head(1000).apply(ast.literal_eval)
    all_valid = parsed.apply(lambda x: all(c in ALL_CATS for c in x)).all()
    if all_valid:
        checks_passed += 1
        print("  ✓ All preference strings contain valid categories")
    else:
        print("  ✗ Some preference strings contain invalid categories")
except Exception as e:
    print(f"  ✗ Preference parsing failed: {e}")

# Check 7: Age distribution reasonable (mean near 35)
checks_total += 1
age_mean = sample["user_age"].mean()
if 30 <= age_mean <= 40:
    checks_passed += 1
    print(f"  ✓ Age mean = {age_mean:.1f} (expected ~35)")
else:
    print(f"  ✗ Age mean = {age_mean:.1f} (expected ~35)")

print(f"\n  Validation: {checks_passed}/{checks_total} checks passed.")
print("Done ✓")
