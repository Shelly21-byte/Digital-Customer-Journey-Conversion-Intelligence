
import pandas as pd
import numpy as np
from pathlib import Path

# Reproducible synthetic data
rng = np.random.default_rng(2026)

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"

# Load existing datasets
sessions = pd.read_csv(
    DATA_DIR / "sessions.csv",
    parse_dates=["session_start", "session_end"]
)

products = pd.read_csv(DATA_DIR / "products.csv")

TARGET_EVENTS = 750000

events = []
orders = []

event_id = 1
order_id = 1

product_ids = products["product_id"].to_numpy()
product_prices = products.set_index(
    "product_id"
)["price_inr"].to_dict()

# Every session starts with two mandatory events:
# session_start and page_view.
# Additional events create the shopping journey.

for session in sessions.itertuples(index=False):

    sid = int(session.session_id)
    start = session.session_start
    end = session.session_end

    customer_id = (
        int(session.customer_id)
        if pd.notna(session.customer_id)
        else None
    )

    duration_seconds = int((end - start).total_seconds())

    # Decide how far the visitor progresses
    progress = rng.choice(
        ["browse", "view", "cart", "checkout", "purchase"],
        p=[0.25, 0.30, 0.22, 0.15, 0.08]
    )

    sequence = ["session_start", "page_view"]

    if progress in ["view", "cart", "checkout", "purchase"]:
        sequence.append("view_item")

    if progress in ["cart", "checkout", "purchase"]:
        sequence.append("add_to_cart")

    if progress in ["checkout", "purchase"]:
        sequence.append("begin_checkout")

    if progress == "purchase":
        sequence.append("purchase")

    # Extra page views create more realistic browsing
    extra_views = int(rng.integers(0, 4))

    for _ in range(extra_views):
        sequence.insert(2, "page_view")

    # Sign-up events are not generated here because the
    # existing sessions represent registered or anonymous
    # identities without modeled registration transitions.

    selected_product = int(rng.choice(product_ids))

    # Generate chronological event timestamps
    n_events = len(sequence)

    offsets = np.linspace(
        0, max(duration_seconds, 0), n_events
    ).astype(int)

    current_order_id = None

    if progress == "purchase":

        current_order_id = order_id

        quantity = int(rng.integers(1, 4))

        order_value = round(
            float(product_prices[selected_product]) * quantity,
            2
        )

        orders.append({
            "order_id": order_id,
            "session_id": sid,
            "customer_id": customer_id,
            "order_timestamp": start + pd.Timedelta(
                seconds=int(offsets[-1])
            ),
            "order_value_inr": order_value,
            "order_status": "Completed"
        })

        order_id += 1

    for index, event_name in enumerate(sequence):

        product_id = (
            selected_product
            if event_name in [
                "view_item",
                "add_to_cart",
                "begin_checkout",
                "purchase"
            ]
            else None
        )

        events.append({
            "event_id": event_id,
            "session_id": sid,
            "event_timestamp": start + pd.Timedelta(
                seconds=int(offsets[index])
            ),
            "event_name": event_name,
            "product_id": product_id,
            "order_id": (
                current_order_id
                if event_name == "purchase"
                else None
            )
        })

        event_id += 1

# Convert to DataFrames
events_df = pd.DataFrame(events)
orders_df = pd.DataFrame(orders)

# Save both datasets
events_file = DATA_DIR / "events.csv"
orders_file = DATA_DIR / "orders.csv"

events_df.to_csv(events_file, index=False)
orders_df.to_csv(orders_file, index=False)

# Basic validation
assert events_df["event_id"].is_unique
assert orders_df["order_id"].is_unique

purchase_events = events_df[
    events_df["event_name"] == "purchase"
]

assert len(purchase_events) == len(orders_df)

assert set(purchase_events["order_id"].dropna()) == set(
    orders_df["order_id"]
)

print("Customer journey datasets generated successfully!")
print("Total events:", len(events_df))
print("Target events:", TARGET_EVENTS)
print("Total orders:", len(orders_df))
print("Purchase events:", len(purchase_events))
print("Unique sessions:", events_df["session_id"].nunique())

print("\nEvent distribution:")
print(events_df["event_name"].value_counts())

print("\nFiles saved:")
print(events_file)
print(orders_file)
