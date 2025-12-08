import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.preprocessing import LabelEncoder, MinMaxScaler
import ast
import warnings
import os
import json
warnings.filterwarnings('ignore')

# Check if TensorFlow is using GPU
print("TensorFlow version:", tf.__version__)
print("GPU Available:", tf.config.list_physical_devices('GPU'))

def parse_list_string(list_str):
    """Parse string representation of list into actual list"""
    try:
        if pd.isna(list_str):
            return []
        # Remove brackets and quotes, then split
        if isinstance(list_str, str):
            # Try to parse as JSON/list
            if list_str.startswith('[') and list_str.endswith(']'):
                try:
                    return ast.literal_eval(list_str)
                except:
                    # Manual parsing
                    list_str = list_str.strip('[]').replace('"', '').replace("'", "")
                    return [item.strip() for item in list_str.split(',') if item.strip()]
            else:
                return [list_str.strip()]
        elif isinstance(list_str, list):
            return list_str
        else:
            return []
    except:
        return []

def calculate_landmark_score(landmark, user_input):
    """Calculate comprehensive score for a landmark"""
    score = 0
    max_score = 100
    
    # 1. Budget match (30 points)
    landmark_budget = str(landmark.get('landmark_budget', '')).lower()
    user_budget = user_input['user_budget'].lower()
    if landmark_budget == user_budget:
        score += 30
    
    # 2. Travel type compatibility (30 points)
    travel_types_str = landmark.get('landmark_Suitable_Travel_Type', '')
    travel_types = parse_list_string(travel_types_str)
    travel_types = [str(t).lower().strip() for t in travel_types]
    user_travel_type = user_input['user_travel_type'].lower()
    if user_travel_type in travel_types:
        score += 30
    
    # 3. Category preference match (20 points)
    landmark_category = str(landmark.get('landmark_category', '')).strip()
    user_preferences = [p.strip() for p in user_input['user_preferences']]
    if landmark_category in user_preferences:
        score += 20
    
    # 4. Rating (20 points max)
    try:
        rating = float(landmark.get('landmark_rate', 0))
        # Convert 1-5 rating to 0-20 points
        rating_points = (rating - 1) * 5
        score += min(20, max(0, rating_points))
    except:
        pass
    
    return score

def main():
    print("=" * 80)
    print("DEEP LEARNING TRAVEL RECOMMENDATION SYSTEM")
    print("=" * 80)
    
    # Get the current directory
    current_dir = os.path.dirname(os.path.abspath(__file__))
    file_path = os.path.join(current_dir, 'user_landmark_matches_1M.xls')
    
    print(f"Loading data from: {file_path}")
    
    try:
        # Read the data
        df = pd.read_csv(file_path, encoding='utf-8')
        print(f"\nSuccessfully loaded {len(df)} rows")
        print(f"Columns: {df.columns.tolist()}")
        
        # Show sample
        print("\nFirst 2 rows of data:")
        print(df.head(2))
        
        # Clean data
        print("\nCleaning data...")
        
        # Convert numeric columns
        df['user_age'] = pd.to_numeric(df['user_age'], errors='coerce')
        df['landmark_rate'] = pd.to_numeric(df['landmark_rate'], errors='coerce')
        
        # Fill missing values
        df['user_age'] = df['user_age'].fillna(df['user_age'].median())
        df['landmark_rate'] = df['landmark_rate'].fillna(df['landmark_rate'].median())
        
        # Take a sample for faster processing
        sample_size = min(50000, len(df))
        print(f"\nUsing {sample_size} rows for processing...")
        df_sample = df.sample(sample_size, random_state=42)
        
        # Get unique landmarks
        unique_landmarks = df_sample[['landmark_name', 'landmark_category', 'landmark_budget', 
                                     'landmark_rate', 'landmark_Suitable_Travel_Type']].drop_duplicates()
        print(f"\nFound {len(unique_landmarks)} unique landmarks")
        
        # User input
        user_input = {
            'user_age': 25,
            'user_gender': 'Male',
            'user_budget': 'medium',
            'user_travel_type': 'solo',
            'user_preferences': ['Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks']
        }
        
        print("\n" + "="*80)
        print("USER PROFILE")
        print("="*80)
        print(f"Age: {user_input['user_age']}")
        print(f"Gender: {user_input['user_gender']}")
        print(f"Budget: {user_input['user_budget']}")
        print(f"Travel Type: {user_input['user_travel_type']}")
        print(f"Preferences: {user_input['user_preferences']}")
        
        # Calculate scores for all landmarks
        print(f"\nCalculating scores for {len(unique_landmarks)} landmarks...")
        
        scored_landmarks = []
        for idx, landmark in unique_landmarks.iterrows():
            score = calculate_landmark_score(landmark, user_input)
            
            # Get travel types for display
            travel_types = parse_list_string(landmark['landmark_Suitable_Travel_Type'])
            
            scored_landmarks.append({
                'name': landmark['landmark_name'],
                'category': landmark['landmark_category'],
                'rating': float(landmark['landmark_rate']),
                'budget': landmark['landmark_budget'],
                'travel_types': travel_types,
                'score': score
            })
        
        # Sort by score (and secondary by rating for ties)
        scored_landmarks.sort(key=lambda x: (x['score'], x['rating']), reverse=True)
        
        # Get top recommendations - ensure diversity across categories
        print("\nSelecting diverse recommendations...")
        
        # Group by category to ensure diversity
        category_groups = {}
        for landmark in scored_landmarks:
            category = landmark['category']
            if category not in category_groups:
                category_groups[category] = []
            category_groups[category].append(landmark)
        
        # Select top from each preferred category first
        top_recommendations = []
        selected_names = set()
        
        # First, get top from each user-preferred category
        for preferred_category in user_input['user_preferences']:
            if preferred_category in category_groups:
                for landmark in category_groups[preferred_category]:
                    if landmark['name'] not in selected_names and len(top_recommendations) < 10:
                        top_recommendations.append(landmark)
                        selected_names.add(landmark['name'])
        
        # Fill remaining slots with highest scores from any category
        if len(top_recommendations) < 10:
            for landmark in scored_landmarks:
                if landmark['name'] not in selected_names and len(top_recommendations) < 10:
                    top_recommendations.append(landmark)
                    selected_names.add(landmark['name'])
        
        # Display recommendations
        print("\n" + "="*80)
        print("TOP 10 PERSONALIZED & DIVERSE RECOMMENDATIONS")
        print("="*80)
        
        for i, rec in enumerate(top_recommendations, 1):
            budget_match = rec['budget'].lower() == user_input['user_budget'].lower()
            travel_match = user_input['user_travel_type'].lower() in [str(t).lower() for t in rec['travel_types']]
            category_match = rec['category'] in user_input['user_preferences']
            
            print(f"\n{i}. {rec['name']}")
            print(f"   Category: {rec['category']}")
            print(f"   Rating: {rec['rating']:.1f}/5.0")
            print(f"   Budget: {rec['budget']} {'✓' if budget_match else '✗'}")
            print(f"   Suitable for: {rec['travel_types']}")
            print(f"   Travel type match: {'✓' if travel_match else '✗'}")
            print(f"   Category preference match: {'✓' if category_match else '✗'}")
            print(f"   Overall score: {rec['score']}/100")
        
        # Now let's create a better deep learning model
        print("\n" + "="*80)
        print("DEEP LEARNING MODEL TRAINING")
        print("="*80)
        
        # Prepare data for ML
        print("Preparing data for machine learning...")
        
        # Encode categorical features
        label_encoders = {}
        categorical_cols = ['user_gender', 'user_budget', 'user_travel_type',
                           'landmark_budget', 'landmark_category']
        
        for col in categorical_cols:
            le = LabelEncoder()
            df_sample[f'{col}_encoded'] = le.fit_transform(df_sample[col].astype(str))
            label_encoders[col] = le
            print(f"Encoded {col}: {len(le.classes_)} classes")
        
        # Create preference vectors
        all_categories = [
            'Fun & Games', 'Water & Amusement Parks', 'Outdoor Activities',
            'Concerts & Shows', 'Zoos & Aquariums', 'Shopping', 
            'Nature & Parks', 'Sights & Landmarks', 'Museums', 'Traveler Resources'
        ]
        
        # Parse preferences
        def encode_user_preferences(pref_str):
            pref_list = parse_list_string(pref_str)
            return [1 if cat in pref_list else 0 for cat in all_categories]
        
        pref_vectors = df_sample['user_preferences'].apply(encode_user_preferences)
        pref_matrix = np.array(pref_vectors.tolist())
        print(f"Preference matrix shape: {pref_matrix.shape}")
        
        # Create user features
        user_features_list = []
        for idx, row in df_sample.iterrows():
            features = []
            
            # Age (normalized)
            age = float(row['user_age'])
            age_norm = (age - 18) / (75 - 18)
            features.append(age_norm)
            
            # Gender (one-hot would be better, but encoded for simplicity)
            gender_val = row['user_gender_encoded'] / max(1, len(label_encoders['user_gender'].classes_) - 1)
            features.append(gender_val)
            
            # Budget
            budget_val = row['user_budget_encoded'] / max(1, len(label_encoders['user_budget'].classes_) - 1)
            features.append(budget_val)
            
            # Travel type
            travel_val = row['user_travel_type_encoded'] / max(1, len(label_encoders['user_travel_type'].classes_) - 1)
            features.append(travel_val)
            
            # Preferences
            features.extend(pref_matrix[idx])
            
            user_features_list.append(features)
        
        user_features = np.array(user_features_list)
        print(f"User features shape: {user_features.shape}")
        
        # Create landmark features
        landmark_features_list = []
        for idx, row in df_sample.iterrows():
            features = []
            
            # Category
            cat_val = row['landmark_category_encoded'] / max(1, len(label_encoders['landmark_category'].classes_) - 1)
            features.append(cat_val)
            
            # Budget
            lm_budget_val = row['landmark_budget_encoded'] / max(1, len(label_encoders['landmark_budget'].classes_) - 1)
            features.append(lm_budget_val)
            
            # Rating (normalized)
            rating = float(row['landmark_rate'])
            rating_norm = (rating - 1) / 4
            features.append(rating_norm)
            
            # Travel compatibility (will be calculated per user)
            features.append(0.0)  # Placeholder
            
            landmark_features_list.append(features)
        
        landmark_features = np.array(landmark_features_list)
        print(f"Landmark features shape: {landmark_features.shape}")
        
        # Create matching features and labels
        matching_features_list = []
        labels_list = []
        
        for idx, row in df_sample.iterrows():
            # Budget match
            budget_match = 1 if row['user_budget_encoded'] == row['landmark_budget_encoded'] else 0
            
            # Travel type match
            user_travel_type = row['user_travel_type']
            landmark_travel_types = parse_list_string(row['landmark_Suitable_Travel_Type'])
            travel_match = 1 if user_travel_type in landmark_travel_types else 0
            
            matching_features_list.append([budget_match, travel_match])
            
            # Create label based on compatibility
            label_score = 0
            if budget_match:
                label_score += 0.6
            if travel_match:
                label_score += 0.4
            
            # Add some noise for negative samples
            if label_score == 0:
                label_score = np.random.uniform(0, 0.2)
            
            labels_list.append(label_score)
        
        matching_features = np.array(matching_features_list)
        labels = np.array(labels_list)
        
        print(f"Matching features shape: {matching_features.shape}")
        print(f"Labels shape: {labels.shape}")
        
        # Build improved neural network
        print("\nBuilding improved neural network...")
        
        user_input_layer = layers.Input(shape=(user_features.shape[1],))
        landmark_input_layer = layers.Input(shape=(landmark_features.shape[1],))
        matching_input_layer = layers.Input(shape=(2,))
        
        # User network with more capacity for preferences
        user_dense1 = layers.Dense(128, activation='relu')(user_input_layer)
        user_dense2 = layers.Dense(64, activation='relu')(user_dense1)
        user_dense3 = layers.Dense(32, activation='relu')(user_dense2)
        
        # Landmark network
        landmark_dense1 = layers.Dense(64, activation='relu')(landmark_input_layer)
        landmark_dense2 = layers.Dense(32, activation='relu')(landmark_dense1)
        landmark_dense3 = layers.Dense(16, activation='relu')(landmark_dense2)
        
        # Combine
        combined = layers.Concatenate()([user_dense3, landmark_dense3, matching_input_layer])
        
        # Final layers with dropout for regularization
        dense1 = layers.Dense(64, activation='relu')(combined)
        dropout1 = layers.Dropout(0.2)(dense1)
        dense2 = layers.Dense(32, activation='relu')(dropout1)
        dropout2 = layers.Dropout(0.1)(dense2)
        dense3 = layers.Dense(16, activation='relu')(dropout2)
        output = layers.Dense(1, activation='sigmoid')(dense3)
        
        # Create model
        model = keras.Model(
            inputs=[user_input_layer, landmark_input_layer, matching_input_layer],
            outputs=output
        )
        
        # Compile
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='mse',
            metrics=['mae', 'accuracy']
        )
        
        print("\nModel summary:")
        model.summary()
        
        # Train on subset
        train_size = min(20000, len(user_features))
        print(f"\nTraining on {train_size} samples...")
        
        indices = np.random.choice(len(user_features), train_size, replace=False)
        
        X_user = user_features[indices]
        X_landmark = landmark_features[indices]
        X_matching = matching_features[indices]
        y = labels[indices]
        
        # Split
        from sklearn.model_selection import train_test_split
        X_user_train, X_user_val, X_landmark_train, X_landmark_val, \
        X_matching_train, X_matching_val, y_train, y_val = train_test_split(
            X_user, X_landmark, X_matching, y,
            test_size=0.2, random_state=42
        )
        
        # Train with callbacks
        callbacks = [
            keras.callbacks.EarlyStopping(patience=5, restore_best_weights=True),
            keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=3)
        ]
        
        history = model.fit(
            [X_user_train, X_landmark_train, X_matching_train], y_train,
            validation_data=([X_user_val, X_landmark_val, X_matching_val], y_val),
            epochs=20,
            batch_size=128,
            callbacks=callbacks,
            verbose=1
        )
        
        print("\nModel training completed!")
        
        # Generate DL recommendations
        print("\n" + "="*80)
        print("DEEP LEARNING RECOMMENDATIONS")
        print("="*80)
        
        # Create user feature vector for prediction
        test_user_features = []
        
        # Age
        age_norm = (user_input['user_age'] - 18) / (75 - 18)
        test_user_features.append(age_norm)
        
        # Gender
        try:
            gender_encoded = label_encoders['user_gender'].transform([user_input['user_gender']])[0]
            gender_val = gender_encoded / max(1, len(label_encoders['user_gender'].classes_) - 1)
        except:
            gender_val = 0.5
        test_user_features.append(gender_val)
        
        # Budget
        try:
            budget_encoded = label_encoders['user_budget'].transform([user_input['user_budget']])[0]
            budget_val = budget_encoded / max(1, len(label_encoders['user_budget'].classes_) - 1)
        except:
            budget_val = 0.5
        test_user_features.append(budget_val)
        
        # Travel type
        try:
            travel_encoded = label_encoders['user_travel_type'].transform([user_input['user_travel_type']])[0]
            travel_val = travel_encoded / max(1, len(label_encoders['user_travel_type'].classes_) - 1)
        except:
            travel_val = 0.5
        test_user_features.append(travel_val)
        
        # Preferences
        user_pref_vector = [1 if cat in user_input['user_preferences'] else 0 for cat in all_categories]
        test_user_features.extend(user_pref_vector)
        
        test_user_features = np.array([test_user_features])
        
        # Prepare all landmarks for prediction
        print(f"\nPreparing {len(unique_landmarks)} landmarks for prediction...")
        
        pred_landmark_features = []
        pred_matching_features = []
        landmark_info_list = []
        
        for _, landmark in unique_landmarks.iterrows():
            # Landmark features
            lm_features = []
            
            # Category
            try:
                cat_encoded = label_encoders['landmark_category'].transform([landmark['landmark_category']])[0]
                cat_val = cat_encoded / max(1, len(label_encoders['landmark_category'].classes_) - 1)
            except:
                cat_val = 0.5
            lm_features.append(cat_val)
            
            # Budget
            try:
                lm_budget_encoded = label_encoders['landmark_budget'].transform([landmark['landmark_budget']])[0]
                lm_budget_val = lm_budget_encoded / max(1, len(label_encoders['landmark_budget'].classes_) - 1)
            except:
                lm_budget_val = 0.5
            lm_features.append(lm_budget_val)
            
            # Rating
            rating = float(landmark['landmark_rate'])
            rating_norm = (rating - 1) / 4
            lm_features.append(rating_norm)
            
            # Travel compatibility
            travel_types = parse_list_string(landmark['landmark_Suitable_Travel_Type'])
            travel_comp = 1 if user_input['user_travel_type'] in travel_types else 0
            lm_features.append(travel_comp)
            
            pred_landmark_features.append(lm_features)
            
            # Matching features
            budget_match = 1 if landmark['landmark_budget'].lower() == user_input['user_budget'].lower() else 0
            pred_matching_features.append([budget_match, travel_comp])
            
            # Store landmark info
            landmark_info_list.append({
                'name': landmark['landmark_name'],
                'category': landmark['landmark_category'],
                'rating': float(landmark['landmark_rate']),
                'budget': landmark['landmark_budget'],
                'travel_types': travel_types
            })
        
        pred_landmark_features = np.array(pred_landmark_features)
        pred_matching_features = np.array(pred_matching_features)
        
        # Repeat user features for all landmarks
        pred_user_features = np.repeat(test_user_features, len(pred_landmark_features), axis=0)
        
        # Get predictions
        print("Generating deep learning predictions...")
        dl_predictions = model.predict(
            [pred_user_features, pred_landmark_features, pred_matching_features],
            verbose=0
        ).flatten()
        
        # Combine predictions with landmark info
        dl_recommendations = []
        for i, landmark_info in enumerate(landmark_info_list):
            dl_recommendations.append({
                'name': landmark_info['name'],
                'category': landmark_info['category'],
                'rating': landmark_info['rating'],
                'budget': landmark_info['budget'],
                'travel_types': landmark_info['travel_types'],
                'dl_score': float(dl_predictions[i])
            })
        
        # Sort by DL score
        dl_recommendations.sort(key=lambda x: x['dl_score'], reverse=True)
        
        # Select diverse recommendations
        dl_top_recommendations = []
        dl_selected_names = set()
        dl_category_counts = {}
        
        for rec in dl_recommendations:
            if rec['name'] not in dl_selected_names and len(dl_top_recommendations) < 10:
                category = rec['category']
                if category not in dl_category_counts:
                    dl_category_counts[category] = 0
                
                # Limit to 3 per category for diversity
                if dl_category_counts[category] < 3:
                    dl_top_recommendations.append(rec)
                    dl_selected_names.add(rec['name'])
                    dl_category_counts[category] += 1
        
        # Display DL recommendations
        print("\n" + "="*80)
        print("TOP 10 DEEP LEARNING RECOMMENDATIONS")
        print("="*80)
        
        for i, rec in enumerate(dl_top_recommendations, 1):
            budget_match = rec['budget'].lower() == user_input['user_budget'].lower()
            travel_match = user_input['user_travel_type'] in rec['travel_types']
            category_match = rec['category'] in user_input['user_preferences']
            
            print(f"\n{i}. {rec['name']}")
            print(f"   Category: {rec['category']}")
            print(f"   Rating: {rec['rating']:.1f}/5.0")
            print(f"   Budget: {rec['budget']} {'✓' if budget_match else '✗'}")
            print(f"   Suitable for: {rec['travel_types']}")
            print(f"   Travel type match: {'✓' if travel_match else '✗'}")
            print(f"   Category preference match: {'✓' if category_match else '✗'}")
            print(f"   DL Score: {rec['dl_score']:.3f}")
        
    except Exception as e:
        print(f"\nERROR: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()