# Travel Recommendation System — Training Summary

> **Generated**: 2026-04-21 23:37:48
> **Version**: 4.0 | **Seed**: 42 | **TensorFlow**: 2.21.0

---

## 1. Dataset

| Property | Value |
|----------|-------|
| Source | `synthetic_user_landmarks.csv` |
| Total samples | 5,000,000 |
| Training set | 3,500,000 (70%) |
| Validation set | 750,000 (15%) |
| Test set | 750,000 (15%) |
| User features | 39 dimensions |
| Landmark features | 31 dimensions |

---

## 2. Model Architecture

A dual-input neural network processes user profiles and landmark attributes
through separate encoder branches before combining them via interaction features.

- **User branch**: Input(39) → Dense(128, ReLU) → BN → Dropout(0.3)
  → Dense(64, ReLU) → BN → Dropout(0.3) → Dense(32, ReLU) → BN
- **Landmark branch**: Input(31) → Dense(64, ReLU) → BN → Dropout(0.3)
  → Dense(32, ReLU) → BN
- **Interaction**: Normalised dot product + element-wise product + concatenation
- **Prediction head**: Dense(64) → BN → DO(0.3) → Dense(32) → BN → DO(0.2) → Dense(16) → DO(0.2) → Dense(1, sigmoid)
- **Total parameters**: 30,145

---

## 3. Training Configuration

| Hyperparameter | Value | Rationale |
|----------------|-------|-----------|
| Loss function | Huber(δ=0.5) + 0.1×MAE | Robust to outliers; MAE reduces underestimation bias |
| Optimizer | Adam | Adaptive per-parameter learning rates |
| LR schedule | CosineDecay(0.0003 → 1e-05) | Smooth decay prevents late-epoch stagnation |
| Batch size | 512 | Optimised for CPU throughput |
| Regularisation | L2(0.001), Dropout(0.2–0.3), BN | Prevents overfitting on large dataset |
| Early stopping | patience=8, restore best | Avoids wasted epochs |
| Epochs completed | 30 / 30 | Ran to completion |

---

## 4. Results

### 4.1 Performance Metrics

| Metric | Value | Meaning |
|--------|-------|---------|
| **NDCG@5** | **0.9536** | Normalized ranking quality (Top 5) |
| **Precision@5** | **0.6243** | Target overlap in Top 5 recommendations |
| **MRR** | **0.4295** | Mean Reciprocal Rank indicating top position hit |
| Test MSE | 0.004468 | Secondary: Regression logic |
| Test R² | 0.8020 | Secondary: Explained continuous variance |
| MSE Ratio | 1.17× | Overfitting diagnostic |
| Training Time | 1433.6 sec | Compute duration |

### 4.2 Error Analysis

| Statistic | Value |
|-----------|-------|
| Mean error | 0.010486 |
| Std error | 0.066012 |
| Median error | 0.005854 |
| Min error | -0.326136 |
| Max error | 0.470768 |
| % within ±0.1 | 90.7% |
| % within ±0.2 | 98.4% |

### 4.3 Observations

- **Convergence**: Smooth and stable — no oscillation detected.
- **Overfitting**: Minimal overfitting (ratio < 1.5×).
- **Generalisation**: Good — validation loss ≤ training loss.

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
user_input = {
    'user_age': 30,
    'user_gender': 'Male',
    'user_budget': 'medium',
    'user_travel_type': 'solo',
    'user_preferences': ['Museum', 'Pharaonic Site', 'Islamic Monument', 'Nile Cruise']
}
```
