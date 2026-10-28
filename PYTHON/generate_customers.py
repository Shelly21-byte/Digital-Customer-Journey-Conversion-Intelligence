
import pandas as pd
import numpy as np
from pathlib import Path

# Reproducible synthetic data
rng = np.random.default_rng(42)

# Project folders
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"
DATA_DIR.mkdir(exist_ok=True)

# Number of registered customers
NUM_CUSTOMERS = 50000

# City and state combinations
locations = [
    ("Mumbai", "Maharashtra"),
    ("Delhi", "Delhi"),
    ("Bengaluru", "Karnataka"),
    ("Hyderabad", "Telangana"),
    ("Chennai", "Tamil Nadu"),
    ("Pune", "Maharashtra"),
    ("Jaipur", "Rajasthan"),
    ("Ahmedabad", "Gujarat"),
    ("Kolkata", "West Bengal"),
    ("Indore", "Madhya Pradesh")
]

channels = [
    "Organic Search",
    "Paid Search",
    "Social",
    "Direct",
    "Referral",
    "Email"
]

channel_probabilities = [
    0.30, 0.25, 0.20, 0.12, 0.08, 0.05
]

# Generate registration timestamps
start_date = pd.Timestamp("2025-10-01")
end_date = pd.Timestamp("2026-09-30 23:59:59")

total_seconds = int(
    (end_date - start_date).total_seconds()
)

random_seconds = rng.integers(
    0, total_seconds + 1, NUM_CUSTOMERS
)

signup_dates = (
    start_date + pd.to_timedelta(random_seconds, unit="s")
)

# Generate locations
location_indices = rng.integers(
    0, len(locations), NUM_CUSTOMERS
)

cities = [locations[i][0] for i in location_indices]
states = [locations[i][1] for i in location_indices]

# Generate acquisition channels
acquisition_channels = rng.choice(
    channels,
    size=NUM_CUSTOMERS,
    p=channel_probabilities
)

# Build customer dataset
customers = pd.DataFrame({
    "customer_id": np.arange(1, NUM_CUSTOMERS + 1),
    "signup_date": signup_dates,
    "city": cities,
    "state": states,
    "acquisition_channel": acquisition_channels
})

# Save dataset
output_file = DATA_DIR / "customers.csv"

customers.to_csv(output_file, index=False)

# Basic validation
assert customers["customer_id"].is_unique
assert customers.notna().all().all()
assert len(customers) == NUM_CUSTOMERS

print("Customer dataset generated successfully!")
print("Total customers:", len(customers))
print("File saved at:", output_file)
print(customers.head())
