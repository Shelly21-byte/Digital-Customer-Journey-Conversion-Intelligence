
import pandas as pd
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DATA_DIR = BASE_DIR / "DATA"

events = pd.read_csv(
    DATA_DIR / "events.csv",
    parse_dates=["event_timestamp"]
)

sessions = pd.read_csv(
    DATA_DIR / "sessions.csv",
    parse_dates=["session_start", "session_end"]
)

orders = pd.read_csv(
    DATA_DIR / "orders.csv",
    parse_dates=["order_timestamp"]
)

# Match events to their sessions
merged = events.merge(
    sessions[["session_id", "session_start", "session_end"]],
    on="session_id",
    how="left",
    validate="many_to_one"
)

# Check timestamps
before_start = (
    merged["event_timestamp"] < merged["session_start"]
).sum()

after_end = (
    merged["event_timestamp"] > merged["session_end"]
).sum()

# Check event sequences
stage_order = {
    "session_start": 0,
    "page_view": 1,
    "view_item": 2,
    "add_to_cart": 3,
    "begin_checkout": 4,
    "purchase": 5
}

events["stage"] = events["event_name"].map(stage_order)

ordered = events.sort_values(
    ["session_id", "event_timestamp", "event_id"]
)

previous_stage = ordered.groupby(
    "session_id"
)["stage"].shift()

invalid_sequences = (
    (ordered["stage"] < previous_stage)
    & previous_stage.notna()
).sum()

# Check order timestamps
purchase_events = events[
    events["event_name"] == "purchase"
]

purchase_check = purchase_events.merge(
    orders[["order_id", "order_timestamp"]],
    on="order_id",
    how="left"
)

timestamp_mismatches = (
    purchase_check["event_timestamp"]
    != purchase_check["order_timestamp"]
).sum()

print("Events before session start:", before_start)
print("Events after session end:", after_end)
print("Invalid event sequences:", invalid_sequences)
print("Purchase timestamp mismatches:", timestamp_mismatches)

assert before_start == 0
assert after_end == 0
assert invalid_sequences == 0
assert timestamp_mismatches == 0

print("\nFINAL EVENT VALIDATION PASSED!")
