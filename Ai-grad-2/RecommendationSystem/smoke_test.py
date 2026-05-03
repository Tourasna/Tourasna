"""Quick smoke test for the training pipeline — uses 5000 samples, 2 epochs."""
import os
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'

import travel_recommendation_training as t

# Override config for speed
t.SAMPLE_SIZE = 5000
t.EPOCHS = 2
t.BATCH_SIZE = 64
t.EARLY_STOP_PATIENCE = 2

t.set_seeds()

# Load tiny sample
df, ul = t.load_and_clean_data(
    os.path.join(t.SCRIPT_DIR, 'synthetic_user_landmarks.csv'),
    sample_size=5000,
)
print(f'Loaded {len(df)} rows')

# Feature engineering
user_affinities = t.generate_user_affinities(df)
uf = t.engineer_user_features(df, user_affinities)
lf = t.engineer_landmark_features(df)
labels = t.create_labels_vectorized(df, user_affinities)
print(f'Features: user={uf.shape}, landmark={lf.shape}, labels={labels.shape}')

# Split, build, train
data = t.split_data(uf, lf, labels)
model = t.build_model(t.FEATURE_DIMS['user'], t.FEATURE_DIMS['landmark'])
history, lr_log = t.train_model(model, data, epochs=2, batch_size=64)

# Evaluate
metrics = t.evaluate_model(model, data, history)

print(f'\nTest MSE:  {metrics["test_mse"]:.6f}')
print(f'Test R2:   {metrics["test_r2"]:.4f}')
print(f'LR points: {len(lr_log.lrs)}')

# Test plotting (just one plot to verify)
t.plot_predicted_vs_actual(metrics['y_test'], metrics['y_pred'], 'smoke_test_scatter.png')
print(f'Plot saved: smoke_test_scatter.png')

# Clean up
os.remove(os.path.join(t.SCRIPT_DIR, 'smoke_test_scatter.png'))
print('\nSMOKE TEST PASSED')
