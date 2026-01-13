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

def main():
    print("=" * 80)
    print("DEEP LEARNING TRAVEL RECOMMENDATION SYSTEM")
    print("=" * 80)
    
    # Get the current directory (where the script is located)
    current_dir = os.path.dirname(os.path.abspath(__file__))
    print(f"Current directory: {current_dir}")
    
    # List all files in the directory
    print(f"\nFiles in current directory:")
    files = os.listdir(current_dir)
    for file in files:
        print(f"  - {file}")
    
    # Look for data files
    data_files = []
    for file in files:
        if file.lower().endswith(('.csv', '.xls', '.xlsx', '.txt')) or 'data' in file.lower() or 'user' in file.lower():
            data_files.append(file)
    
    print(f"\nPossible data files found: {data_files}")
    
    if not data_files:
        print("\nERROR: No data files found in the directory!")
        print("Please make sure your data file is in the same directory as this script.")
        return
    
    # Try to find the correct file
    target_file = None
    for file in data_files:
        if 'user_landmark' in file.lower():
            target_file = file
            break
    
    if not target_file and data_files:
        target_file = data_files[0]  # Use the first data file
    
    file_path = os.path.join(current_dir, target_file)
    print(f"\nUsing file: {target_file}")
    print(f"Full path: {file_path}")
    
    try:
        # Try to read the file
        print(f"\nAttempting to read file: {target_file}")
        
        # Determine file type and read accordingly
        if target_file.lower().endswith('.xls') or target_file.lower().endswith('.xlsx'):
            # Try different Excel engines
            try:
                df = pd.read_excel(file_path, engine='openpyxl')
                print("Successfully read as Excel with openpyxl")
            except:
                try:
                    df = pd.read_excel(file_path, engine='xlrd')
                    print("Successfully read as Excel with xlrd")
                except Exception as e:
                    print(f"Failed to read as Excel: {e}")
                    # Try as CSV with different encodings
                    try:
                        df = pd.read_csv(file_path, encoding='utf-8')
                        print("Successfully read as CSV (UTF-8)")
                    except:
                        try:
                            df = pd.read_csv(file_path, encoding='latin-1')
                            print("Successfully read as CSV (Latin-1)")
                        except Exception as e2:
                            print(f"Failed to read file: {e2}")
                            return
        else:
            # Assume it's a CSV or text file
            try:
                df = pd.read_csv(file_path, encoding='utf-8')
                print("Successfully read as CSV (UTF-8)")
            except:
                try:
                    df = pd.read_csv(file_path, encoding='latin-1')
                    print("Successfully read as CSV (Latin-1)")
                except Exception as e:
                    print(f"Failed to read file: {e}")
                    return
        
        print(f"\nSuccessfully loaded data!")
        print(f"Data shape: {df.shape}")
        print(f"Columns: {df.columns.tolist()}")
        
        # Show first few rows
        print("\nFirst 3 rows of data:")
        print(df.head(3))
        
        # If we have only one column, the data might be combined
        if len(df.columns) == 1:
            print("\nDetected single column. Data might need splitting...")
            combined_column = df.columns[0]
            first_value = str(df.iloc[0, 0])
            
            # Check if first row contains column names
            if 'user' in first_value.lower() and 'landmark' in first_value.lower():
                print("First row appears to contain column names")
                # Split the first row to get column names
                column_names = first_value.split(',')
                print(f"Found {len(column_names)} column names")
                
                # Now split all data
                split_data = df[combined_column].str.split(',', expand=True)
                df = split_data.iloc[1:].reset_index(drop=True)
                df.columns = column_names[:len(df.columns)]
                
                print(f"\nAfter splitting - Shape: {df.shape}")
                print(f"Columns: {df.columns.tolist()}")
        
        # Clean column names
        df.columns = [col.strip().replace('"', '').replace("'", "").replace('\n', ' ') for col in df.columns]
        
        print(f"\nCleaned columns: {df.columns.tolist()}")
        
        # SIMPLE RECOMMENDATION SYSTEM
        print("\n" + "="*80)
        print("SIMPLE RECOMMENDATION SYSTEM")
        print("="*80)
        
        # Define user input
        user_input = {
            'user_age': 25,
            'user_gender': 'Male',
            'user_budget': 'medium',
            'user_travel_type': 'solo',
            'user_preferences': ['Museums', 'Shopping', 'Outdoor Activities', 'Nature & Parks']
        }
        
        print(f"\nUser Profile:")
        print(f"  Age: {user_input['user_age']}")
        print(f"  Gender: {user_input['user_gender']}")
        print(f"  Budget: {user_input['user_budget']}")
        print(f"  Travel Type: {user_input['user_travel_type']}")
        print(f"  Preferences: {user_input['user_preferences']}")
        
        # Try to find landmark columns
        landmark_name_col = None
        for col in df.columns:
            if 'landmark' in col.lower() and 'name' in col.lower():
                landmark_name_col = col
                break
            elif 'landmark' in col.lower():
                landmark_name_col = col
        
        if landmark_name_col:
            # Get unique landmarks
            landmark_cols = [landmark_name_col]
            for col in ['landmark_category', 'landmark_budget', 'landmark_rate', 'landmark_Suitable_Travel_Type']:
                if col in df.columns:
                    landmark_cols.append(col)
                else:
                    # Look for similar columns
                    for df_col in df.columns:
                        if col.split('_')[-1].lower() in df_col.lower():
                            landmark_cols.append(df_col)
                            break
            
            unique_landmarks = df[landmark_cols].drop_duplicates()
            print(f"\nFound {len(unique_landmarks)} unique landmarks")
            
            # Simple scoring function
            def calculate_score(landmark, user):
                score = 0
                
                # Budget match
                for budget_col in ['landmark_budget', 'budget']:
                    if budget_col in landmark:
                        if str(landmark[budget_col]).lower() == user['user_budget'].lower():
                            score += 30
                            break
                
                # Travel type match
                for travel_col in ['landmark_Suitable_Travel_Type', 'Suitable_Travel_Type', 'travel_type']:
                    if travel_col in landmark:
                        travel_types = str(landmark[travel_col]).lower().split(',')
                        travel_types = [t.strip() for t in travel_types]
                        if user['user_travel_type'].lower() in travel_types:
                            score += 30
                            break
                
                # Category preference match
                for category_col in ['landmark_category', 'category']:
                    if category_col in landmark:
                        if str(landmark[category_col]) in user['user_preferences']:
                            score += 20
                            break
                
                # Rating
                for rating_col in ['landmark_rate', 'rate', 'rating']:
                    if rating_col in landmark:
                        try:
                            rating = float(landmark[rating_col])
                            score += min(20, (rating - 1) * 5)
                        except:
                            pass
                        break
                
                return score
            
            # Calculate scores
            print("\nCalculating scores for landmarks...")
            scored_landmarks = []
            
            for idx, landmark in unique_landmarks.iterrows():
                score = calculate_score(landmark, user_input)
                landmark_info = {
                    'name': landmark[landmark_name_col],
                    'score': score
                }
                
                # Add additional info if available
                for col in ['landmark_category', 'category', 'landmark_budget', 'budget', 
                           'landmark_rate', 'rate', 'landmark_Suitable_Travel_Type', 'Suitable_Travel_Type']:
                    if col in landmark:
                        if 'category' in col.lower():
                            landmark_info['category'] = str(landmark[col])
                        elif 'budget' in col.lower():
                            landmark_info['budget'] = str(landmark[col])
                        elif 'rate' in col.lower():
                            landmark_info['rating'] = str(landmark[col])
                        elif 'travel' in col.lower():
                            landmark_info['travel_types'] = str(landmark[col]).split(',')
                
                scored_landmarks.append(landmark_info)
            
            # Sort and get top 10
            scored_landmarks.sort(key=lambda x: x['score'], reverse=True)
            top_10 = scored_landmarks[:10]
            
            # Display results
            print("\n" + "="*80)
            print("TOP 10 PERSONALIZED RECOMMENDATIONS")
            print("="*80)
            
            for i, rec in enumerate(top_10, 1):
                print(f"\n{i}. {rec['name']}")
                
                if 'category' in rec:
                    print(f"   Category: {rec['category']}")
                
                if 'rating' in rec:
                    print(f"   Rating: {rec['rating']}")
                
                if 'budget' in rec:
                    budget_match = rec['budget'].lower() == user_input['user_budget'].lower()
                    print(f"   Budget: {rec['budget']} {'✓' if budget_match else '✗'}")
                
                if 'travel_types' in rec:
                    travel_match = user_input['user_travel_type'].lower() in [t.strip().lower() for t in rec['travel_types']]
                    print(f"   Travel Match: {'✓' if travel_match else '✗'}")
                
                if 'category' in rec:
                    category_match = rec['category'] in user_input['user_preferences']
                    print(f"   Category Match: {'✓' if category_match else '✗'}")
                
                print(f"   Score: {rec['score']}/100")
        else:
            print("\nERROR: Could not find landmark information in the data.")
            print("Available columns:", df.columns.tolist())
        
    except Exception as e:
        print(f"\nERROR: {str(e)}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()