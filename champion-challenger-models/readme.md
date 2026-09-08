Champion Challenger Modelling

Order of execution of notebooks
1. CC_1_Data_generation.ipynb
2. CC_2_Champion_training.ipynb
3. CC_3_Challenger_training.ipynb
4. CC_4_Swap_models.ipynb
5. CC_5_Automation.ipynb  

Data Flow

Historical Data (Training) → Champion Model
                ↓
New Weekly Data → Challenger Model
                ↓
Evaluation Dataset → Performance Comparison
                ↓
Model Promotion Decision → Registry Updates

Time-Based Data Splits

Weeks 0-9  : Training Data (Champion)
Weeks 10-12: Test Data (Champion)
Weeks 3-12 : Training Data (Challenger)
Weeks 13-15: Test Data (Challenger)
Weeks 16-19: Evaluation Data (Hold-out for comparison)
