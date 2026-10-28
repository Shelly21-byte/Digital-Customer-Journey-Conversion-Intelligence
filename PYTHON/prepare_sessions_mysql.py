
import pandas as pd
from pathlib import Path

# ==========================================
# PREPARE SESSIONS CSV FOR MYSQL
# Purpose: Handle missing foreign key values
# ==========================================

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"

# Read original sessions dataset
df = pd.read_csv(DATA_DIR / "sessions.csv")

# Convert missing IDs to MySQL NULL marker
for col in ["customer_id", "campaign_id"]:
    df[col] = df[col].apply(
        lambda x: r"\N" if pd.isna(x) else str(int(x))
    )

# Save a separate import-ready file
output_path = DATA_DIR / "sessions_mysql.csv"

df.to_csv(output_path, index=False)

print("MySQL import file created!")
print("Total sessions:", len(df))
print("Saved to:", output_path)
