
import pandas as pd
import numpy as np
from pathlib import Path

rng = np.random.default_rng(789)

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"

NUM_SESSIONS = 200000

# Load existing datasets
customers = pd.read_csv(
    DATA_DIR / "customers.csv",
    parse_dates=["signup_date"]
)

campaigns = pd.read_csv(
    DATA_DIR / "campaigns.csv",
    parse_dates=["start_date", "end_date"]
)

START = pd.Timestamp("2025-10-01")
END = pd.Timestamp("2026-09-30 23:59:59")

channels = [
    "Organic Search", "Paid Search",
    "Social", "Direct", "Referral", "Email"
]

channel_probs = [0.30, 0.25, 0.20, 0.12, 0.08, 0.05]

devices = ["Mobile", "Desktop", "Tablet"]
device_probs = [0.65, 0.30, 0.05]

landing_pages = [
    "/", "/products", "/categories",
    "/offers", "/new-arrivals"
]

# Precompute active campaign lookup by date and channel
campaign_lookup = {}

for row in campaigns.itertuples(index=False):
    for day in pd.date_range(row.start_date, row.end_date):
        key = (day.date(), row.channel)
        campaign_lookup.setdefault(key, []).append(
            int(row.campaign_id)
        )

# Generate registered customer sessions
# Every registered customer receives at least one session
# after registration.
registered_ids = customers["customer_id"].to_numpy()
signup_dates = customers["signup_date"].to_numpy(
    dtype="datetime64[s]"
)

registered_session_count = 140000

customer_indices = np.concatenate([
    np.arange(len(customers)),
    rng.choice(
        len(customers),
        registered_session_count - len(customers),
        replace=True
    )
])

rng.shuffle(customer_indices)

# Generate anonymous visitors
anonymous_session_count = (
    NUM_SESSIONS - registered_session_count
)

anonymous_visitor_count = 20000

anonymous_indices = rng.integers(
    1,
    anonymous_visitor_count + 1,
    size=anonymous_session_count
)

rows = []

for i in range(NUM_SESSIONS):

    if i < registered_session_count:
        idx = int(customer_indices[i])
        customer_id = int(registered_ids[idx])
        visitor_id = f"REG{customer_id:06d}"
        earliest = pd.Timestamp(signup_dates[idx])
    else:
        customer_id = None
        visitor_id = (
            f"ANON{anonymous_indices[i - registered_session_count]:06d}"
        )
        earliest = START

    # Choose session timestamp after registration
    remaining_seconds = int(
        (END - earliest).total_seconds()
    )

    offset = int(
        rng.integers(0, remaining_seconds + 1)
    )

    session_start = earliest + pd.Timedelta(
        seconds=offset
    )

    # Session duration: 1 to 30 minutes
    duration_minutes = int(rng.integers(1, 31))

    session_end = session_start + pd.Timedelta(
        minutes=duration_minutes
    )

    # Keep session within analysis period
    if session_end > END:
        session_end = END

    channel = str(rng.choice(
        channels, p=channel_probs
    ))

    device = str(rng.choice(
        devices, p=device_probs
    ))

    landing_page = str(rng.choice(landing_pages))

    # Assign campaigns only when active and matching channel
    campaign_id = None

    eligible = campaign_lookup.get(
        (session_start.date(), channel), []
    )

    if eligible and rng.random() < 0.70:
        campaign_id = int(rng.choice(eligible))

    rows.append({
        "session_id": i + 1,
        "customer_id": customer_id,
        "visitor_id": visitor_id,
        "session_start": session_start,
        "session_end": session_end,
        "device_type": device,
        "channel": channel,
        "campaign_id": campaign_id,
        "landing_page": landing_page
    })

sessions = pd.DataFrame(rows)

# Sort chronologically while preserving unique session IDs
sessions = sessions.sort_values(
    "session_start"
).reset_index(drop=True)

# Validate
assert len(sessions) == NUM_SESSIONS
assert sessions["session_id"].is_unique
assert (
    sessions["session_end"] >= sessions["session_start"]
).all()
assert sessions["visitor_id"].notna().all()

# Save
output_file = DATA_DIR / "sessions.csv"

sessions.to_csv(output_file, index=False)

print("Sessions dataset generated successfully!")
print("Total sessions:", len(sessions))
print("Registered sessions:",
      sessions["customer_id"].notna().sum())
print("Anonymous sessions:",
      sessions["customer_id"].isna().sum())
print("Unique visitors:",
      sessions["visitor_id"].nunique())
print("Saved at:", output_file)

print("\nFirst five sessions:")
print(sessions.head())
