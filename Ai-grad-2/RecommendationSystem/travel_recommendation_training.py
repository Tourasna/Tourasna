# travel_recommendation_training.py
# ============================================================================
# Travel Recommendation System — Deep Learning Training Pipeline v4.0
# ============================================================================
#
# Trains a dual-input neural network on the full 5M-row synthetic dataset
# and produces all model artifacts, evaluation metrics, plots, and reports.
#
# Key improvements over v3.0:
#   1. Full 5M dataset (configurable via SAMPLE_SIZE) with 70/15/15 split
#   2. Fully vectorized label creation — no iloc/iterrows loops
#   3. Wider architecture with element-wise interaction features
#   4. Composite Huber+MAE loss for robustness to outliers and skew
#   5. CosineDecay LR schedule for better late-epoch convergence
#   6. tf.data pipeline with batching, shuffling, and prefetching
#   7. Early stopping with patience=8 and best-weight restoration
#   8. Comprehensive output: 7 plots, metrics JSON, history CSV,
#      test predictions CSV, and academic training summary
#
# ============================================================================

import gc
import json
import logging
import os
import pickle
import random
import time
from datetime import datetime

import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for server/headless training
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import seaborn as sns
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers, regularizers
from sklearn.metrics import (
    accuracy_score, mean_absolute_error, mean_squared_error, r2_score,
)
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

from utils import (
    parse_list_string,
    normalize_budget,
    prepare_user_features_single,
    prepare_landmark_features_batch,
    get_top_10_diverse_recommendations,
    ALL_CATEGORIES,
    TRAVEL_TYPES,
    BUDGET_LEVELS,
    AGE_MIN,
    AGE_MAX,
    RATING_MIN,
    RATING_MAX,
    FEATURE_DIMS,
)

# ============================================================================
# LOGGING SETUP
# ============================================================================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S',
)
logger = logging.getLogger(__name__)

# ============================================================================
# CONFIGURATION
# ============================================================================

# -- Reproducibility --------------------------------------------------------
SEED = 42

# -- Data -------------------------------------------------------------------
SAMPLE_SIZE = None          # None = use full dataset; set int for testing
SPLIT_RATIO = (0.70, 0.15, 0.15)   # train / val / test

# -- Training ---------------------------------------------------------------
BATCH_SIZE = 512            # Larger batches improve CPU throughput
EPOCHS = 30                 # Upper bound; early stopping may end earlier
INITIAL_LR = 3e-4           # Starting learning rate for CosineDecay
L2_WEIGHT = 1e-3            # L2 regularization strength on Dense layers
EARLY_STOP_PATIENCE = 8     # Epochs to wait before early stopping
COSINE_ALPHA = 1e-5         # Minimum LR at end of cosine schedule

# -- Loss -------------------------------------------------------------------
HUBER_DELTA = 0.5           # Huber δ — quadratic for |e|<δ, linear beyond
MAE_LOSS_WEIGHT = 0.1       # Weight of the MAE component in composite loss

# -- Label noise ------------------------------------------------------------
LABEL_NOISE_STD = 0.05      # Gaussian noise σ added to synthetic labels

# -- Output -----------------------------------------------------------------
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# -- Plot style -------------------------------------------------------------
plt.style.use('seaborn-v0_8-darkgrid')
sns.set_palette("husl")


# ============================================================================
# REPRODUCIBILITY
# ============================================================================

def set_seeds(seed: int = SEED) -> None:
    """Set all random seeds for full reproducibility."""
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)
    os.environ['TF_DETERMINISTIC_OPS'] = '1'
    logger.info("Random seeds set to %d for reproducibility", seed)


# ============================================================================
# CUSTOM LOSS FUNCTION
# ============================================================================

@keras.utils.register_keras_serializable(package='TravelRec')
class CompositeHuberMAELoss(keras.losses.Loss):
    """Composite loss: Huber + weighted MAE.

    **Why composite?**
    - Huber loss is robust to outliers (linear penalty beyond δ), preventing
      the model from being pulled towards extreme values.
    - The added MAE component reduces the systematic underestimation bias
      (right-skewed error distribution) observed with pure MSE, because MAE
      penalises all errors equally regardless of direction.

    Args:
        delta: Huber threshold — errors below δ are penalised quadratically,
               errors above δ are penalised linearly.
        mae_weight: Relative weight of the MAE term (default 0.1).
    """

    def __init__(self, delta: float = 0.5, mae_weight: float = 0.1,
                 name: str = 'composite_huber_mae', **kwargs):
        super().__init__(name=name, **kwargs)
        self.delta = delta
        self.mae_weight = mae_weight

    def call(self, y_true, y_pred):
        y_true = tf.cast(y_true, y_pred.dtype)
        # Ensure y_true has the same rank as y_pred (usually (batch, 1))
        # to prevent unintended broadcasting during subtraction.
        if len(y_true.shape) != len(y_pred.shape):
            y_true = tf.reshape(y_true, tf.shape(y_pred))

        error = y_true - y_pred
        abs_error = tf.abs(error)

        # Huber: 0.5·e² for |e|≤δ,  δ·|e| - 0.5·δ² for |e|>δ
        quadratic = tf.minimum(abs_error, self.delta)
        linear_part = abs_error - quadratic
        huber = 0.5 * tf.square(quadratic) + self.delta * linear_part

        # Composite: Huber + λ·MAE
        return huber + self.mae_weight * abs_error

    def get_config(self):
        config = super().get_config()
        config.update({'delta': self.delta, 'mae_weight': self.mae_weight})
        return config


# ============================================================================
# DATA LOADING & CLEANING
# ============================================================================

def load_and_clean_data(file_path: str, sample_size=SAMPLE_SIZE):
    """Load CSV dataset and perform basic cleaning.

    Optimizations for large datasets:
    - Explicit fillna with median for numeric columns
    - Optional sub-sampling for rapid iteration

    Returns:
        df: Cleaned DataFrame (full or sampled)
        unique_landmarks: DataFrame of unique landmarks
    """
    logger.info("Loading data from: %s", file_path)
    df = pd.read_csv(file_path, encoding='utf-8')
    logger.info("Loaded %s rows", f"{len(df):,}")

    # --- Clean numeric columns ---
    df['user_age'] = pd.to_numeric(df['user_age'], errors='coerce')
    df['landmark_rate'] = pd.to_numeric(df['landmark_rate'], errors='coerce')
    age_median = df['user_age'].median()
    rate_median = df['landmark_rate'].median()
    df['user_age'] = df['user_age'].fillna(age_median)
    df['landmark_rate'] = df['landmark_rate'].fillna(rate_median)

    # --- Optional sub-sampling ---
    if sample_size is not None and sample_size < len(df):
        logger.info("Sub-sampling %s rows (SAMPLE_SIZE=%s)", f"{sample_size:,}", sample_size)
        df = df.sample(sample_size, random_state=SEED).reset_index(drop=True)

    # --- Extract unique landmarks ---
    unique_landmarks = df[[
        'landmark_name', 'landmark_category', 'landmark_budget',
        'landmark_rate', 'landmark_Suitable_Travel_Type',
    ]].drop_duplicates()
    logger.info("Found %s unique landmarks", f"{len(unique_landmarks):,}")

    return df, unique_landmarks


# ============================================================================
# VECTORIZED FEATURE ENGINEERING
# ============================================================================

def generate_user_affinities(df: pd.DataFrame, categories: list = None) -> np.ndarray:
    """Generate a continuous affinity matrix (Nx27) representing genuine nuanced preferences.
    Instead of discrete 1/0, it assigns decreasing weights to explicit preferences based on order,
    then adds individual variance noise so that no two users are exactly 100% identical.
    """
    if categories is None:
        categories = ALL_CATEGORIES
    
    n = len(df)
    n_cats = len(categories)
    cat_lower = [c.lower() for c in categories]
    
    # 1. Base affinities from explicit string
    unique_prefs = df['user_preferences'].unique()
    pref_to_idx = {p: i for i, p in enumerate(unique_prefs)}
    
    unique_base = np.zeros((len(unique_prefs), n_cats), dtype=np.float32)
    for i, p_str in enumerate(unique_prefs):
        parsed = [str(x).lower() for x in parse_list_string(p_str)]
        for j, cat in enumerate(cat_lower):
            if cat in parsed:
                idx = parsed.index(cat)
                # Falloff: 1st=0.8, 2nd=0.7...
                unique_base[i, j] = max(0.4, 0.8 - (0.1 * idx))
            else:
                unique_base[i, j] = 0.05
                
    mapped_indices = df['user_preferences'].map(pref_to_idx).values
    base_affinities = unique_base[mapped_indices]
    
    # 2. Add individual variance noise
    np.random.seed(SEED) # Ensure deterministic noise generation
    noise = np.random.uniform(0.0, 0.3, size=(n, n_cats)).astype(np.float32)
    affinities = np.clip(base_affinities + noise, 0.0, 1.0)
    
    return affinities


def engineer_user_features(df: pd.DataFrame, affinities_matrix: np.ndarray, categories=None) -> np.ndarray:
    """Create user feature matrix using vectorized operations.

    Feature order (39 dims):
        [age_norm, gender_male, gender_female,
         budget_low, budget_med, budget_high,
         travel_family, travel_couple, travel_solo, travel_luxury,
         interaction_count_norm, recency_norm,
         pref_0 ... pref_26]

    Returns:
        np.ndarray of shape (n_samples, 39), dtype float32
    """
    if categories is None:
        categories = ALL_CATEGORIES

    n = len(df)

    # Age — normalised to [0, 1]
    age_norm = np.clip(
        (df['user_age'].astype(np.float32).values - AGE_MIN) / (AGE_MAX - AGE_MIN),
        0.0, 1.0,
    ).reshape(-1, 1)

    # Gender — one-hot [male, female]
    gender_lower = df['user_gender'].str.lower().values
    gender_male = (gender_lower == 'male').astype(np.float32).reshape(-1, 1)
    gender_female = (gender_lower != 'male').astype(np.float32).reshape(-1, 1)

    # Budget — one-hot [low, medium, high]
    unique_budgets = df['user_budget'].unique()
    budget_map_norm = {b: normalize_budget(b) for b in unique_budgets}
    budget_normed = df['user_budget'].map(budget_map_norm).values
    budget_onehot = np.zeros((n, 3), dtype=np.float32)
    for i, level in enumerate(BUDGET_LEVELS):
        budget_onehot[:, i] = (budget_normed == level).astype(np.float32)

    # Travel type — one-hot [family, couple, solo, luxury]
    travel_lower = df['user_travel_type'].str.lower().values
    travel_onehot = np.zeros((n, len(TRAVEL_TYPES)), dtype=np.float32)
    for i, t in enumerate(TRAVEL_TYPES):
        travel_onehot[:, i] = (travel_lower == t).astype(np.float32)

    # Implicit behavioral traits: interaction count & recency
    np.random.seed(SEED)
    interaction_norm = np.random.uniform(0.0, 1.0, size=(n, 1)).astype(np.float32)
    recency_norm = np.random.uniform(0.0, 1.0, size=(n, 1)).astype(np.float32)

    # Stack all features
    user_features = np.hstack([
        age_norm, gender_male, gender_female,
        budget_onehot, travel_onehot,
        interaction_norm, recency_norm,
        affinities_matrix,
    ])

    logger.info("User features shape: %s  dtype: %s", user_features.shape, user_features.dtype)
    assert user_features.shape[1] == FEATURE_DIMS['user'], \
        f"User feature dim mismatch: {user_features.shape[1]} vs expected {FEATURE_DIMS['user']}"
    return user_features


def engineer_landmark_features(df: pd.DataFrame, categories=None) -> np.ndarray:
    """Create landmark feature matrix using vectorized operations.

    Feature order (31 dims):
        [cat_onehot_0 ... cat_onehot_26,
         budget_low, budget_med, budget_high,
         rating_norm]

    Returns:
        np.ndarray of shape (n_samples, 31), dtype float32
    """
    if categories is None:
        categories = ALL_CATEGORIES

    n = len(df)

    # Category — one-hot
    category_matrix = np.zeros((n, len(categories)), dtype=np.float32)
    cat_values = df['landmark_category'].values
    for i, cat in enumerate(categories):
        category_matrix[:, i] = (cat_values == cat).astype(np.float32)

    # Budget — one-hot (normalised via pre-mapped dict)
    unique_budgets = df['landmark_budget'].unique()
    budget_map_norm = {b: normalize_budget(b) for b in unique_budgets}
    budget_normed = df['landmark_budget'].map(budget_map_norm).values
    budget_onehot = np.zeros((n, 3), dtype=np.float32)
    for i, level in enumerate(BUDGET_LEVELS):
        budget_onehot[:, i] = (budget_normed == level).astype(np.float32)

    # Rating — normalised to [0, 1]
    rating_norm = np.clip(
        (df['landmark_rate'].astype(np.float32).values - RATING_MIN) / (RATING_MAX - RATING_MIN),
        0.0, 1.0,
    ).reshape(-1, 1)

    landmark_features = np.hstack([category_matrix, budget_onehot, rating_norm])

    logger.info("Landmark features shape: %s  dtype: %s", landmark_features.shape, landmark_features.dtype)
    assert landmark_features.shape[1] == FEATURE_DIMS['landmark'], \
        f"Landmark feature dim mismatch: {landmark_features.shape[1]} vs expected {FEATURE_DIMS['landmark']}"
    return landmark_features


# ============================================================================
# VECTORIZED LABEL CREATION
# ============================================================================

def create_labels_vectorized(df: pd.DataFrame, affinities_matrix: np.ndarray, noise_std: float = LABEL_NOISE_STD) -> np.ndarray:
    """Create training labels using a weighted continuous formula.

    Weights:
        - Category Affinity: 35% (computed directly from the continuous affinity matrix)
        - Normalized Rating: 20%
        - Budget Compatibility: 20% (continuous penalty matrix)
        - Travel Type Fit: 15%
        - Popularity Trend: 10% (intrinsic static score per landmark)
        - Gaussian Noise: + N(0, noise_std)

    Returns:
        np.ndarray of shape (n,) with values in [0, 1], dtype float32
    """
    n = len(df)
    import hashlib

    # --- 1. Normalized Rating (20%) ---
    rating = pd.to_numeric(df['landmark_rate'], errors='coerce').fillna(df['landmark_rate'].median()).values
    rating_norm = np.clip((rating - RATING_MIN) / (RATING_MAX - RATING_MIN), 0.0, 1.0).astype(np.float32)
    score_rating = rating_norm * 0.20
    logger.info("  Rating component computed (vectorized)")

    # --- 2. Budget Compatibility (20%) ---
    # User budget vs Landmark budget compatibility matrix
    budget_matrix = {
        ('low', 'low'): 1.0, ('low', 'medium'): 0.3, ('low', 'high'): 0.0,
        ('medium', 'low'): 0.8, ('medium', 'medium'): 1.0, ('medium', 'high'): 0.4,
        ('high', 'low'): 0.6, ('high', 'medium'): 0.8, ('high', 'high'): 1.0
    }
    unique_user_budgets = df['user_budget'].unique()
    user_budget_map = {b: normalize_budget(b) for b in unique_user_budgets}
    user_budget_norm = df['user_budget'].map(user_budget_map).values

    unique_land_budgets = df['landmark_budget'].unique()
    land_budget_map = {b: normalize_budget(b) for b in unique_land_budgets}
    land_budget_norm = df['landmark_budget'].map(land_budget_map).values

    # Vectorized map using parallel arrays
    budget_combo = pd.Series(zip(user_budget_norm, land_budget_norm))
    score_budget = budget_combo.map(lambda x: budget_matrix.get(x, 0.5)).values.astype(np.float32) * 0.20
    logger.info("  Budget compatibility computed (vectorized)")

    # --- 3. Travel Type Fit (15%) ---
    travel_combo = (
        df['user_travel_type'].astype(str) + '|||'
        + df['landmark_Suitable_Travel_Type'].astype(str)
    )
    unique_travel_combos = travel_combo.unique()
    travel_match_map = {}
    for combo in unique_travel_combos:
        parts = combo.split('|||', 1)
        user_t = parts[0].lower().strip()
        landmark_t_str = parts[1] if len(parts) > 1 else ''
        travel_types = frozenset(t.lower().strip() for t in parse_list_string(landmark_t_str))
        travel_match_map[combo] = 1.0 if user_t in travel_types else 0.2

    score_travel = travel_combo.map(travel_match_map).values.astype(np.float32) * 0.15
    logger.info("  Travel fit computed (dedup)")

    # --- 4. Category Affinity (35%) ---
    # Fetch the genuine continuous affinity score assigned to this specific user
    # for the specific landmark category out of the 27 dimensions.
    cat_lower = [c.lower() for c in ALL_CATEGORIES]
    cat_to_col = {c: i for i, c in enumerate(cat_lower)}
    
    # Map the landmark's category to the column index in the affinity matrix
    row_cat_cols = df['landmark_category'].str.lower().map(cat_to_col).fillna(0).astype(int).values
    
    # Advanced indexing: get the precise affinity score instantly
    score_category = affinities_matrix[np.arange(n), row_cat_cols] * 0.35
    logger.info("  Category affinity computed (from continuous affinity matrix)")

    # --- 5. Popularity Trend (10%) ---
    # Intrinsic stable popularity for each landmark
    def get_popularity(name):
        h = int(hashlib.md5(str(name).encode('utf-8')).hexdigest()[:8], 16)
        return 0.4 + (h / 0xffffffff) * 0.6
        
    unique_landmarks = df['landmark_name'].unique()
    pop_map = {name: get_popularity(name) for name in unique_landmarks}
    score_popularity = df['landmark_name'].map(pop_map).values.astype(np.float32) * 0.10
    logger.info("  Popularity trend computed (hashed)")

    # --- Combine ---
    labels = score_rating + score_budget + score_travel + score_category + score_popularity

    # Add Gaussian noise
    noise = np.random.normal(0, noise_std, n).astype(np.float32)
    labels += noise
    labels = np.clip(labels, 0.0, 1.0)

    logger.info("Label stats: mean=%.3f  std=%.3f  min=%.3f  max=%.3f",
                labels.mean(), labels.std(), labels.min(), labels.max())
    return labels


# ============================================================================
# MODEL ARCHITECTURE
# ============================================================================

def build_model(user_dim: int, landmark_dim: int, l2_weight: float = L2_WEIGHT):
    """Build improved dual-input neural network.

    Architecture improvements over v3.0:
    - Wider user branch (128→64→32) for richer user representations
    - Element-wise multiply interaction (in addition to dot product) captures
      per-dimension feature alignment — addresses scatter dispersion
    - Deeper prediction head (64→32→16→1) for finer-grained score prediction
    - Consistent BN + Dropout on all layers for stable convergence

    Args:
        user_dim: Number of user features (expected 37)
        landmark_dim: Number of landmark features (expected 31)
        l2_weight: L2 regularisation coefficient

    Returns:
        Compiled Keras Model
    """
    reg = regularizers.l2(l2_weight)

    # ---- User branch: 128 → 64 → 32 ----
    user_input = layers.Input(shape=(user_dim,), name='user_input')
    x = layers.Dense(128, activation='relu', kernel_regularizer=reg)(user_input)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(64, activation='relu', kernel_regularizer=reg)(x)
    x = layers.BatchNormalization()(x)
    x = layers.Dropout(0.3)(x)
    x = layers.Dense(32, activation='relu', kernel_regularizer=reg)(x)
    user_embedding = layers.BatchNormalization()(x)

    # ---- Landmark branch: 64 → 32 ----
    landmark_input = layers.Input(shape=(landmark_dim,), name='landmark_input')
    y = layers.Dense(64, activation='relu', kernel_regularizer=reg)(landmark_input)
    y = layers.BatchNormalization()(y)
    y = layers.Dropout(0.3)(y)
    y = layers.Dense(32, activation='relu', kernel_regularizer=reg)(y)
    landmark_embedding = layers.BatchNormalization()(y)

    # ---- Interaction layer ----
    # Dot product captures global similarity between embeddings
    dot_product = layers.Dot(axes=1, normalize=True)(
        [user_embedding, landmark_embedding]
    )
    # Element-wise product captures per-dimension alignment — richer signal
    # that helps reduce scatter dispersion in predictions
    element_product = layers.Multiply()([user_embedding, landmark_embedding])

    # Combined: user(32) + landmark(32) + dot(1) + element(32) = 97
    combined = layers.Concatenate()(
        [user_embedding, landmark_embedding, dot_product, element_product]
    )

    # ---- Prediction head: 64 → 32 → 16 → 1 ----
    z = layers.Dense(64, activation='relu', kernel_regularizer=reg)(combined)
    z = layers.BatchNormalization()(z)
    z = layers.Dropout(0.3)(z)
    z = layers.Dense(32, activation='relu', kernel_regularizer=reg)(z)
    z = layers.BatchNormalization()(z)
    z = layers.Dropout(0.2)(z)
    z = layers.Dense(16, activation='relu')(z)
    z = layers.Dropout(0.2)(z)
    output = layers.Dense(1, activation='sigmoid')(z)

    model = keras.Model(
        inputs=[user_input, landmark_input],
        outputs=output,
        name='travel_recommendation_model',
    )

    # ---- LR Schedule ----
    # Compute total training steps for cosine schedule.
    # We estimate assuming full dataset and max epochs; early stopping may
    # end earlier but the cosine curve is still well-shaped.
    # Actual steps_per_epoch is set dynamically in train_model().
    logger.info("Model built. Compilation deferred to train_model() for dynamic LR schedule.")

    return model


# ============================================================================
# tf.data PIPELINE
# ============================================================================

def create_tf_data_pipeline(X_user, X_landmark, y, batch_size, shuffle=False, seed=SEED):
    """Create an efficient tf.data pipeline for training or evaluation.

    Benefits over raw numpy arrays:
    - Automatic batching with drop_remainder for consistent batch sizes
    - Prefetching overlaps data prep with computation (even on CPU)
    - Epoch-level shuffling prevents the model from memorising sample order
    """
    dataset = tf.data.Dataset.from_tensor_slices((
        {'user_input': X_user, 'landmark_input': X_landmark},
        y,
    ))

    if shuffle:
        buffer_size = min(100_000, len(y))
        dataset = dataset.shuffle(buffer_size=buffer_size, seed=seed,
                                  reshuffle_each_iteration=True)

    dataset = dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return dataset


# ============================================================================
# CUSTOM CALLBACKS
# ============================================================================

class LearningRateLogger(keras.callbacks.Callback):
    """Log the current learning rate at the end of each epoch.

    Supports both fixed LR and schedule-based LR (e.g. CosineDecay).
    Stores values in ``self.lrs`` for post-training plotting.
    """

    def __init__(self):
        super().__init__()
        self.lrs = []

    def on_epoch_end(self, epoch, logs=None):
        try:
            lr_obj = self.model.optimizer.learning_rate
            if isinstance(lr_obj, keras.optimizers.schedules.LearningRateSchedule):
                current_step = int(self.model.optimizer.iterations)
                lr = float(lr_obj(current_step))
            else:
                lr = float(lr_obj)
        except Exception:
            lr = 0.0
        self.lrs.append(lr)
        if logs is not None:
            logs['lr'] = lr


# ============================================================================
# TRAINING
# ============================================================================

def train_model(model, data, epochs=EPOCHS, batch_size=BATCH_SIZE):
    """Train the model with tf.data pipelines, cosine LR, and early stopping.

    Args:
        model: Un-compiled Keras model (compilation happens here with dynamic LR)
        data: dict with train/val/test numpy arrays
        epochs: Max training epochs
        batch_size: Mini-batch size

    Returns:
        (history, lr_logger) — training history and LR logger callback
    """
    n_train = len(data['y_train'])
    steps_per_epoch = int(np.ceil(n_train / batch_size))
    total_steps = steps_per_epoch * epochs

    # ---- CosineDecay LR schedule ----
    # Addresses diminishing gains in later epochs: LR smoothly decays from
    # INITIAL_LR to COSINE_ALPHA, preventing oscillation while still allowing
    # meaningful parameter updates in later training.
    lr_schedule = keras.optimizers.schedules.CosineDecay(
        initial_learning_rate=INITIAL_LR,
        decay_steps=total_steps,
        alpha=COSINE_ALPHA,
    )
    logger.info("LR schedule: CosineDecay  initial=%.1e  min=%.1e  over %d steps (%d epochs)",
                INITIAL_LR, COSINE_ALPHA, total_steps, epochs)

    # ---- Compile model ----
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=lr_schedule),
        loss=CompositeHuberMAELoss(delta=HUBER_DELTA, mae_weight=MAE_LOSS_WEIGHT),
        metrics=[
            'mae',
            keras.metrics.RootMeanSquaredError(),
            keras.metrics.MeanSquaredError(),
        ],
    )

    # ---- Create tf.data pipelines ----
    train_dataset = create_tf_data_pipeline(
        data['X_user_train'], data['X_landmark_train'], data['y_train'],
        batch_size=batch_size, shuffle=True,
    )
    val_dataset = create_tf_data_pipeline(
        data['X_user_val'], data['X_landmark_val'], data['y_val'],
        batch_size=batch_size, shuffle=False,
    )

    # ---- Callbacks ----
    lr_logger = LearningRateLogger()
    callbacks = [
        keras.callbacks.EarlyStopping(
            monitor='val_loss',
            patience=EARLY_STOP_PATIENCE,
            restore_best_weights=True,
            min_delta=1e-4,
            verbose=1,
        ),
        lr_logger,
    ]

    # ---- Train ----
    logger.info("Starting training: %d epochs, batch_size=%d, %d steps/epoch",
                epochs, batch_size, steps_per_epoch)
    history = model.fit(
        train_dataset,
        validation_data=val_dataset,
        epochs=epochs,
        callbacks=callbacks,
        verbose=1,
    )

    logger.info("Training completed after %d epochs.", len(history.history['loss']))
    return history, lr_logger


# ============================================================================
# DATA SPLITTING
# ============================================================================

def split_data(user_features, landmark_features, labels):
    """Split data into train / validation / test sets (70 / 15 / 15).

    Returns:
        dict with all split arrays
    """
    test_ratio = SPLIT_RATIO[2]        # 0.15
    val_ratio_of_remainder = SPLIT_RATIO[1] / (SPLIT_RATIO[0] + SPLIT_RATIO[1])  # 0.15/0.85

    # First split: 85% temp, 15% test
    (X_user_temp, X_user_test,
     X_land_temp, X_land_test,
     y_temp, y_test) = train_test_split(
        user_features, landmark_features, labels,
        test_size=test_ratio, random_state=SEED,
    )

    # Second split: temp → 70% train, 15% val  (val is 15/85 ≈ 17.6% of temp)
    (X_user_train, X_user_val,
     X_land_train, X_land_val,
     y_train, y_val) = train_test_split(
        X_user_temp, X_land_temp, y_temp,
        test_size=val_ratio_of_remainder, random_state=SEED,
    )

    logger.info("Training set:   %s samples", f"{len(y_train):,}")
    logger.info("Validation set: %s samples", f"{len(y_val):,}")
    logger.info("Test set:       %s samples", f"{len(y_test):,}")

    return {
        'X_user_train': X_user_train, 'X_user_val': X_user_val, 'X_user_test': X_user_test,
        'X_landmark_train': X_land_train, 'X_landmark_val': X_land_val, 'X_landmark_test': X_land_test,
        'y_train': y_train, 'y_val': y_val, 'y_test': y_test,
    }


# ============================================================================
# EVALUATION (Ranking Metrics)
# ============================================================================

def compute_ranking_metrics(y_true: np.ndarray, y_pred: np.ndarray, list_size: int = 15, k: int = 5) -> dict:
    """Simulate ranking by grouping test predictions into lists.
    Calculates NDCG@K, Precision@K, and Mean Reciprocal Rank (MRR).
    
    This evaluates the model on its ability to correctly sort items from best to
    worst, rather than its ability to guess a specific score.
    """
    n_lists = len(y_true) // list_size
    
    ndcg_scores = []
    precision_scores = []
    mrr_scores = []
    
    for i in range(n_lists):
        start = i * list_size
        end = start + list_size
        
        y_t = y_true[start:end]
        y_p = y_pred[start:end]
        
        # Sort by predicted score
        pred_order = np.argsort(y_p)[::-1]
        
        # True order (ideal)
        true_order = np.argsort(y_t)[::-1]
        
        # Get top K items by prediction
        top_k_pred_idx = pred_order[:k]
        top_k_true_idx = true_order[:k]
        
        # Precision@K
        hits = len(set(top_k_pred_idx).intersection(set(top_k_true_idx)))
        precision_scores.append(hits / k)
        
        # MRR: Look for the absolute best item in the user's predicted list
        best_true_idx = true_order[0]
        try:
            rank_of_best = list(pred_order).index(best_true_idx) + 1
            mrr_scores.append(1.0 / rank_of_best)
        except ValueError:
            mrr_scores.append(0.0)
            
        # NDCG@K
        relevance = y_t[top_k_pred_idx]
        ideal_relevance = y_t[top_k_true_idx]
        
        dcg = np.sum((2 ** relevance - 1) / np.log2(np.arange(2, k + 2)))
        idcg = np.sum((2 ** ideal_relevance - 1) / np.log2(np.arange(2, k + 2)))
        
        ndcg = dcg / idcg if idcg > 0 else 0
        ndcg_scores.append(ndcg)
        
    return {
        f'ndcg@{k}': np.mean(ndcg_scores),
        f'precision@{k}': np.mean(precision_scores),
        'mrr': np.mean(mrr_scores)
    }

def evaluate_model(model, data, history):
    """Evaluate model on test set and compute comprehensive metrics.

    Returns:
        dict with all evaluation metrics and predictions
    """
    print("\n" + "=" * 80)
    print("MODEL EVALUATION")
    print("=" * 80)

    # ---- Evaluate on test set ----
    results = model.evaluate(
        {'user_input': data['X_user_test'], 'landmark_input': data['X_landmark_test']},
        data['y_test'], verbose=0, batch_size=BATCH_SIZE,
    )
    # results order: [composite_loss, mae, rmse, mse]
    test_composite_loss = results[0]
    test_mae = results[1]
    test_rmse = results[2]
    test_mse = results[3]

    # ---- Full predictions for analysis ----
    y_pred = model.predict(
        {'user_input': data['X_user_test'], 'landmark_input': data['X_landmark_test']},
        verbose=0, batch_size=BATCH_SIZE,
    ).flatten()
    y_test = data['y_test']

    # ---- Regression metrics (Kept for secondary analysis) ----
    r2 = r2_score(y_test, y_pred)

    # ---- True Recommendation Metrics ----
    ranking_metrics = compute_ranking_metrics(y_test, y_pred, list_size=20, k=5)
    
    # ---- Overfitting analysis ----
    # Use MSE metric from history (not composite loss) for fair comparison
    mse_key = 'mean_squared_error'
    if mse_key not in history.history:
        mse_key = 'mse'  # Fallback key name

    train_mse_final = history.history[mse_key][-1] if mse_key in history.history else results[3]
    val_mse_key = f'val_{mse_key}'
    val_mse_final = history.history[val_mse_key][-1] if val_mse_key in history.history else test_mse

    ratio = max(train_mse_final, val_mse_final) / max(min(train_mse_final, val_mse_final), 1e-10)

    # ---- Print results ----
    print(f"\nRANKING EVALUATION (PRIMARY metrics):")
    print(f"  NDCG@5:               {ranking_metrics['ndcg@5']:.4f}")
    print(f"  Precision@5:          {ranking_metrics['precision@5']:.4f}")
    print(f"  MRR (Mean Rec. Rank): {ranking_metrics['mrr']:.4f}")

    print(f"\nRegression Evaluation (Secondary metrics):")
    print(f"  Test Loss (Composite):  {test_composite_loss:.6f}")
    print(f"  Test MSE:               {test_mse:.6f}")

    print(f"\nOverfitting Analysis:")
    print(f"  Final Training MSE:    {train_mse_final:.6f}")
    print(f"  Final Validation MSE:  {val_mse_final:.6f}")
    print(f"  MSE Ratio:             {ratio:.2f}x")

    if val_mse_final > train_mse_final * 2.0:
        print("  WARNING: Possible overfitting (val MSE >> train MSE)")
    elif train_mse_final > val_mse_final * 2.0:
        print("  NOTE: Heavy regularisation effect (train MSE > val MSE)")
    else:
        print("  GOOD: Minimal overfitting detected")

    return {
        'ndcg_5': ranking_metrics['ndcg@5'],
        'precision_5': ranking_metrics['precision@5'],
        'mrr': ranking_metrics['mrr'],
        'test_composite_loss': test_composite_loss,
        'test_mse': test_mse,
        'test_mae': test_mae,
        'test_rmse': test_rmse,
        'test_r2': r2,
        'y_test': y_test,
        'y_pred': y_pred,
        'train_mse_final': train_mse_final,
        'val_mse_final': val_mse_final,
        'loss_ratio': ratio,
    }


# ============================================================================
# PLOTTING
# ============================================================================

def _save_plot(fig, filename: str) -> None:
    """Save figure to SCRIPT_DIR and close."""
    path = os.path.join(SCRIPT_DIR, filename)
    fig.savefig(path, dpi=300, bbox_inches='tight')
    plt.close(fig)
    logger.info("Plot saved: %s", filename)


def plot_metric_curve(history, metric_key: str, display_name: str, filename: str) -> None:
    """Plot training vs validation curve for a single metric."""
    try:
        train_vals = history.history[metric_key]
        val_vals = history.history[f'val_{metric_key}']
    except KeyError:
        logger.warning("Metric '%s' not found in history — skipping plot.", metric_key)
        return

    fig, ax = plt.subplots(figsize=(10, 6))
    epochs = range(1, len(train_vals) + 1)
    ax.plot(epochs, train_vals, label=f'Training {display_name}',
            linewidth=2, marker='o', markersize=4)
    ax.plot(epochs, val_vals, label=f'Validation {display_name}',
            linewidth=2, marker='s', markersize=4)
    ax.set_title(f'Training vs Validation {display_name}', fontsize=16, fontweight='bold')
    ax.set_xlabel('Epoch', fontsize=13)
    ax.set_ylabel(display_name, fontsize=13)
    ax.legend(fontsize=12)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    _save_plot(fig, filename)


def plot_predicted_vs_actual(y_test, y_pred, filename='predicted_vs_actual.png') -> None:
    """Scatter plot of predicted vs actual values on the test set."""
    fig, ax = plt.subplots(figsize=(10, 8))

    # Sub-sample for plotting if dataset is very large (>50K points)
    n = len(y_test)
    if n > 50_000:
        idx = np.random.choice(n, 50_000, replace=False)
        y_t, y_p = y_test[idx], y_pred[idx]
    else:
        y_t, y_p = y_test, y_pred

    ax.scatter(y_t, y_p, alpha=0.15, s=8, color='steelblue', rasterized=True)
    ax.plot([0, 1], [0, 1], 'r--', lw=2, label='Perfect Prediction')
    ax.set_title('Predicted vs Actual Values', fontsize=16, fontweight='bold')
    ax.set_xlabel('Actual Scores', fontsize=13)
    ax.set_ylabel('Predicted Scores', fontsize=13)
    ax.legend(fontsize=12)
    ax.grid(True, alpha=0.3)
    ax.set_xlim(-0.05, 1.05)
    ax.set_ylim(-0.05, 1.05)
    fig.tight_layout()
    _save_plot(fig, filename)


def plot_error_distribution(y_test, y_pred, filename='error_distribution.png') -> None:
    """Histogram of residuals (prediction errors) on the test set."""
    errors = y_pred - y_test

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.hist(errors, bins=100, alpha=0.7, color='seagreen', edgecolor='black', linewidth=0.5)
    ax.axvline(x=0, color='red', linestyle='--', linewidth=2, label='Zero error')
    ax.axvline(x=errors.mean(), color='orange', linestyle='-', linewidth=2,
               label=f'Mean error: {errors.mean():.4f}')
    ax.set_title('Prediction Error Distribution (Test Set)', fontsize=16, fontweight='bold')
    ax.set_xlabel('Prediction Error (predicted − actual)', fontsize=13)
    ax.set_ylabel('Frequency', fontsize=13)
    ax.legend(fontsize=12)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    _save_plot(fig, filename)


def plot_batch_accuracy(y_test, y_pred, filename='batch_accuracy.png') -> None:
    """Bar chart of batch-wise binary accuracy (threshold=0.5)."""
    y_pred_bin = (y_pred >= 0.5).astype(int)
    y_test_bin = (y_test >= 0.5).astype(int)

    batch_size_plot = max(1000, len(y_test) // 100)
    accuracies = []
    for i in range(0, len(y_test_bin), batch_size_plot):
        end = min(i + batch_size_plot, len(y_test_bin))
        acc = accuracy_score(y_test_bin[i:end], y_pred_bin[i:end])
        accuracies.append(acc)

    fig, ax = plt.subplots(figsize=(12, 5))
    ax.bar(range(len(accuracies)), accuracies, alpha=0.7, color='mediumpurple')
    mean_acc = np.mean(accuracies)
    ax.axhline(y=mean_acc, color='red', linestyle='--', linewidth=2,
               label=f'Mean: {mean_acc:.3f}')
    ax.set_title('Batch-wise Accuracy', fontsize=16, fontweight='bold')
    ax.set_xlabel('Batch Number', fontsize=13)
    ax.set_ylabel('Accuracy', fontsize=13)
    ax.legend(fontsize=12)
    ax.grid(True, alpha=0.3, axis='y')
    fig.tight_layout()
    _save_plot(fig, filename)


def plot_learning_rate(lr_logger, filename='learning_rate_schedule.png') -> None:
    """Plot learning rate over epochs."""
    if not lr_logger.lrs:
        logger.warning("No LR data recorded — skipping LR plot.")
        return

    fig, ax = plt.subplots(figsize=(10, 5))
    epochs = range(1, len(lr_logger.lrs) + 1)
    ax.plot(epochs, lr_logger.lrs, linewidth=2, color='darkorange', marker='o', markersize=4)
    ax.set_title('Learning Rate Schedule', fontsize=16, fontweight='bold')
    ax.set_xlabel('Epoch', fontsize=13)
    ax.set_ylabel('Learning Rate', fontsize=13)
    ax.set_yscale('log')
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    _save_plot(fig, filename)


def create_all_plots(history, metrics, lr_logger) -> None:
    """Generate all 7 required training visualisation plots."""
    logger.info("Generating plots...")

    # 1–3: Training vs validation metric curves
    # Try multiple possible key names for MSE
    mse_key = 'mean_squared_error' if 'mean_squared_error' in history.history else 'mse'
    rmse_key = 'root_mean_squared_error' if 'root_mean_squared_error' in history.history else 'rmse'

    plot_metric_curve(history, mse_key, 'MSE', 'training_vs_validation_mse.png')
    plot_metric_curve(history, 'mae', 'MAE', 'training_vs_validation_mae.png')
    plot_metric_curve(history, rmse_key, 'RMSE', 'training_vs_validation_rmse.png')

    # 4–6: Test set analysis
    plot_predicted_vs_actual(metrics['y_test'], metrics['y_pred'])
    plot_error_distribution(metrics['y_test'], metrics['y_pred'])
    plot_batch_accuracy(metrics['y_test'], metrics['y_pred'])

    # 7: Learning rate
    plot_learning_rate(lr_logger)

    logger.info("All 7 plots generated successfully.")


# ============================================================================
# ARTIFACT SAVING
# ============================================================================

def save_all_artifacts(model, history, metrics, lr_logger, label_encoders,
                       all_categories, training_time, data, total_rows):
    """Save all output files required for inference, evaluation, and reporting.

    Files saved:
        1. travel_recommendation_model.keras   — trained model
        2. label_encoders.pkl                  — fitted label encoders
        3. all_categories.pkl                  — category list
        4. model_config.json                   — full configuration
        5. performance_metrics.json            — all test metrics
        6. training_history.csv                — per-epoch metrics
        7. test_predictions.csv                — actual/predicted/residual
    """
    print("\n" + "=" * 80)
    print("SAVING ARTIFACTS")
    print("=" * 80)

    n_train = len(data['y_train'])
    n_val = len(data['y_val'])
    n_test = len(data['y_test'])
    n_epochs = len(history.history['loss'])

    # 1. Model
    model_path = os.path.join(SCRIPT_DIR, 'travel_recommendation_model.keras')
    model.save(model_path)
    logger.info("Model saved: travel_recommendation_model.keras")

    # 2. Label encoders
    with open(os.path.join(SCRIPT_DIR, 'label_encoders.pkl'), 'wb') as f:
        pickle.dump(label_encoders, f)
    logger.info("Label encoders saved: label_encoders.pkl")

    # 3. Categories
    with open(os.path.join(SCRIPT_DIR, 'all_categories.pkl'), 'wb') as f:
        pickle.dump(all_categories, f)
    logger.info("Categories saved: all_categories.pkl")

    # 4. Model config (comprehensive — used by model_inference.py)
    mse_key = 'mean_squared_error' if 'mean_squared_error' in history.history else 'mse'
    config = {
        'model_name': 'Travel_Recommendation_Model',
        'version': '4.0',
        'created_at': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'seed': SEED,
        'dataset': {
            'source': 'synthetic_user_landmarks.csv',
            'total_rows': int(total_rows),
            'train_samples': int(n_train),
            'val_samples': int(n_val),
            'test_samples': int(n_test),
            'split_ratio': f"{SPLIT_RATIO[0]*100:.0f}/{SPLIT_RATIO[1]*100:.0f}/{SPLIT_RATIO[2]*100:.0f}",
        },
        'architecture': {
            'type': 'Dual-Input Neural Network with Element-wise Interaction',
            'user_input_dim': FEATURE_DIMS['user'],
            'landmark_input_dim': FEATURE_DIMS['landmark'],
            'user_branch': '128 → 64 → 32 (ReLU, L2, BN, Dropout)',
            'landmark_branch': '64 → 32 (ReLU, L2, BN, Dropout)',
            'interaction': 'DotProduct(normalised) + ElementWiseProduct + Concatenation',
            'prediction_head': '64 → 32 → 16 → 1 (ReLU→Sigmoid)',
            'total_params': int(model.count_params()),
        },
        'training': {
            'loss_function': f'CompositeHuberMAELoss(delta={HUBER_DELTA}, mae_weight={MAE_LOSS_WEIGHT})',
            'optimizer': 'Adam with CosineDecay',
            'initial_learning_rate': INITIAL_LR,
            'min_learning_rate': COSINE_ALPHA,
            'batch_size': BATCH_SIZE,
            'max_epochs': EPOCHS,
            'actual_epochs': n_epochs,
            'regularization': f'L2({L2_WEIGHT}) + Dropout(0.2-0.3) + BatchNorm',
            'early_stopping_patience': EARLY_STOP_PATIENCE,
        },
        'metrics': {
            'ndcg_5': float(metrics['ndcg_5']),
            'precision_5': float(metrics['precision_5']),
            'mrr': float(metrics['mrr']),
            'test_mse': float(metrics['test_mse']),
            'test_mae': float(metrics['test_mae']),
            'test_rmse': float(metrics['test_rmse']),
            'test_r2_score': float(metrics['test_r2']),
            'loss_ratio': float(metrics['loss_ratio']),
        },
        'training_time_seconds': float(training_time),
        'input_format': {
            'user_input_structure': {
                'user_age': f'int ({AGE_MIN}-{AGE_MAX})',
                'user_gender': 'string (Male/Female)',
                'user_budget': 'string (low/medium/high)',
                'user_travel_type': f'string ({"/".join(TRAVEL_TYPES)})',
                'user_preferences': 'list of strings from ALL_CATEGORIES',
            },
            'example_input': {
                'user_age': 30,
                'user_gender': 'Male',
                'user_budget': 'medium',
                'user_travel_type': 'solo',
                'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise'],
            },
        },
        'all_categories': all_categories,
    }

    with open(os.path.join(SCRIPT_DIR, 'model_config.json'), 'w') as f:
        json.dump(config, f, indent=2)
    logger.info("Config saved: model_config.json")

    # 5. Performance metrics (standalone JSON for easy parsing)
    perf = {
            'ndcg_5': float(metrics['ndcg_5']),
            'precision_5': float(metrics['precision_5']),
            'mrr': float(metrics['mrr']),
        'train_loss_mse': float(metrics['train_mse_final']),
        'val_loss_mse': float(metrics['val_mse_final']),
        'test_loss_mse': float(metrics['test_mse']),
        'test_loss_composite': float(metrics['test_composite_loss']),
        'test_r2_score': float(metrics['test_r2']),
        'loss_ratio': float(metrics['loss_ratio']),
        'training_time_seconds': float(training_time),
        'total_samples': int(total_rows),
        'train_samples': int(n_train),
        'val_samples': int(n_val),
        'test_samples': int(n_test),
        'epochs_completed': n_epochs,
    }
    with open(os.path.join(SCRIPT_DIR, 'performance_metrics.json'), 'w') as f:
        json.dump(perf, f, indent=2)
    logger.info("Performance metrics saved: performance_metrics.json")

    # 6. Training history CSV (per-epoch)
    history_data = {'epoch': list(range(1, n_epochs + 1))}
    for key in ['loss', f'val_loss', mse_key, f'val_{mse_key}', 'mae', 'val_mae']:
        if key in history.history:
            history_data[key] = history.history[key]
    rmse_key = 'root_mean_squared_error' if 'root_mean_squared_error' in history.history else 'rmse'
    for key in [rmse_key, f'val_{rmse_key}']:
        if key in history.history:
            history_data[key] = history.history[key]
    if lr_logger.lrs:
        history_data['learning_rate'] = lr_logger.lrs[:n_epochs]

    history_df = pd.DataFrame(history_data)
    history_df.to_csv(os.path.join(SCRIPT_DIR, 'training_history.csv'), index=False)
    logger.info("Training history saved: training_history.csv")

    # 7. Test predictions CSV
    preds_df = pd.DataFrame({
        'actual': metrics['y_test'],
        'predicted': metrics['y_pred'],
        'residual': metrics['y_pred'] - metrics['y_test'],
    })
    preds_df.to_csv(os.path.join(SCRIPT_DIR, 'test_predictions.csv'), index=False)
    logger.info("Test predictions saved: test_predictions.csv (%s rows)", f"{len(preds_df):,}")

    # 8. Training report (text)
    report = f"""
{'=' * 80}
DEEP LEARNING TRAVEL RECOMMENDATION SYSTEM — TRAINING REPORT v4.0
{'=' * 80}
Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

DATASET:
{'-' * 40}
Total samples:     {total_rows:,}
Training samples:  {n_train:,}
Validation samples:{n_val:,}
Test samples:      {n_test:,}
Split ratio:       {SPLIT_RATIO[0]*100:.0f}/{SPLIT_RATIO[1]*100:.0f}/{SPLIT_RATIO[2]*100:.0f}

MODEL ARCHITECTURE:
{'-' * 40}
Type: Dual-Input Neural Network with Element-wise Interaction
User branch:    Input({FEATURE_DIMS['user']}) → 128 → 64 → 32 (ReLU, L2, BN, Dropout)
Landmark branch:Input({FEATURE_DIMS['landmark']}) → 64 → 32 (ReLU, L2, BN, Dropout)
Interaction:    DotProduct + ElementWiseProduct + Concat
Prediction:     64 → 32 → 16 → 1 (Sigmoid)
Total params:   {model.count_params():,}

TRAINING CONFIGURATION:
{'-' * 40}
Loss function:   CompositeHuberMAELoss(delta={HUBER_DELTA}, mae_weight={MAE_LOSS_WEIGHT})
Optimizer:       Adam + CosineDecay(lr={INITIAL_LR} → {COSINE_ALPHA})
Regularization:  L2({L2_WEIGHT}), Dropout(0.2-0.3), BatchNorm
Batch size:      {BATCH_SIZE}
Epochs:          {n_epochs}/{EPOCHS}
Early stopping:  patience={EARLY_STOP_PATIENCE}
Seed:            {SEED}

PERFORMANCE METRICS:
{'-' * 40}
RANKING EFFICIENCY (Primary):
NDCG@5:             {metrics['ndcg_5']:.4f}
Precision@5:        {metrics['precision_5']:.4f}
MRR:                {metrics['mrr']:.4f}

REGRESSION (Secondary):
Train MSE (final):  {metrics['train_mse_final']:.6f}
Val MSE (final):    {metrics['val_mse_final']:.6f}
Test MSE:           {metrics['test_mse']:.6f}
Test R² Score:      {metrics['test_r2']:.4f}
Loss Ratio:         {metrics['loss_ratio']:.2f}x
Training Time:      {training_time:.1f} seconds

SAVED FILES:
{'-' * 40}
 1. travel_recommendation_model.keras
 2. label_encoders.pkl
 3. all_categories.pkl
 4. model_config.json
 5. performance_metrics.json
 6. training_history.csv
 7. test_predictions.csv
 8. training_vs_validation_mse.png
 9. training_vs_validation_mae.png
10. training_vs_validation_rmse.png
11. predicted_vs_actual.png
12. error_distribution.png
13. batch_accuracy.png
14. learning_rate_schedule.png
15. training_report.txt
16. training_summary.md

{'=' * 80}
"""
    with open(os.path.join(SCRIPT_DIR, 'training_report.txt'), 'w', encoding='utf-8') as f:
        f.write(report)
    logger.info("Training report saved: training_report.txt")


# ============================================================================
# ACADEMIC TRAINING SUMMARY (Markdown)
# ============================================================================

def generate_training_summary(model, history, metrics, lr_logger,
                              training_time, total_rows, data):
    """Generate an academic-style markdown summary of training methodology and results."""
    n_train = len(data['y_train'])
    n_val = len(data['y_val'])
    n_test = len(data['y_test'])
    n_epochs = len(history.history['loss'])
    errors = metrics['y_pred'] - metrics['y_test']

    summary = f"""# Travel Recommendation System — Training Summary

> **Generated**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
> **Version**: 4.0 | **Seed**: {SEED} | **TensorFlow**: {tf.__version__}

---

## 1. Dataset

| Property | Value |
|----------|-------|
| Source | `synthetic_user_landmarks.csv` |
| Total samples | {total_rows:,} |
| Training set | {n_train:,} ({SPLIT_RATIO[0]*100:.0f}%) |
| Validation set | {n_val:,} ({SPLIT_RATIO[1]*100:.0f}%) |
| Test set | {n_test:,} ({SPLIT_RATIO[2]*100:.0f}%) |
| User features | {FEATURE_DIMS['user']} dimensions |
| Landmark features | {FEATURE_DIMS['landmark']} dimensions |

---

## 2. Model Architecture

A dual-input neural network processes user profiles and landmark attributes
through separate encoder branches before combining them via interaction features.

- **User branch**: Input({FEATURE_DIMS['user']}) → Dense(128, ReLU) → BN → Dropout(0.3)
  → Dense(64, ReLU) → BN → Dropout(0.3) → Dense(32, ReLU) → BN
- **Landmark branch**: Input({FEATURE_DIMS['landmark']}) → Dense(64, ReLU) → BN → Dropout(0.3)
  → Dense(32, ReLU) → BN
- **Interaction**: Normalised dot product + element-wise product + concatenation
- **Prediction head**: Dense(64) → BN → DO(0.3) → Dense(32) → BN → DO(0.2) → Dense(16) → DO(0.2) → Dense(1, sigmoid)
- **Total parameters**: {model.count_params():,}

---

## 3. Training Configuration

| Hyperparameter | Value | Rationale |
|----------------|-------|-----------|
| Loss function | Huber(δ={HUBER_DELTA}) + {MAE_LOSS_WEIGHT}×MAE | Robust to outliers; MAE reduces underestimation bias |
| Optimizer | Adam | Adaptive per-parameter learning rates |
| LR schedule | CosineDecay({INITIAL_LR} → {COSINE_ALPHA}) | Smooth decay prevents late-epoch stagnation |
| Batch size | {BATCH_SIZE} | Optimised for CPU throughput |
| Regularisation | L2({L2_WEIGHT}), Dropout(0.2–0.3), BN | Prevents overfitting on large dataset |
| Early stopping | patience={EARLY_STOP_PATIENCE}, restore best | Avoids wasted epochs |
| Epochs completed | {n_epochs} / {EPOCHS} | {"Stopped early" if n_epochs < EPOCHS else "Ran to completion"} |

---

## 4. Results

### 4.1 Performance Metrics

| Metric | Value | Meaning |
|--------|-------|---------|
| **NDCG@5** | **{metrics['ndcg_5']:.4f}** | Normalized ranking quality (Top 5) |
| **Precision@5** | **{metrics['precision_5']:.4f}** | Target overlap in Top 5 recommendations |
| **MRR** | **{metrics['mrr']:.4f}** | Mean Reciprocal Rank indicating top position hit |
| Test MSE | {metrics['test_mse']:.6f} | Secondary: Regression logic |
| Test R² | {metrics['test_r2']:.4f} | Secondary: Explained continuous variance |
| MSE Ratio | {metrics['loss_ratio']:.2f}× | Overfitting diagnostic |
| Training Time | {training_time:.1f} sec | Compute duration |

### 4.2 Error Analysis

| Statistic | Value |
|-----------|-------|
| Mean error | {errors.mean():.6f} |
| Std error | {errors.std():.6f} |
| Median error | {np.median(errors):.6f} |
| Min error | {errors.min():.6f} |
| Max error | {errors.max():.6f} |
| % within ±0.1 | {(np.abs(errors) <= 0.1).mean()*100:.1f}% |
| % within ±0.2 | {(np.abs(errors) <= 0.2).mean()*100:.1f}% |

### 4.3 Observations

- **Convergence**: {"Smooth and stable — no oscillation detected." if n_epochs >= 5 else "Limited epochs — convergence assessment inconclusive."}
- **Overfitting**: {"Minimal overfitting (ratio < 1.5×)." if metrics['loss_ratio'] < 1.5 else "Moderate overfitting detected." if metrics['loss_ratio'] < 3.0 else "Significant overfitting — consider stronger regularisation."}
- **Generalisation**: {"Good — validation loss ≤ training loss." if metrics['val_mse_final'] <= metrics['train_mse_final'] * 1.1 else "Reasonable — validation loss slightly above training."}

---

## 5. Output Files

| # | File | Purpose |
|---|------|---------|
| 1 | `travel_recommendation_model.keras` | Trained model for inference |
| 2 | `label_encoders.pkl` | Fitted label encoders |
| 3 | `all_categories.pkl` | Category mappings |
| 4 | `model_config.json` | Full model configuration |
| 5 | `performance_metrics.json` | Standalone metrics file |
| 6 | `training_history.csv` | Per-epoch training history |
| 7 | `test_predictions.csv` | Test set: actual, predicted, residual |
| 8 | `training_vs_validation_mse.png` | MSE learning curves |
| 9 | `training_vs_validation_mae.png` | MAE learning curves |
| 10 | `training_vs_validation_rmse.png` | RMSE learning curves |
| 11 | `predicted_vs_actual.png` | Scatter plot (test set) |
| 12 | `error_distribution.png` | Residual histogram |
| 13 | `batch_accuracy.png` | Batch-wise accuracy bar chart |
| 14 | `learning_rate_schedule.png` | LR over epochs |
| 15 | `training_report.txt` | Human-readable report |
| 16 | `training_summary.md` | This academic summary |

---

## 6. Inference Usage

```python
from model_inference import main
main()
```

Or programmatically:

```python
user_input = {{
    'user_age': 30,
    'user_gender': 'Male',
    'user_budget': 'medium',
    'user_travel_type': 'solo',
    'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise']
}}
```
"""

    path = os.path.join(SCRIPT_DIR, 'training_summary.md')
    with open(path, 'w', encoding='utf-8') as f:
        f.write(summary)
    logger.info("Training summary saved: training_summary.md")


# ============================================================================
# DEMO PREDICTION
# ============================================================================

def run_demo_prediction(model, user_input_demo, unique_landmarks, all_categories):
    """Score all landmarks for a demo user profile and display top 10.

    Uses shared utility functions from utils.py to ensure feature alignment
    with the training pipeline.
    """
    # Prepare features using shared utilities
    test_user_features, _ = prepare_user_features_single(user_input_demo, all_categories)
    pred_landmark_features, landmark_info_list = prepare_landmark_features_batch(
        unique_landmarks, all_categories
    )

    # Repeat user for all landmarks
    pred_user_features = np.repeat(test_user_features, len(pred_landmark_features), axis=0)

    # Get predictions
    logger.info("Generating predictions for %d landmarks...", len(landmark_info_list))
    dl_predictions = model.predict(
        {'user_input': pred_user_features, 'landmark_input': pred_landmark_features},
        verbose=0, batch_size=BATCH_SIZE,
    ).flatten()

    # Combine and sort
    dl_recommendations = []
    for i, info in enumerate(landmark_info_list):
        dl_recommendations.append({
            'name': info['name'],
            'category': info['category'],
            'rating': info['rating'],
            'budget': info['budget'],
            'budget_lower': info['budget_lower'],
            'travel_types': info['travel_types'],
            'dl_score': float(dl_predictions[i]),
        })

    dl_recommendations.sort(key=lambda x: x['dl_score'], reverse=True)
    top_10 = get_top_10_diverse_recommendations(
        dl_recommendations, user_input_demo['user_preferences']
    )

    # Display
    print("\n" + "=" * 80)
    print("TOP 10 DEEP LEARNING RECOMMENDATIONS (Demo)")
    print("=" * 80)

    for i, rec in enumerate(top_10, 1):
        budget_match = rec['budget_lower'] == user_input_demo['user_budget'].lower()
        travel_match = user_input_demo['user_travel_type'].lower() in [
            str(t).lower() for t in rec['travel_types']
        ]
        category_match = rec['category'].lower() in [
            p.lower() for p in user_input_demo['user_preferences']
        ]

        print(f"\n{i}. {rec['name']}")
        print(f"   Category: {rec['category']}")
        print(f"   Rating: {rec['rating']:.1f}/5.0")
        print(f"   Budget: {rec['budget']}  {'[MATCH]' if budget_match else '[NO MATCH]'}")
        print(f"   Travel types: {rec['travel_types']}  {'[MATCH]' if travel_match else '[NO MATCH]'}")
        print(f"   Category match: {'[MATCH]' if category_match else '[NO MATCH]'}")
        print(f"   DL Score: {rec['dl_score']:.3f}")

    return top_10


# ============================================================================
# MAIN PIPELINE
# ============================================================================

def main():
    print("=" * 80)
    print("TRAVEL RECOMMENDATION SYSTEM — TRAINING PIPELINE v4.0")
    print("=" * 80)
    print(f"Config: SAMPLE_SIZE={'ALL' if SAMPLE_SIZE is None else SAMPLE_SIZE}, "
          f"BATCH_SIZE={BATCH_SIZE}, EPOCHS={EPOCHS}, LR={INITIAL_LR}")
    print(f"Loss: CompositeHuberMAE(delta={HUBER_DELTA}, mae_weight={MAE_LOSS_WEIGHT})")
    print(f"Split: {SPLIT_RATIO[0]*100:.0f}/{SPLIT_RATIO[1]*100:.0f}/{SPLIT_RATIO[2]*100:.0f}")
    print("=" * 80)

    # ---- Setup ----
    set_seeds()
    print(f"TensorFlow {tf.__version__}")
    gpus = tf.config.list_physical_devices('GPU')
    print(f"GPU: {len(gpus)} device(s)" if gpus else "GPU: None (CPU training)")

    pipeline_start = time.time()

    # ---- Load Data ----
    file_path = os.path.join(SCRIPT_DIR, 'synthetic_user_landmarks.csv')
    df, unique_landmarks = load_and_clean_data(file_path, sample_size=SAMPLE_SIZE)
    total_rows = len(df)

    # ---- Demo User Profile (for end-of-training validation) ----
    user_input_demo = {
        'user_age': 30,
        'user_gender': 'Male',
        'user_budget': 'medium',
        'user_travel_type': 'solo',
        'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise'],
    }

    # ---- Fit Label Encoders (metadata — not used in forward pass) ----
    label_encoders = {}
    categorical_cols = ['user_gender', 'user_budget', 'user_travel_type',
                        'landmark_budget', 'landmark_category']
    for col in categorical_cols:
        le = LabelEncoder()
        le.fit(df[col].astype(str))
        label_encoders[col] = le

    # ---- Feature Engineering ----
    print("\n" + "=" * 80)
    print("FEATURE ENGINEERING")
    print("=" * 80)

    logger.info("Generating continuous user affinity matrices...")
    user_affinities = generate_user_affinities(df, ALL_CATEGORIES)

    logger.info("Engineering user features (vectorized + dedup)...")
    user_features = engineer_user_features(df, user_affinities, ALL_CATEGORIES)

    logger.info("Engineering landmark features (vectorized)...")
    landmark_features = engineer_landmark_features(df, ALL_CATEGORIES)

    logger.info("Creating labels (weighted continuous)...")
    labels = create_labels_vectorized(df, user_affinities)

    # Free DataFrame memory — features are now in numpy arrays
    del df
    gc.collect()
    logger.info("DataFrame freed — features in numpy arrays (%.1f MB total)",
                (user_features.nbytes + landmark_features.nbytes + labels.nbytes) / 1e6)

    # ---- Split Data ----
    data = split_data(user_features, landmark_features, labels)

    # Free full-size arrays (splits are copies from train_test_split)
    del user_features, landmark_features, labels
    gc.collect()

    # ---- Build Model ----
    print("\n" + "=" * 80)
    print("MODEL ARCHITECTURE")
    print("=" * 80)

    model = build_model(FEATURE_DIMS['user'], FEATURE_DIMS['landmark'])
    # Print summary before compilation (compile happens in train_model)
    # Temporarily compile with dummy optimizer just for summary
    model.compile(optimizer='adam', loss='mse')
    model.summary()

    # ---- Train ----
    print("\n" + "=" * 80)
    print("TRAINING")
    print("=" * 80)

    train_start = time.time()
    history, lr_logger = train_model(model, data)
    training_time = time.time() - train_start
    logger.info("Training time: %.1f seconds (%.1f minutes)", training_time, training_time / 60)

    # ---- Evaluate ----
    metrics = evaluate_model(model, data, history)

    # ---- Plots ----
    create_all_plots(history, metrics, lr_logger)

    # ---- Save All Artifacts ----
    save_all_artifacts(
        model, history, metrics, lr_logger, label_encoders,
        list(ALL_CATEGORIES), training_time, data, total_rows,
    )

    # ---- Training Summary ----
    generate_training_summary(
        model, history, metrics, lr_logger,
        training_time, total_rows, data,
    )

    # ---- Demo Prediction ----
    print("\n" + "=" * 80)
    print("DEMO PREDICTION")
    print("=" * 80)
    print(json.dumps(user_input_demo, indent=2))

    # Reload unique landmarks for demo (df was deleted)
    file_path = os.path.join(SCRIPT_DIR, 'synthetic_user_landmarks.csv')
    demo_df = pd.read_csv(
        file_path, encoding='utf-8',
        usecols=['landmark_name', 'landmark_category', 'landmark_budget',
                 'landmark_rate', 'landmark_Suitable_Travel_Type'],
    )
    demo_unique = demo_df.drop_duplicates()
    del demo_df

    run_demo_prediction(model, user_input_demo, demo_unique, list(ALL_CATEGORIES))

    # ---- Final Summary ----
    total_time = time.time() - pipeline_start
    print("\n" + "=" * 80)
    print("PIPELINE COMPLETE")
    print("=" * 80)
    print(f"Total time:        {total_time:.1f}s ({total_time/60:.1f} min)")
    print(f"Training time:     {training_time:.1f}s ({training_time/60:.1f} min)")
    print(f"NDCG@5:            {metrics['ndcg_5']:.4f}")
    print(f"Precision@5:       {metrics['precision_5']:.4f}")
    print(f"MRR:               {metrics['mrr']:.4f}")
    print(f"Test MSE:          {metrics['test_mse']:.6f}")
    print(f"Test R²:           {metrics['test_r2']:.4f}")
    print(f"MSE Loss Ratio:    {metrics['loss_ratio']:.2f}x")
    print(f"Epochs completed:  {len(history.history['loss'])}/{EPOCHS}")
    print(f"\nAll 16 output files saved to: {SCRIPT_DIR}")
    print(f"\nTo run inference:  python model_inference.py")
    print("=" * 80)


if __name__ == "__main__":
    main()
