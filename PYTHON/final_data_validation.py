
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"

# Load all six datasets
customers = pd.read_csv(
    DATA_DIR / "customers.csv",
    parse_dates=["signup_date"]
)

campaigns = pd.read_csv(
    DATA_DIR / "campaigns.csv",
    parse_dates=["start_date", "end_date"]
)

products = pd.read_csv(DATA_DIR / "products.csv")

sessions = pd.read_csv(
    DATA_DIR / "sessions.csv",
    parse_dates=["session_start", "session_end"]
)

events = pd.read_csv(
    DATA_DIR / "events.csv",
    parse_dates=["event_timestamp"]
)

orders = pd.read_csv(
    DATA_DIR / "orders.csv",
    parse_dates=["order_timestamp"]
)

failures = []

def check(name, count):
    count = int(count)
    status = "PASS" if count == 0 else "FAIL"
    print(f"{status}: {name} - {count} issues")
    if count:
        failures.append((name, count))

print("\n=== FINAL DATA QUALITY AUDIT ===\n")

# 1. Primary key uniqueness
tables = [
    ("customers", customers, "customer_id"),
    ("campaigns", campaigns, "campaign_id"),
    ("products", products, "product_id"),
    ("sessions", sessions, "session_id"),
    ("events", events, "event_id"),
    ("orders", orders, "order_id")
]

for name, df, key in tables:
    check(
        f"{name}: duplicate primary keys",
        df[key].duplicated().sum()
    )
    check(
        f"{name}: missing primary keys",
        df[key].isna().sum()
    )

# 2. Foreign key relationships
registered = sessions[
    sessions["customer_id"].notna()
]

check(
    "Unknown session customers",
    (~registered["customer_id"].isin(
        customers["customer_id"]
    )).sum()
)

check(
    "Unknown event sessions",
    (~events["session_id"].isin(
        sessions["session_id"]
    )).sum()
)

check(
    "Unknown order sessions",
    (~orders["session_id"].isin(
        sessions["session_id"]
    )).sum()
)

product_events = events[
    events["product_id"].notna()
]

check(
    "Unknown event products",
    (~product_events["product_id"].isin(
        products["product_id"]
    )).sum()
)

campaign_sessions = sessions[
    sessions["campaign_id"].notna()
]

check(
    "Unknown campaign references",
    (~campaign_sessions["campaign_id"].isin(
        campaigns["campaign_id"]
    )).sum()
)

# 3. Session timing
merged_events = events.merge(
    sessions[
        ["session_id", "session_start", "session_end"]
    ],
    on="session_id",
    how="left",
    validate="many_to_one"
)

check(
    "Events outside session boundaries",
    (
        (merged_events["event_timestamp"]
         < merged_events["session_start"])
        |
        (merged_events["event_timestamp"]
         > merged_events["session_end"])
    ).sum()
)

# 4. Session start counts
starts = events[
    events["event_name"] == "session_start"
]

start_counts = starts.groupby("session_id").size()

check(
    "Sessions without exactly one start event",
    (sessions["session_id"].map(
        start_counts
    ).fillna(0) != 1).sum()
)

# 5. Purchase and order reconciliation
purchases = events[
    events["event_name"] == "purchase"
]

check(
    "Purchase/order count difference",
    abs(len(purchases) - len(orders))
)

check(
    "Missing purchase order IDs",
    purchases["order_id"].isna().sum()
)

check(
    "Purchase events without matching orders",
    (~purchases["order_id"].isin(
        orders["order_id"]
    )).sum()
)

check(
    "Orders without matching purchase events",
    (~orders["order_id"].isin(
        purchases["order_id"]
    )).sum()
)

check(
    "Duplicate purchase order references",
    purchases["order_id"].duplicated().sum()
)

# 6. Verify purchase session and timestamp
purchase_match = purchases.merge(
    orders[
        ["order_id", "session_id", "order_timestamp"]
    ],
    on="order_id",
    how="left",
    suffixes=("_event", "_order"),
    validate="one_to_one"
)

check(
    "Purchase session mismatches",
    (
        purchase_match["session_id_event"]
        != purchase_match["session_id_order"]
    ).sum()
)

check(
    "Purchase timestamp mismatches",
    (
        purchase_match["event_timestamp"]
        != purchase_match["order_timestamp"]
    ).sum()
)

# 7. Order values
check(
    "Invalid order values",
    (
        orders["order_value_inr"].isna()
        | (orders["order_value_inr"] <= 0)
    ).sum()
)

# 8. Campaign attribution consistency
attributed = campaign_sessions.merge(
    campaigns[
        ["campaign_id", "channel",
         "start_date", "end_date"]
    ],
    on="campaign_id",
    how="left",
    suffixes=("_session", "_campaign"),
    validate="many_to_one"
)

check(
    "Campaign channel mismatches",
    (
        attributed["channel_session"]
        != attributed["channel_campaign"]
    ).sum()
)

check(
    "Campaign date mismatches",
    (
        (attributed["session_start"].dt.normalize()
         < attributed["start_date"])
        |
        (attributed["session_start"].dt.normalize()
         > attributed["end_date"])
    ).sum()
)

# Final summary
print("\n=== DATASET SUMMARY ===")

for name, df, key in tables:
    print(f"{name}: {len(df):,} records")

print("\n=== FINAL RESULT ===")

if failures:
    print(f"FAILED: {len(failures)} checks found issues.")
    for name, count in failures:
        print(f" - {name}: {count}")
    raise SystemExit(1)
else:
    print("ALL DATA QUALITY CHECKS PASSED!")
    print("Datasets are ready for the next phase.")
