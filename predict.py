import sys
import argparse
import pandas as pd
import joblib
import numpy as np
import warnings

warnings.filterwarnings("ignore")

def load_artifacts():
    try:
        return joblib.load('model_artifacts.pkl')
    except FileNotFoundError:
        print("Error: model_artifacts.pkl not found. Please run train_model.py first.", file=sys.stderr)
        exit(1)
    except Exception as e:
        print(f"Error loading artifacts: {e}", file=sys.stderr)
        exit(1)

def main():
    parser = argparse.ArgumentParser(description='Stroke Prediction')
    parser.add_argument('--gender', type=str, required=True)
    parser.add_argument('--age', type=float, required=True)
    parser.add_argument('--hypertension', type=int, required=True)
    parser.add_argument('--heart_disease', type=int, required=True)
    parser.add_argument('--ever_married', type=str, required=True)
    parser.add_argument('--work_type', type=str, required=True)
    parser.add_argument('--residence_type', type=str, required=True)
    parser.add_argument('--avg_glucose_level', type=float, required=True)
    parser.add_argument('--bmi', type=str, required=True) # Accepting as string to handle potentially empty inputs gracefully if needed, though CLI usually enforces type
    parser.add_argument('--smoking_status', type=str, required=True)

    args = parser.parse_args()

    artifacts = load_artifacts()
    model = artifacts['model']
    scaler = artifacts['scaler']
    encoders = artifacts['encoders']
    bmi_median = artifacts['bmi_median']
    feature_columns = artifacts['columns']

    # Prepare input data
    data = {
        'gender': [args.gender],
        'age': [args.age],
        'hypertension': [args.hypertension],
        'heart_disease': [args.heart_disease],
        'ever_married': [args.ever_married],
        'work_type': [args.work_type],
        'Residence_type': [args.residence_type],
        'avg_glucose_level': [args.avg_glucose_level],
        'bmi': [float(args.bmi) if args.bmi and args.bmi.lower() != 'nan' else np.nan],
        'smoking_status': [args.smoking_status]
    }
    
    df = pd.DataFrame(data)

    # 1. Fill BMI
    df['bmi'].fillna(bmi_median, inplace=True)

    # 2. Encode categorical
    # Note: user must provide valid values matching those seen during training.
    # We should handle potential unknown labels gracefully or let it crash with a clear message.
    for col, le in encoders.items():
        if col in df.columns:
            # Handle unknown labels by assigning a default or raising error
            # For simplicity, we assume inputs are valid or map to nearest? 
            # Actually, LabelEncoder will throw error for unseen labels.
             # Ideally we'd wrap this in try-except
            try:
                df[col] = le.transform(df[col])
            except ValueError as e:
                # Fallback: try to fit valid labels or print error
                # Since this is a simple demo, we'll strip whitespace and try again, usually inputs might differ slightly
                print(f"Error encoding {col}: {e}")
                exit(1)

    # 3. Scale numericals
    # The scaler expects specific columns to be scaled in specific order if fitted on dense array?
    # No, scaler was fitted on the WHOLE dataset (resampled). 
    # Wait, in train_model.py: 
    # X_train_res = scaler.fit_transform(X_train_res)
    # X_train_res IS the whole feature set.
    # So we just transform the whole DF.
    
    # Ensure column order matches training
    df = df[feature_columns]
    
    X_scaled = scaler.transform(df)

    # Predict
    prediction = model.predict(X_scaled)
    prob = model.predict_proba(X_scaled)[0][1]

    print(f"Prediction: {prediction[0]}")
    print(f"Probability: {prob:.4f}")

if __name__ == '__main__':
    main()
