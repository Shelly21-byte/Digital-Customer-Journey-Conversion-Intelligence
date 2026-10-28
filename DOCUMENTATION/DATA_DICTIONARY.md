# Data dictionary

Source data is synthetic. Derived features are computed; no new customer actions are invented.


## campaign_dimension.csv

| Column | Type/example | Meaning |
|---|---|---|
| campaign_id | 1 | Campaign key; derived model uses 0 for unattributed sessions. |
| campaign_name | Customer_Rewards_Social_001 | Campaign name |
| channel | Social | Channel |
| start_date | 2026-08-22 | Start date |
| end_date | 2026-08-29 | End date |
| campaign_spend | 27799.8 | Campaign spend |

## campaigns.csv

| Column | Type/example | Meaning |
|---|---|---|
| campaign_id | 1 | Campaign key; derived model uses 0 for unattributed sessions. |
| campaign_name | Customer_Rewards_Social_001 | Campaign name |
| channel | Social | Channel |
| start_date | 2026-08-22 | Start date |
| end_date | 2026-08-29 | End date |
| campaign_spend | 27799.8 | Campaign spend |

## cohort_activity.csv

| Column | Type/example | Meaning |
|---|---|---|
| visitor_id | ANON008082 | Persistent synthetic visitor identity; includes registered and anonymous visitors. |
| month_offset | 0 | Month offset |

## customers.csv

| Column | Type/example | Meaning |
|---|---|---|
| customer_id | 1 | Registered customer key; derived features use 0 for anonymous sessions. |
| signup_date | 2025-11-02 13:50:18 | Signup date |
| city | Chennai | City |
| state | Tamil Nadu | State |
| acquisition_channel | Email | Acquisition channel |

## date_dimension.csv

| Column | Type/example | Meaning |
|---|---|---|
| Date | 2025-10-01 | Date |
| Year | 2025 | Year |
| Month | Oct | Month |
| Month Number | 10 | Month number |
| Year Month | 2025-10 | Year month |
| Year Month Sort | 202510 | Year month sort |
| Quarter | Q4 | Quarter |

## events.csv

| Column | Type/example | Meaning |
|---|---|---|
| event_id | 1 | Event id |
| session_id | 189843 | Unique browsing-session key. |
| event_timestamp | 2025-10-01 00:00:31 | Event timestamp |
| event_name | session_start | Event name |
| product_id | nullable | Product id |
| order_id | nullable | Order id |

## events_clean.csv

| Column | Type/example | Meaning |
|---|---|---|
| event_id | 1 | Event id |
| session_id | 189843 | Unique browsing-session key. |
| event_timestamp | 2025-10-01 00:00:31 | Event timestamp |
| event_name | session_start | Event name |
| product_id | nullable | Product id |
| order_id | nullable | Order id |

## funnel_stages.csv

| Column | Type/example | Meaning |
|---|---|---|
| Stage | Sessions | Stage |
| Stage Order | 1 | 1 sessions, 2 product view, 3 cart, 4 checkout, 5 purchase. |

## month_offsets.csv

| Column | Type/example | Meaning |
|---|---|---|
| Month Offset | 0 | Month offset |

## orders.csv

| Column | Type/example | Meaning |
|---|---|---|
| order_id | 1 | Order id |
| session_id | 199510 | Unique browsing-session key. |
| customer_id | nullable | Registered customer key; derived features use 0 for anonymous sessions. |
| order_timestamp | 2025-10-01 00:59:25 | Order timestamp |
| order_value_inr | 14318.94 | Full completed-order amount in INR, not a product line amount. |
| order_status | Completed | Order status |

## orders_clean.csv

| Column | Type/example | Meaning |
|---|---|---|
| order_id | 1 | Order id |
| session_id | 199510 | Unique browsing-session key. |
| customer_id | nullable | Registered customer key; derived features use 0 for anonymous sessions. |
| order_timestamp | 2025-10-01 00:59:25 | Order timestamp |
| order_value_inr | 14318.94 | Full completed-order amount in INR, not a product line amount. |
| order_status | Completed | Order status |

## products.csv

| Column | Type/example | Meaning |
|---|---|---|
| product_id | 1 | Product id |
| product_name | Smartphone - Variant 01 | Product name |
| category | Electronics | Category |
| price_inr | 37839.02 | Price inr |

## session_features.csv

| Column | Type/example | Meaning |
|---|---|---|
| session_id | 189843 | Unique browsing-session key. |
| customer_id | 0 | Registered customer key; derived features use 0 for anonymous sessions. |
| visitor_id | ANON008082 | Persistent synthetic visitor identity; includes registered and anonymous visitors. |
| session_start | 2025-10-01 00:00:31 | Session start |
| session_end | 2025-10-01 00:15:31 | Session end |
| device_type | Mobile | Device type |
| channel | Social | Channel |
| campaign_id | 0 | Campaign key; derived model uses 0 for unattributed sessions. |
| landing_page | /offers | Landing page |
| viewed_flag | 0 | Viewed flag |
| cart_flag | 0 | Cart flag |
| checkout_flag | 0 | Checkout flag |
| purchase_flag | 0 | 1 if the ordered view -> cart -> checkout -> purchase sequence exists. |
| page_views | 1 | Page views |
| duration_seconds | 900 | Duration seconds |
| engaged_flag | 1 | 1 if duration >10 seconds OR page_views >=2 OR purchase; this rule is saturated. |
| revenue_inr | 0.0 | Completed-order amounts aggregated once per session. |
| order_count | 0 | Order count |
| city | Unknown / anonymous | City |
| state | Unknown / anonymous | State |
| customer_type | Anonymous | Customer type |
| session_date | 2025-10-01 | Session date |
| first_visit_date | 2025-10-01 | First visit date |
| user_type | New | New if on the visitor's first observed calendar day; Returning on later days. |

## sessions.csv

| Column | Type/example | Meaning |
|---|---|---|
| session_id | 189843 | Unique browsing-session key. |
| customer_id | nullable | Registered customer key; derived features use 0 for anonymous sessions. |
| visitor_id | ANON008082 | Persistent synthetic visitor identity; includes registered and anonymous visitors. |
| session_start | 2025-10-01 00:00:31 | Session start |
| session_end | 2025-10-01 00:15:31 | Session end |
| device_type | Mobile | Device type |
| channel | Social | Channel |
| campaign_id | nullable | Campaign key; derived model uses 0 for unattributed sessions. |
| landing_page | /offers | Landing page |

## visitor_features.csv

| Column | Type/example | Meaning |
|---|---|---|
| visitor_id | ANON008082 | Persistent synthetic visitor identity; includes registered and anonymous visitors. |
| customer_id | 0 | Registered customer key; derived features use 0 for anonymous sessions. |
| first_visit_date | 2025-10-01 | First visit date |
| first_channel | Social | Channel on the first observed session. |
| first_device | Mobile | Device on the first observed session. |
| city | Unknown / anonymous | City |
| state | Unknown / anonymous | State |
| customer_type | Anonymous | Customer type |
| cohort_month | 2025-10-01 | Calendar month of first observed visit. |
| cohort_label | 2025-10 | Cohort label |
| eligible_d1 | 1 | 1 when this visitor has enough follow-up days before the global data boundary. |
| retained_d1 | 0 | 1 when the visitor had a session exactly N calendar days after first observed visit. |
| eligible_d7 | 1 | 1 when this visitor has enough follow-up days before the global data boundary. |
| retained_d7 | 0 | 1 when the visitor had a session exactly N calendar days after first observed visit. |
| eligible_d30 | 1 | 1 when this visitor has enough follow-up days before the global data boundary. |
| retained_d30 | 0 | 1 when the visitor had a session exactly N calendar days after first observed visit. |
| session_count | 3 | Session count |
| active_days | 3 | Active days |
| lifetime_revenue_inr | 5967.36 | Lifetime revenue inr |
| lifetime_orders | 1 | Lifetime orders |
| repeat_visitor_flag | 1 | Repeat visitor flag |
| repeat_buyer_flag | 0 | Repeat buyer flag |