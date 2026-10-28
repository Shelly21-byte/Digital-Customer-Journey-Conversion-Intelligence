
import pandas as pd
import numpy as np
from pathlib import Path

# Reproducible random generator
rng = np.random.default_rng(123)

# Project paths
BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"
DATA_DIR.mkdir(exist_ok=True)

NUM_CAMPAIGNS = 60

# Marketing channels and their simulated daily budgets
channel_budgets = {
    "Paid Search": (3000, 12000),
    "Social": (2000, 10000),
    "Email": (500, 2500),
    "Referral": (800, 4000)
}

campaign_types = [
    "Festive Sale",
    "New Arrivals",
    "Weekend Deals",
    "Customer Rewards",
    "Seasonal Offers",
    "Product Launch"
]

channels = list(channel_budgets.keys())

start_period = pd.Timestamp("2025-10-01")
end_period = pd.Timestamp("2026-09-30")

campaigns = []

for i in range(1, NUM_CAMPAIGNS + 1):

    channel = rng.choice(
        channels,
        p=[0.40, 0.35, 0.15, 0.10]
    )

    campaign_type = rng.choice(campaign_types)

    # Campaigns run between 7 and 30 days
    duration = int(rng.integers(7, 31))

    # Ensure campaign ends within analysis period
    latest_start = end_period - pd.Timedelta(days=duration - 1)
    max_offset = (latest_start - start_period).days

    start_offset = int(rng.integers(0, max_offset + 1))
    start_date = start_period + pd.Timedelta(days=start_offset)
    end_date = start_date + pd.Timedelta(days=duration - 1)

    min_budget, max_budget = channel_budgets[channel]
    daily_budget = float(rng.uniform(min_budget, max_budget))

    campaign_spend = round(daily_budget * duration, 2)

    campaign_name = (
        f"{campaign_type.replace(' ', '_')}_{channel.replace(' ', '_')}_{i:03d}"
    )

    campaigns.append({
        "campaign_id": i,
        "campaign_name": campaign_name,
        "channel": channel,
        "start_date": start_date.date(),
        "end_date": end_date.date(),
        "campaign_spend": campaign_spend
    })

campaigns_df = pd.DataFrame(campaigns)

# Validation
assert len(campaigns_df) == NUM_CAMPAIGNS
assert campaigns_df["campaign_id"].is_unique
assert campaigns_df.notna().all().all()
assert (
    pd.to_datetime(campaigns_df["end_date"])
    >= pd.to_datetime(campaigns_df["start_date"])
).all()

# Save CSV
output_file = DATA_DIR / "campaigns.csv"
campaigns_df.to_csv(output_file, index=False)

print("Campaign dataset generated successfully!")
print("Total campaigns:", len(campaigns_df))
print("Total simulated spend (INR):",
      round(campaigns_df["campaign_spend"].sum(), 2))
print("Saved at:", output_file)
print(campaigns_df.head())
