-- READ-ONLY VALIDATION AND EXPECTED RESULTS
USE digital_customer_journey;

-- VERIFY SOURCE COUNTS: 50,000 / 60 / 500 / 200,000 / 1,000,291 / 15,852
SELECT 'customers' AS source,COUNT(*) AS rows_found FROM customers
UNION ALL SELECT 'campaigns',COUNT(*) FROM campaigns
UNION ALL SELECT 'products',COUNT(*) FROM products
UNION ALL SELECT 'sessions',COUNT(*) FROM sessions
UNION ALL SELECT 'events',COUNT(*) FROM events
UNION ALL SELECT 'orders',COUNT(*) FROM orders;

-- VERIFY SESSION KEYS: EXPECT 0 DUPLICATES
SELECT COUNT(*)-COUNT(DISTINCT session_id) AS duplicate_session_ids FROM sessions;

-- VERIFY PURCHASE MATCHES: EXPECT 15,852 MATCHES AND 0 MISMATCHES
SELECT COUNT(*) AS purchase_events,
 SUM(o.order_id IS NULL) AS missing_orders,
 SUM(e.session_id<>o.session_id) AS session_mismatches,
 SUM(e.event_timestamp<>o.order_timestamp) AS timestamp_mismatches
FROM events e LEFT JOIN orders o ON e.order_id=o.order_id WHERE e.event_name='purchase';

-- VERIFY EVENT CHRONOLOGY: EXPECT 0 VIOLATIONS
SELECT SUM(e.event_timestamp<s.session_start OR e.event_timestamp>s.session_end) AS out_of_session_events
FROM events e JOIN sessions s ON e.session_id=s.session_id;

-- VERIFY REVENUE AND CONVERSION
-- EXPECT 200,000 SESSIONS; 68,967 VISITORS; 15,852 ORDERS;
-- REVENUE 397350417.76; CONVERSION 0.07926; AOV APPROX 25066.26
SELECT * FROM vw_business_kpis;

-- VERIFY ORDERED FUNNEL: 200000 / 149398 / 89644 / 45602 / 15852
SELECT * FROM vw_funnel ORDER BY stage_order;

-- VERIFY EXACT-DAY RETENTION WITH MATURE DENOMINATORS
-- EXPECT APPROX 0.02721495 / 0.02098802 / 0.01409813
SELECT SUM(retained_d1*eligible_d1)/SUM(eligible_d1) AS d1_retention,
 SUM(retained_d7*eligible_d7)/SUM(eligible_d7) AS d7_retention,
 SUM(retained_d30*eligible_d30)/SUM(eligible_d30) AS d30_retention
FROM vw_visitor_retention;

-- REVIEW CAMPAIGN OPPORTUNITIES: SCORES ARE PRIORITIES, NOT FORECASTS
SELECT * FROM vw_campaign_opportunity WHERE sessions>=100 ORDER BY opportunity_score DESC;
