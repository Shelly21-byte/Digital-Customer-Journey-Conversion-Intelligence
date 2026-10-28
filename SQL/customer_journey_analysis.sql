-- 1. CREATE DATABASE
CREATE DATABASE IF NOT EXISTS
digital_customer_journey;
USE digital_customer_journey;

-- Verify active database
SELECT DATABASE() AS active_database;

-- 2. CUSTOMERS TABLE
USE digital_customer_journey;
CREATE TABLE IF NOT EXISTS customers (
    customer_id INT PRIMARY KEY,
    signup_date DATETIME NOT NULL,
    city VARCHAR(100),
    state VARCHAR(100),
    acquisition_channel VARCHAR(50)
);

-- Verify customers data
USE digital_customer_journey;
SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_id) AS unique_customers,
    MIN(signup_date) AS earliest_signup,
    MAX(signup_date) AS latest_signup
FROM customers;

-- 3. CAMPAIGNS TABLE
USE digital_customer_journey;
CREATE TABLE IF NOT EXISTS campaigns (
    campaign_id INT PRIMARY KEY,
    campaign_name VARCHAR(150),
    channel VARCHAR(50),
    start_date DATE,
    end_date DATE,
    campaign_spend DECIMAL(12,2)
);

-- Verify campaigns data
SELECT
    COUNT(*) AS total_campaigns,
    COUNT(DISTINCT campaign_id) AS unique_campaigns,
    ROUND(SUM(campaign_spend), 2) AS total_campaign_spend
FROM digital_customer_journey.campaigns;

-- 4. PRODUCTS TABLE
USE digital_customer_journey;
CREATE TABLE IF NOT EXISTS products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150),
    category VARCHAR(100),
    price_inr DECIMAL(12,2)
);

-- Verify products data after CSV import
USE digital_customer_journey;
CREATE TABLE IF NOT EXISTS products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(150),
    category VARCHAR(100),
    price_inr DECIMAL(12,2)
);

-- SECTION 05: VERIFY PRODUCTS DATA
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT category) AS total_categories,
    MIN(price_inr) AS minimum_price,
    MAX(price_inr) AS maximum_price
FROM products;

-- SECTION 05: VERIFY PRODUCTS DATA
-- Purpose: Confirm successful CSV import
SELECT
    COUNT(*) AS total_products,
    COUNT(DISTINCT product_id) AS unique_products,
    COUNT(DISTINCT category) AS total_categories
FROM products;

-- SECTION 06: CREATE SESSIONS TABLE
-- Purpose: Store customer browsing sessions
CREATE TABLE IF NOT EXISTS sessions (
    session_id INT PRIMARY KEY,
    customer_id INT NULL,
    visitor_id VARCHAR(50) NOT NULL,
    session_start DATETIME NOT NULL,
    session_end DATETIME NOT NULL,
    device_type VARCHAR(50),
    channel VARCHAR(50),
    campaign_id INT NULL,
    landing_page VARCHAR(150),
    FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),
    FOREiGN KEY (campaign_id)
        REFERENCES campaigns(campaign_id)
);

-- SECTION 07: CHECK SESSIONS IMPORT STATUS
-- Purpose: Count records after failed CSV import
SELECT 
    COUNT(*) AS imported_sessions
FROM
    sessions;

-- SECTION 08: CLEAR PARTIAL SESSIONS IMPORT
-- Purpose: Remove partially imported sessions
TRUNCATE TABLE sessions;

-- SECTION 09: VERIFY SESSIONS TABLE IS EMPTY
-- Purpose: Confirm successful cleanup
SELECT
    COUNT(*) AS remaining_sessions
FROM sessions;

-- SECTION 10: CHECK MYSQL FILE IMPORT SETTINGS
-- Purpose: Identify permitted CSV import methods
SHOW GLOBAL VARIABLES LIKE 'local_infile';
SHOW GLOBAL VARIABLES LIKE 'secure_file_priv';

-- SECTION 11: CHECK SECURE FILE PRIVILEGES
-- Purpose: Check server-side file restrictions
SHOW GLOBAL VARIABLES LIKE 'secure_file_priv';

-- SECTION 12: IMPORT SESSIONS DATA
-- Purpose: Import 200,000 sessions from CSV
-- and convert missing foreign keys to NULL
LOAD DATA LOCAL INFILE
'C:/Users/shell/Downloads/Digital-Customer-Journey-Analytics/DATA/sessions.csv'
INTO TABLE sessions
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    session_id,
    @customer_id,
    visitor_id,
    session_start,
    session_end,
    device_type,
    channel,
    @campaign_id,
    landing_page
)
SET
    customer_id = NULLIF(TRIM(@customer_id), ''),
    campaign_id = NULLIF(TRIM(@campaign_id), '');
    
-- SECTION 13: VERIFY SESSIONS DATA
-- Purpose: Confirm all 200,000 sessions
-- were imported successfully
SELECT
    COUNT(*) AS total_sessions,
    COUNT(DISTINCT session_id) AS unique_sessions,
    COUNT(DISTINCT visitor_id) AS unique_visitors,
    SUM(customer_id IS NULL) AS anonymous_sessions,
    SUM(customer_id IS NOT NULL) AS registered_sessions
FROM sessions;

-- SECTION 14: CREATE EVENTS TABLE
-- Purpose: Store customer journey events
-- including page views, cart actions,
-- checkout activity and purchases

CREATE TABLE IF NOT EXISTS events (
    event_id INT PRIMARY KEY,
    session_id INT NOT NULL,
    event_timestamp DATETIME NOT NULL,
    event_name VARCHAR(50) NOT NULL,
    product_id INT NULL,
    order_id INT NULL,
    FOREIGN KEY (session_id)
        REFERENCES sessions(session_id),
    FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);

-- SECTION 15: IMPORT EVENTS DATA
-- Purpose: Import customer journey events
-- and handle missing product/order IDs
LOAD DATA LOCAL INFILE
'C:/Users/shell/Downloads/Digital-Customer-Journey-Analytics/DATA/events.csv'
INTO TABLE events
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    event_id,
    session_id,
    event_timestamp,
    event_name,
    @product_id,
    @order_id
)
SET
    product_id = NULLIF(TRIM(@product_id), ''),
    order_id = NULLIF(TRIM(@order_id), '');
    
-- SECTION 16: VERIFY EVENTS DATA IMPORT
-- Purpose: Check imported event records
-- and validate unique event IDs
SELECT
    COUNT(*) AS total_events,
    COUNT(DISTINCT event_id) AS unique_events,
    COUNT(DISTINCT session_id) AS sessions_with_events,
    COUNT(*) - COUNT(DISTINCT event_id) AS duplicate_events
FROM events;


-- ==========================================
-- SECTION 17: VALIDATE EVENT TYPES
-- Purpose: Check customer journey event counts
-- after importing the CSV into MySQL
-- ==========================================

SELECT
    event_name,
    COUNT(*) AS total_events
FROM events
GROUP BY event_name
ORDER BY total_events DESC;

-- SECTION 18: VALIDATE EVENT NULL VALUES
-- Purpose: Check missing IDs and timestamps
SELECT
    SUM(session_id IS NULL) AS missing_session_ids,
    SUM(event_timestamp IS NULL) AS missing_timestamps,
    SUM(event_name IS NULL OR event_name = '') AS missing_event_names,
    SUM(product_id IS NULL) AS events_without_products,
    SUM(order_id IS NULL) AS events_without_orders
FROM events;

-- SECTION 19: INVESTIGATE EVENT ORDER IDS
-- Purpose: Detect incorrect zero values
-- introduced during CSV import
SELECT
    COUNT(*) AS total_events,
    SUM(order_id = 0) AS zero_order_ids,
    SUM(order_id IS NULL) AS null_order_ids,
    SUM(order_id > 0) AS valid_order_ids
FROM events;

-- SECTION 20: CLEAN EVENT ORDER IDS
-- Purpose: Convert invalid zero order IDs
-- into SQL NULL values

-- Temporarily disable Safe Update Mode
SET SQL_SAFE_UPDATES = 0;

-- Correct missing order IDs
UPDATE events
SET order_id = NULL
WHERE order_id = 0;

-- Re-enable Safe Update Mode
SET SQL_SAFE_UPDATES = 1;

-- SECTION 21: VERIFY ORDER ID CLEANING
-- Purpose: Validate corrected order IDs
SELECT
    COUNT(*) AS total_events,
    SUM(order_id = 0) AS zero_order_ids,
    SUM(order_id IS NULL) AS null_order_ids,
    SUM(order_id > 0) AS valid_order_ids
FROM events;

-- SECTION 22: CREATE ORDERS TABLE
-- Purpose: Store completed customer purchases
-- and their associated revenue
CREATE TABLE IF NOT EXISTS orders (
    order_id INT PRIMARY KEY,
    session_id INT NOT NULL,
    customer_id INT NULL,
    order_timestamp DATETIME NOT NULL,
    order_value_inr DECIMAL(12,2) NOT NULL,
    order_status VARCHAR(30),
    FOREIGN KEY (session_id)
        REFERENCES sessions(session_id),
    FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);

-- SECTION 23: IMPORT ORDERS DATA
-- Purpose: Import 15,852 completed orders
-- and handle missing customer IDs
LOAD DATA LOCAL INFILE
'C:/Users/shell/Downloads/Digital-Customer-Journey-Analytics/DATA/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    order_id,
    session_id,
    @customer_id,
    order_timestamp,
    order_value_inr,
    order_status
)
SET
    customer_id = NULLIF(TRIM(@customer_id), '');
    
-- SECTION 24: VERIFY ORDERS DATA
-- Purpose: Validate imported orders,
-- customer IDs and total revenue
SELECT
    COUNT(*) AS total_orders,
    COUNT(DISTINCT order_id) AS unique_orders,
    SUM(customer_id IS NULL) AS anonymous_orders,
    SUM(customer_id = 0) AS zero_customer_ids,
    ROUND(SUM(order_value_inr), 2) AS total_revenue_inr,
    COUNT(DISTINCT session_id) AS purchasing_sessions
FROM orders;

-- SECTION 25: VALIDATE ORDERS AND SESSIONS
-- Purpose: Check whether every order
-- belongs to a valid browsing session
SELECT
    COUNT(*) AS total_orders,
    SUM(
        CASE
            WHEN s.session_id IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_sessions,
    SUM(
        CASE
            WHEN NOT (o.customer_id <=> s.customer_id)
            THEN 1
            ELSE 0
        END
    ) AS customer_id_mismatches
FROM orders o
LEFT JOIN sessions s
    ON o.session_id = s.session_id;
    
-- SECTION 26: VALIDATE PURCHASE EVENTS
-- Purpose: Verify purchase events match
-- completed orders and their sessions
SELECT
    COUNT(*) AS total_purchase_events,
    SUM(
        CASE
            WHEN o.order_id IS NULL THEN 1
            ELSE 0
        END
    ) AS purchases_without_orders,
    SUM(
        CASE
            WHEN o.order_id IS NOT NULL
             AND e.session_id <> o.session_id
            THEN 1
            ELSE 0
        END
    ) AS session_mismatches,
    SUM(
        CASE
            WHEN o.order_id IS NOT NULL
             AND e.event_timestamp <> o.order_timestamp
            THEN 1
            ELSE 0
        END
    ) AS timestamp_mismatches,
    COUNT(DISTINCT e.order_id) AS unique_purchase_orders
FROM events e
LEFT JOIN orders o
    ON e.order_id = o.order_id
WHERE e.event_name = 'purchase';

-- SECTION 27: VALIDATE ORDER RECONCILIATION
-- Purpose: Ensure every completed order
-- has exactly one matching purchase event
SELECT
    COUNT(*) AS total_orders,
    SUM(
        CASE
            WHEN p.purchase_count IS NULL THEN 1
            ELSE 0
        END
    ) AS orders_without_purchase_events,
    SUM(
        CASE
            WHEN p.purchase_count > 1 THEN 1
            ELSE 0
        END
    ) AS orders_with_duplicate_purchases
FROM orders o
LEFT JOIN (
    SELECT
        order_id,
        COUNT(*) AS purchase_count
    FROM events
    WHERE event_name = 'purchase'
    GROUP BY order_id
) p
    ON o.order_id = p.order_id;
    
-- SECTION 28: OVERALL BUSINESS KPIs
-- Purpose: Calculate total sessions, visitors,
-- orders, revenue, conversion rate and AOV
SELECT
    s.total_sessions,
    s.unique_visitors,
    o.total_orders,
    o.total_revenue_inr,
    ROUND(
        o.total_orders * 100.0 /
        NULLIF(s.total_sessions, 0),
        2
    ) AS conversion_rate_pct,
    ROUND(
        o.total_revenue_inr /
        NULLIF(o.total_orders, 0),
        2
    ) AS average_order_value_inr
FROM (
    SELECT
        COUNT(*) AS total_sessions,
        COUNT(DISTINCT visitor_id) AS unique_visitors
    FROM sessions
) s
CROSS JOIN (
    SELECT
        COUNT(*) AS total_orders,
        ROUND(SUM(order_value_inr), 2)
            AS total_revenue_inr
    FROM orders
    WHERE order_status = 'Completed'
) o;

-- SECTION 29: INVESTIGATE ORDER STATUS
-- Purpose: Identify why completed orders
-- are missing from the business KPI query
SELECT
    COALESCE(
        CONCAT('[', order_status, ']'),
        '[NULL]'
    ) AS stored_order_status,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY total_orders DESC;

-- SECTION 30: DIAGNOSE ORDER STATUS FILTER
-- Purpose: Compare total orders with orders
-- matching the Completed status condition
SELECT
    COUNT(*) AS all_orders,
    COUNT(CASE WHEN order_status = 'Completed'
        THEN 1 END) AS completed_orders,
    ROUND(SUM(order_value_inr), 2) AS total_revenue_inr
FROM digital_customer_journey.orders;

-- SECTION 31: INSPECT ORDER STATUS VALUES
-- Purpose: Identify exact status values,
-- including hidden spaces or characters
SELECT
    CONCAT('[', order_status, ']') AS order_status_value,
    HEX(order_status) AS status_hex,
    LENGTH(order_status) AS status_length,
    COUNT(*) AS total_orders
FROM orders
GROUP BY order_status;

-- SECTION 32: CLEAN ORDER STATUS VALUES
-- Purpose: Remove hidden carriage returns
-- introduced during CSV import
SET SQL_SAFE_UPDATES = 0;
UPDATE orders
SET order_status = TRIM(
    REPLACE(order_status, CHAR(13), '')
)
WHERE order_status LIKE CONCAT('%', CHAR(13), '%');
SET SQL_SAFE_UPDATES = 1;

-- SECTION 33: VERIFY ORDER STATUS CLEANING
-- Purpose: Confirm completed orders and
-- revenue are correctly recognized
SELECT
    COUNT(*) AS total_orders,
    SUM(order_status = 'Completed') AS completed_orders,
    ROUND(SUM(order_value_inr), 2) AS total_revenue_inr
FROM orders;

-- SECTION 32: CLEAN ORDER STATUS VALUES
-- Purpose: Remove hidden carriage returns
-- introduced during CSV import
SET SQL_SAFE_UPDATES = 0;
UPDATE orders
SET order_status = TRIM(
    REPLACE(order_status, CHAR(13), '')
)
WHERE order_status LIKE CONCAT('%', CHAR(13), '%');
SET SQL_SAFE_UPDATES = 1;

-- SECTION 33: VERIFY ORDER STATUS CLEANING
-- Purpose: Confirm completed orders and
-- revenue are correctly recognized
SELECT
    COUNT(*) AS total_orders,
    SUM(order_status = 'Completed') AS completed_orders,
    ROUND(SUM(order_value_inr), 2) AS total_revenue_inr
FROM orders;

-- SECTION 34: FINAL OVERALL BUSINESS KPIs
-- Purpose: Calculate validated business
-- metrics for the Power BI dashboard
SELECT
    s.total_sessions,
    s.unique_visitors,
    o.total_orders,
    o.total_revenue_inr,
    ROUND(
        o.total_orders * 100.0 /
        NULLIF(s.total_sessions, 0),
        2
    ) AS conversion_rate_pct,
    ROUND(
        o.total_revenue_inr /
        NULLIF(o.total_orders, 0),
        2
    ) AS average_order_value_inr
FROM (
    SELECT
        COUNT(*) AS total_sessions,
        COUNT(DISTINCT visitor_id) AS unique_visitors
    FROM sessions
) s
CROSS JOIN (
    SELECT
        COUNT(*) AS total_orders,
        ROUND(SUM(order_value_inr), 2)
            AS total_revenue_inr
    FROM orders
    WHERE order_status = 'Completed'
) o;

-- SECTION 35: VERIFY ORDER STATUS FIX
-- Purpose: Check whether hidden characters
-- remain after cleaning order statuses
SELECT
    CONCAT('[', order_status, ']') AS status_value,
    HEX(order_status) AS status_hex,
    LENGTH(order_status) AS status_length,
    COUNT(*) AS total_orders
FROM digital_customer_journey.orders
GROUP BY order_status;

-- SECTION 36: FIX HIDDEN ORDER STATUS CHARACTER
-- Purpose: Remove trailing carriage returns
-- so completed orders are counted correctly
UPDATE digital_customer_journey.orders
SET order_status = REPLACE(order_status, CHAR(13), '')
WHERE order_id > 0
  AND INSTR(order_status, CHAR(13)) > 0;

-- Verify the fix
SELECT
    COUNT(*) AS total_orders,
    SUM(order_status = 'Completed') AS completed_orders,
    MIN(LENGTH(order_status)) AS min_status_length,
    MAX(LENGTH(order_status)) AS max_status_length
FROM digital_customer_journey.orders;

-- SECTION 37: VERIFIED BUSINESS KPIs
-- Purpose: Calculate overall sessions,
-- visitors, orders, revenue, conversion
-- rate and average order value
SELECT
    s.total_sessions,
    s.unique_visitors,
    o.total_orders,
    o.total_revenue_inr,
    ROUND(
        o.total_orders * 100.0 /
        NULLIF(s.total_sessions, 0),
        2
    ) AS conversion_rate_pct,
    ROUND(
        o.total_revenue_inr /
        NULLIF(o.total_orders, 0),
        2
    ) AS average_order_value_inr
FROM (
    SELECT
        COUNT(*) AS total_sessions,
        COUNT(DISTINCT visitor_id) AS unique_visitors
    FROM sessions
) s
CROSS JOIN (
    SELECT
        COUNT(*) AS total_orders,
        ROUND(SUM(order_value_inr), 2)
            AS total_revenue_inr
    FROM orders
    WHERE order_status = 'Completed'
) o;

-- SECTION 38: CUSTOMER JOURNEY FUNNEL
-- Purpose: Count unique sessions reaching
-- each stage of the shopping journey
SELECT
    COUNT(DISTINCT session_id) AS total_sessions,
    COUNT(DISTINCT CASE
        WHEN event_name = 'view_item'
        THEN session_id
    END) AS product_view_sessions,
    COUNT(DISTINCT CASE
        WHEN event_name = 'add_to_cart'
        THEN session_id
    END) AS add_to_cart_sessions,
    COUNT(DISTINCT CASE
        WHEN event_name = 'begin_checkout'
        THEN session_id
    END) AS checkout_sessions,
    COUNT(DISTINCT CASE
        WHEN event_name = 'purchase'
        THEN session_id
    END) AS purchase_sessions
FROM events;

-- SECTION 39: FUNNEL DROP-OFF ANALYSIS
-- Purpose: Calculate conversion and
-- drop-off percentages between stages
WITH funnel AS (
    SELECT
        COUNT(DISTINCT session_id) AS sessions,
        COUNT(DISTINCT CASE
            WHEN event_name = 'view_item'
            THEN session_id END) AS product_views,
        COUNT(DISTINCT CASE
            WHEN event_name = 'add_to_cart'
            THEN session_id END) AS add_to_cart,
        COUNT(DISTINCT CASE
            WHEN event_name = 'begin_checkout'
            THEN session_id END) AS checkout,
        COUNT(DISTINCT CASE
            WHEN event_name = 'purchase'
            THEN session_id END) AS purchases
    FROM events
)
SELECT
    'Session to Product View' AS funnel_stage,
    ROUND(product_views * 100.0 /
        NULLIF(sessions, 0), 2) AS conversion_pct,
    ROUND((sessions - product_views) * 100.0 /
        NULLIF(sessions, 0), 2) AS drop_off_pct
FROM funnel
UNION ALL
SELECT
    'Product View to Cart',
    ROUND(add_to_cart * 100.0 /
        NULLIF(product_views, 0), 2),
    ROUND((product_views - add_to_cart) * 100.0 /
        NULLIF(product_views, 0), 2)
FROM funnel
UNION ALL
SELECT
    'Cart to Checkout',
    ROUND(checkout * 100.0 /
        NULLIF(add_to_cart, 0), 2),
    ROUND((add_to_cart - checkout) * 100.0 /
        NULLIF(add_to_cart, 0), 2)
FROM funnel
UNION ALL
SELECT
    'Checkout to Purchase',
    ROUND(purchases * 100.0 /
        NULLIF(checkout, 0), 2),
    ROUND((checkout - purchases) * 100.0 /
        NULLIF(checkout, 0), 2)
FROM funnel;

-- SECTION 40: CHANNEL PERFORMANCE ANALYSIS
-- Purpose: Compare marketing channels by
-- sessions, orders, revenue and conversion

SELECT
    s.channel AS marketing_channel,
    COUNT(DISTINCT s.session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        COALESCE(SUM(o.order_value_inr), 0),
        2
    ) AS total_revenue_inr,
    ROUND(
        COUNT(DISTINCT o.order_id) * 100.0 /
        NULLIF(COUNT(DISTINCT s.session_id), 0),
        2
    ) AS conversion_rate_pct
FROM sessions s
LEFT JOIN orders o
    ON s.session_id = o.session_id
    AND o.order_status = 'Completed'
GROUP BY s.channel
ORDER BY total_revenue_inr DESC;

-- SECTION 41: CAMPAIGN PERFORMANCE AND ROAS
-- Purpose: Measure campaign sessions,
-- orders, revenue, spend and return on
-- advertising spend
WITH campaign_performance AS (
    SELECT
        c.campaign_id,
        c.campaign_name,
        c.channel,
        c.campaign_spend,
        COUNT(DISTINCT s.session_id) AS total_sessions,
        COUNT(DISTINCT o.order_id) AS total_orders,
        COALESCE(
            SUM(o.order_value_inr), 0
        ) AS total_revenue_inr
    FROM campaigns c
    LEFT JOIN sessions s
        ON c.campaign_id = s.campaign_id
    LEFT JOIN orders o
        ON s.session_id = o.session_id
        AND o.order_status = 'Completed'
    GROUP BY
        c.campaign_id,
        c.campaign_name,
        c.channel,
        c.campaign_spend
)
SELECT
    campaign_id,
    campaign_name,
    channel,
    total_sessions,
    total_orders,
    ROUND(total_revenue_inr, 2)
        AS total_revenue_inr,
    campaign_spend,
    ROUND(
        total_orders * 100.0 /
        NULLIF(total_sessions, 0), 2
    ) AS conversion_rate_pct,
    ROUND(
        total_revenue_inr /
        NULLIF(campaign_spend, 0), 2
    ) AS roas
FROM campaign_performance
ORDER BY roas DESC;

-- SECTION 42: DEVICE PERFORMANCE ANALYSIS
-- Purpose: Compare device types by sessions,
-- orders, revenue, conversion rate and AOV
SELECT
    s.device_type,
    COUNT(DISTINCT s.session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(
        COALESCE(SUM(o.order_value_inr), 0),
        2
    ) AS total_revenue_inr,
    ROUND(
        COUNT(DISTINCT o.order_id) * 100.0 /
        NULLIF(COUNT(DISTINCT s.session_id), 0),
        2
    ) AS conversion_rate_pct,
    ROUND(
        COALESCE(SUM(o.order_value_inr), 0) /
        NULLIF(COUNT(DISTINCT o.order_id), 0),
        2
    ) AS average_order_value_inr
FROM sessions s

LEFT JOIN orders o
    ON s.session_id = o.session_id
    AND o.order_status = 'Completed'
GROUP BY s.device_type
ORDER BY total_revenue_inr DESC;

-- SECTION 43: CART AND CHECKOUT ABANDONMENT
-- Purpose: Identify sessions that reached
-- cart or checkout but did not purchase

WITH session_funnel AS (
    SELECT
        session_id,

        MAX(CASE
            WHEN event_name = 'add_to_cart'
            THEN 1 ELSE 0
        END) AS added_to_cart,

        MAX(CASE
            WHEN event_name = 'begin_checkout'
            THEN 1 ELSE 0
        END) AS started_checkout,

        MAX(CASE
            WHEN event_name = 'purchase'
            THEN 1 ELSE 0
        END) AS purchased

    FROM events
    GROUP BY session_id
)

SELECT
    SUM(added_to_cart) AS cart_sessions,

    SUM(
        CASE
            WHEN added_to_cart = 1
             AND purchased = 0
            THEN 1 ELSE 0
        END
    ) AS abandoned_cart_sessions,

    ROUND(
        SUM(
            CASE
                WHEN added_to_cart = 1
                 AND purchased = 0
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(SUM(added_to_cart), 0),
        2
    ) AS cart_abandonment_pct,

    SUM(started_checkout) AS checkout_sessions,

    SUM(
        CASE
            WHEN started_checkout = 1
             AND purchased = 0
            THEN 1 ELSE 0
        END
    ) AS abandoned_checkout_sessions,

    ROUND(
        SUM(
            CASE
                WHEN started_checkout = 1
                 AND purchased = 0
                THEN 1 ELSE 0
            END
        ) * 100.0 /
        NULLIF(SUM(started_checkout), 0),
        2
    ) AS checkout_abandonment_pct

FROM session_funnel;

-- SECTION 44: DAILY REVENUE TREND ANALYSIS
-- Purpose: Analyze daily completed orders,
-- revenue and average order value
SELECT
    DATE(order_timestamp) AS order_date,

    COUNT(order_id) AS total_orders,

    ROUND(
        SUM(order_value_inr), 2
    ) AS daily_revenue_inr,

    ROUND(
        AVG(order_value_inr), 2
    ) AS average_order_value_inr

FROM orders

WHERE order_status = 'Completed'

GROUP BY DATE(order_timestamp)

ORDER BY order_date;

-- SECTION 45: CUSTOMER RETENTION ANALYSIS
-- Purpose: Measure D1, D7 and D30 visitor
-- retention using first visit dates
-- and subsequent browsing sessions
WITH daily_visits AS (
    SELECT DISTINCT
        visitor_id,
        DATE(session_start) AS visit_date
    FROM sessions
),

first_visits AS (
    SELECT
        visitor_id,
        MIN(visit_date) AS first_visit_date
    FROM daily_visits
    GROUP BY visitor_id
),

visitor_retention AS (
    SELECT
        f.visitor_id,
        f.first_visit_date,

        MAX(CASE
            WHEN DATEDIFF(d.visit_date,
                          f.first_visit_date) = 1
            THEN 1 ELSE 0
        END) AS retained_d1,

        MAX(CASE
            WHEN DATEDIFF(d.visit_date,
                          f.first_visit_date) = 7
            THEN 1 ELSE 0
        END) AS retained_d7,

        MAX(CASE
            WHEN DATEDIFF(d.visit_date,
                          f.first_visit_date) = 30
            THEN 1 ELSE 0
        END) AS retained_d30

    FROM first_visits f

    LEFT JOIN daily_visits d
        ON f.visitor_id = d.visitor_id

    GROUP BY
        f.visitor_id,
        f.first_visit_date
),

data_boundary AS (
    SELECT MAX(DATE(session_start)) AS last_date
    FROM sessions
)

SELECT
    COUNT(*) AS total_unique_visitors,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN first_visit_date <=
                     DATE_SUB(last_date, INTERVAL 1 DAY)
                THEN retained_d1 ELSE 0
            END
        ) /
        NULLIF(SUM(
            first_visit_date <=
            DATE_SUB(last_date, INTERVAL 1 DAY)
        ), 0),
        2
    ) AS d1_retention_pct,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN first_visit_date <=
                     DATE_SUB(last_date, INTERVAL 7 DAY)
                THEN retained_d7 ELSE 0
            END
        ) /
        NULLIF(SUM(
            first_visit_date <=
            DATE_SUB(last_date, INTERVAL 7 DAY)
        ), 0),
        2
    ) AS d7_retention_pct,

    ROUND(
        100.0 * SUM(
            CASE
                WHEN first_visit_date <=
                     DATE_SUB(last_date, INTERVAL 30 DAY)
                THEN retained_d30 ELSE 0
            END
        ) /
        NULLIF(SUM(
            first_visit_date <=
            DATE_SUB(last_date, INTERVAL 30 DAY)
        ), 0),
        2
    ) AS d30_retention_pct

FROM visitor_retention
CROSS JOIN data_boundary;


















