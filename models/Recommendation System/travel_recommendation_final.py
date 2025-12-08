import pandas as pd
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.preprocessing import LabelEncoder, MinMaxScaler
import ast
import warnings
import os
warnings.filterwarnings('ignore')

# Check if TensorFlow is using GPU
print("TensorFlow version:", tf.__version__)
print("GPU Available:", tf.config.list_physical_devices('GPU'))

def parse_list_string(list_str):
    """Parse string representation of list into actual list"""
    try:
        if pd.isna(list_str):
            return []
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
    
    # 3. Category preference match (40 points - MORE WEIGHT!)
    landmark_category = str(landmark.get('landmark_category', '')).strip()
    user_preferences = [p.strip() for p in user_input['user_preferences']]
    if landmark_category in user_preferences:
        score += 40  # Increased weight for preferences
    
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
        
        # Clean data
        print("\nCleaning data...")
        
        # Convert numeric columns
        df['user_age'] = pd.to_numeric(df['user_age'], errors='coerce')
        df['landmark_rate'] = pd.to_numeric(df['landmark_rate'], errors='coerce')
        
        # Fill missing values
        df['user_age'] = df['user_age'].fillna(df['user_age'].median())
        df['landmark_rate'] = df['landmark_rate'].fillna(df['landmark_rate'].median())
        
        # Use ALL data for unique landmarks
        print(f"\nUsing ALL {len(df)} rows for processing...")
        
        # Get unique landmarks from ALL data
        unique_landmarks = df[['landmark_name', 'landmark_category', 'landmark_budget', 
                              'landmark_rate', 'landmark_Suitable_Travel_Type']].drop_duplicates()
        print(f"\nFound {len(unique_landmarks)} unique landmarks")
        
        # User input
        user_input = {
            'user_age': 30,
            'user_gender': 'Male',
            'user_budget': 'medium',
            'user_travel_type': 'solo',
            'user_preferences': ['Museums','Outdoor Activities']
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
        for _, landmark in unique_landmarks.iterrows():
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
        
        # Get top recommendations - IMPROVED DIVERSITY LOGIC
        print("\nSelecting diverse recommendations...")
        
        # Separate landmarks by user preference categories
        preference_landmarks = {pref: [] for pref in user_input['user_preferences']}
        other_landmarks = []
        
        for landmark in scored_landmarks:
            if landmark['category'] in user_input['user_preferences']:
                preference_landmarks[landmark['category']].append(landmark)
            else:
                other_landmarks.append(landmark)
        
        # Select top from each preferred category
        top_recommendations = []
        selected_names = set()
        
        # Take 3 from each preferred category if available
        for pref in user_input['user_preferences']:
            landmarks_in_category = preference_landmarks.get(pref, [])
            taken = 0
            for landmark in landmarks_in_category:
                if landmark['name'] not in selected_names and taken < 3 and len(top_recommendations) < 10:
                    top_recommendations.append(landmark)
                    selected_names.add(landmark['name'])
                    taken += 1
        
        # Fill remaining slots with highest scores
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
        
        # Now let's create a MUCH BETTER deep learning model
        print("\n" + "="*80)
        print("DEEP LEARNING MODEL TRAINING")
        print("="*80)
        
        # Use a larger sample for training (500,000 rows)
        sample_size = min(500000, len(df))
        print(f"Using {sample_size} rows for deep learning training...")
        df_sample = df.sample(sample_size, random_state=42).reset_index(drop=True)
        
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
            
            # Gender (one-hot encoded)
            gender_onehot = [0, 0]
            if row['user_gender'].lower() == 'male':
                gender_onehot[0] = 1
            else:
                gender_onehot[1] = 1
            features.extend(gender_onehot)
            
            # Budget (one-hot encoded)
            budget_onehot = [0, 0, 0]
            if row['user_budget'].lower() == 'low':
                budget_onehot[0] = 1
            elif row['user_budget'].lower() == 'medium':
                budget_onehot[1] = 1
            else:
                budget_onehot[2] = 1
            features.extend(budget_onehot)
            
            # Travel type (one-hot encoded)
            travel_onehot = [0, 0, 0, 0]
            travel_types = ['family', 'couple', 'solo', 'luxury']
            try:
                travel_idx = travel_types.index(row['user_travel_type'].lower())
                travel_onehot[travel_idx] = 1
            except:
                pass
            features.extend(travel_onehot)
            
            # Preferences
            features.extend(pref_matrix[idx])
            
            user_features_list.append(features)
        
        user_features = np.array(user_features_list)
        print(f"User features shape: {user_features.shape}")
        
        # Create landmark features
        landmark_features_list = []
        for idx, row in df_sample.iterrows():
            features = []
            
            # Category (one-hot encoded)
            category_onehot = [0] * len(all_categories)
            try:
                cat_idx = all_categories.index(row['landmark_category'])
                category_onehot[cat_idx] = 1
            except:
                pass
            features.extend(category_onehot)
            
            # Budget (one-hot encoded)
            lm_budget_onehot = [0, 0, 0]
            if row['landmark_budget'].lower() == 'low':
                lm_budget_onehot[0] = 1
            elif row['landmark_budget'].lower() == 'medium':
                lm_budget_onehot[1] = 1
            else:
                lm_budget_onehot[2] = 1
            features.extend(lm_budget_onehot)
            
            # Rating (normalized)
            rating = float(row['landmark_rate'])
            rating_norm = (rating - 1) / 4
            features.append(rating_norm)
            
            landmark_features_list.append(features)
        
        landmark_features = np.array(landmark_features_list)
        print(f"Landmark features shape: {landmark_features.shape}")
        
        # Create BETTER labels based on multiple factors
        labels_list = []
        for idx, row in df_sample.iterrows():
            label_score = 0
            
            # Budget match (0.3 weight)
            if row['user_budget'].lower() == row['landmark_budget'].lower():
                label_score += 0.3
            
            # Travel type match (0.3 weight)
            user_travel_type = row['user_travel_type']
            landmark_travel_types = parse_list_string(row['landmark_Suitable_Travel_Type'])
            if user_travel_type in landmark_travel_types:
                label_score += 0.3
            
            # Category preference match (0.4 weight)
            user_prefs = parse_list_string(row['user_preferences'])
            if row['landmark_category'] in user_prefs:
                label_score += 0.4
            
            labels_list.append(label_score)
        
        labels = np.array(labels_list)
        print(f"Labels shape: {labels.shape}")
        print(f"Label distribution: Min={labels.min():.2f}, Max={labels.max():.2f}, Mean={labels.mean():.2f}")
        
        # Build IMPROVED neural network
        print("\nBuilding improved neural network...")
        
        user_input_layer = layers.Input(shape=(user_features.shape[1],))
        landmark_input_layer = layers.Input(shape=(landmark_features.shape[1],))
        
        # User network
        user_dense1 = layers.Dense(256, activation='relu')(user_input_layer)
        user_bn1 = layers.BatchNormalization()(user_dense1)
        user_dropout1 = layers.Dropout(0.3)(user_bn1)
        
        user_dense2 = layers.Dense(128, activation='relu')(user_dropout1)
        user_bn2 = layers.BatchNormalization()(user_dense2)
        user_dropout2 = layers.Dropout(0.2)(user_bn2)
        
        user_dense3 = layers.Dense(64, activation='relu')(user_dropout2)
        user_embedding = layers.BatchNormalization()(user_dense3)
        
        # Landmark network
        landmark_dense1 = layers.Dense(128, activation='relu')(landmark_input_layer)
        landmark_bn1 = layers.BatchNormalization()(landmark_dense1)
        landmark_dropout1 = layers.Dropout(0.3)(landmark_bn1)
        
        landmark_dense2 = layers.Dense(64, activation='relu')(landmark_dropout1)
        landmark_bn2 = layers.BatchNormalization()(landmark_dense2)
        landmark_dropout2 = layers.Dropout(0.2)(landmark_bn2)
        
        landmark_dense3 = layers.Dense(32, activation='relu')(landmark_dropout2)
        landmark_embedding = layers.BatchNormalization()(landmark_dense3)
        
        # Combine with dot product for similarity
        dot_product = layers.Dot(axes=1, normalize=True)([user_embedding, landmark_embedding])
        
        # Also concatenate for additional features
        combined = layers.Concatenate()([user_embedding, landmark_embedding, dot_product])
        
        # Final layers
        dense1 = layers.Dense(64, activation='relu')(combined)
        bn1 = layers.BatchNormalization()(dense1)
        dropout1 = layers.Dropout(0.2)(bn1)
        
        dense2 = layers.Dense(32, activation='relu')(dropout1)
        bn2 = layers.BatchNormalization()(dense2)
        dropout2 = layers.Dropout(0.1)(bn2)
        
        dense3 = layers.Dense(16, activation='relu')(dropout2)
        output = layers.Dense(1, activation='sigmoid')(dense3)
        
        # Create model
        model = keras.Model(
            inputs=[user_input_layer, landmark_input_layer],
            outputs=output
        )
        
        # Compile with better optimizer
        model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.0005),
            loss='mse',
            metrics=['mae', keras.metrics.RootMeanSquaredError()]
        )
        
        print("\nModel summary:")
        model.summary()
        
        # Train on the sample
        print(f"\nTraining on {len(user_features)} samples...")
        
        # Split for validation
        from sklearn.model_selection import train_test_split
        X_user_train, X_user_val, X_landmark_train, X_landmark_val, y_train, y_val = train_test_split(
            user_features, landmark_features, labels,
            test_size=0.2, random_state=42
        )
        
        # Train with callbacks
        callbacks = [
            keras.callbacks.EarlyStopping(patience=10, restore_best_weights=True, min_delta=0.0001),
            keras.callbacks.ReduceLROnPlateau(factor=0.5, patience=5, min_lr=0.00001),
            keras.callbacks.ModelCheckpoint('best_model.keras', save_best_only=True)
        ]
        
        history = model.fit(
            [X_user_train, X_landmark_train], y_train,
            validation_data=([X_user_val, X_landmark_val], y_val),
            epochs=30,
            batch_size=512,
            callbacks=callbacks,
            verbose=1
        )
        
        print("\nModel training completed!")
        
        # Generate DL recommendations using ALL unique landmarks
        print("\n" + "="*80)
        print("DEEP LEARNING RECOMMENDATIONS")
        print("="*80)
        
        # Create user feature vector for prediction
        test_user_features = []
        
        # Age
        age_norm = (user_input['user_age'] - 18) / (75 - 18)
        test_user_features.append(age_norm)
        
        # Gender (one-hot)
        gender_onehot = [0, 0]
        if user_input['user_gender'].lower() == 'male':
            gender_onehot[0] = 1
        else:
            gender_onehot[1] = 1
        test_user_features.extend(gender_onehot)
        
        # Budget (one-hot)
        budget_onehot = [0, 0, 0]
        if user_input['user_budget'].lower() == 'low':
            budget_onehot[0] = 1
        elif user_input['user_budget'].lower() == 'medium':
            budget_onehot[1] = 1
        else:
            budget_onehot[2] = 1
        test_user_features.extend(budget_onehot)
        
        # Travel type (one-hot)
        travel_onehot = [0, 0, 0, 0]
        travel_types = ['family', 'couple', 'solo', 'luxury']
        try:
            travel_idx = travel_types.index(user_input['user_travel_type'].lower())
            travel_onehot[travel_idx] = 1
        except:
            pass
        test_user_features.extend(travel_onehot)
        
        # Preferences
        user_pref_vector = [1 if cat in user_input['user_preferences'] else 0 for cat in all_categories]
        test_user_features.extend(user_pref_vector)
        
        test_user_features = np.array([test_user_features])
        
        # Prepare ALL unique landmarks for prediction
        print(f"\nPreparing {len(unique_landmarks)} landmarks for prediction...")
        
        pred_landmark_features = []
        landmark_info_list = []
        
        for _, landmark in unique_landmarks.iterrows():
            # Landmark features
            features = []
            
            # Category (one-hot)
            category_onehot = [0] * len(all_categories)
            try:
                cat_idx = all_categories.index(landmark['landmark_category'])
                category_onehot[cat_idx] = 1
            except:
                pass
            features.extend(category_onehot)
            
            # Budget (one-hot)
            lm_budget_onehot = [0, 0, 0]
            if landmark['landmark_budget'].lower() == 'low':
                lm_budget_onehot[0] = 1
            elif landmark['landmark_budget'].lower() == 'medium':
                lm_budget_onehot[1] = 1
            else:
                lm_budget_onehot[2] = 1
            features.extend(lm_budget_onehot)
            
            # Rating
            rating = float(landmark['landmark_rate'])
            rating_norm = (rating - 1) / 4
            features.append(rating_norm)
            
            pred_landmark_features.append(features)
            
            # Store landmark info
            travel_types = parse_list_string(landmark['landmark_Suitable_Travel_Type'])
            landmark_info_list.append({
                'name': landmark['landmark_name'],
                'category': landmark['landmark_category'],
                'rating': float(landmark['landmark_rate']),
                'budget': landmark['landmark_budget'],
                'travel_types': travel_types
            })
        
        pred_landmark_features = np.array(pred_landmark_features)
        
        # Repeat user features for all landmarks
        pred_user_features = np.repeat(test_user_features, len(pred_landmark_features), axis=0)
        
        # Get predictions
        print("Generating deep learning predictions...")
        dl_predictions = model.predict(
            [pred_user_features, pred_landmark_features],
            verbose=0,
            batch_size=512
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
        
        # Prioritize user-preferred categories
        for pref in user_input['user_preferences']:
            for rec in dl_recommendations:
                if (rec['category'] == pref and 
                    rec['name'] not in dl_selected_names and 
                    len(dl_top_recommendations) < 10):
                    dl_top_recommendations.append(rec)
                    dl_selected_names.add(rec['name'])
        
        # Fill with highest scores
        if len(dl_top_recommendations) < 10:
            for rec in dl_recommendations:
                if rec['name'] not in dl_selected_names and len(dl_top_recommendations) < 10:
                    dl_top_recommendations.append(rec)
                    dl_selected_names.add(rec['name'])
        
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
        
        # Final summary
        print("\n" + "="*80)
        print("FINAL SUMMARY")
        print("="*80)
        
        rule_categories = [rec['category'] for rec in top_recommendations]
        dl_categories = [rec['category'] for rec in dl_top_recommendations]
        
        print("\nRule-Based Recommendations by Category:")
        from collections import Counter
        for category, count in Counter(rule_categories).most_common():
            print(f"  {category}: {count}")
        
        print("\nDeep Learning Recommendations by Category:")
        for category, count in Counter(dl_categories).most_common():
            print(f"  {category}: {count}")
        
        print(f"\nUser Preferences Covered (Rule-Based): {len(set(rule_categories) & set(user_input['user_preferences']))}/4")
        print(f"User Preferences Covered (Deep Learning): {len(set(dl_categories) & set(user_input['user_preferences']))}/4")
        
    except Exception as e:
        print(f"\nERROR: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()