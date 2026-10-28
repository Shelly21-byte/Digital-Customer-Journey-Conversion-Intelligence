-- ANALYTICAL VIEWS: MYSQL 8+; RUN AFTER SCHEMA AND IMPORT
USE digital_customer_journey;

-- ORDERED EVENT TIMESTAMPS: FIRST OCCURRENCE OF EACH SHOPPING STAGE
CREATE OR REPLACE VIEW vw_session_stages AS
SELECT session_id,
 MIN(CASE WHEN event_name='view_item' THEN event_timestamp END) AS view_at,
 MIN(CASE WHEN event_name='add_to_cart' THEN event_timestamp END) AS cart_at,
 MIN(CASE WHEN event_name='begin_checkout' THEN event_timestamp END) AS checkout_at,
 MIN(CASE WHEN event_name='purchase' THEN event_timestamp END) AS purchase_at,
 SUM(event_name='page_view') AS page_views
FROM events GROUP BY session_id;

-- SESSION FEATURES: SAFE AGGREGATION BEFORE JOINING ORDERS AND EVENTS
CREATE OR REPLACE VIEW vw_session_features AS
SELECT s.*, DATE(s.session_start) AS session_date,
 COALESCE(c.city,'Unknown / anonymous') AS city,
 COALESCE(c.state,'Unknown / anonymous') AS state,
 TIMESTAMPDIFF(SECOND,s.session_start,s.session_end) AS duration_seconds,
 COALESCE(f.page_views,0) AS page_views,
 (f.view_at IS NOT NULL) AS viewed_flag,
 COALESCE(f.view_at IS NOT NULL AND f.cart_at>=f.view_at,0) AS cart_flag,
 COALESCE(f.view_at IS NOT NULL AND f.cart_at>=f.view_at AND f.checkout_at>=f.cart_at,0) AS checkout_flag,
 COALESCE(f.view_at IS NOT NULL AND f.cart_at>=f.view_at AND f.checkout_at>=f.cart_at AND f.purchase_at>=f.checkout_at,0) AS purchase_flag,
 (TIMESTAMPDIFF(SECOND,s.session_start,s.session_end)>10 OR COALESCE(f.page_views,0)>=2 OR f.purchase_at IS NOT NULL) AS engaged_flag,
 COALESCE(o.revenue_inr,0) AS revenue_inr,
 COALESCE(o.order_count,0) AS order_count
FROM sessions s
LEFT JOIN customers c ON s.customer_id=c.customer_id
LEFT JOIN vw_session_stages f ON s.session_id=f.session_id
LEFT JOIN (
 SELECT session_id,SUM(order_value_inr) AS revenue_inr,COUNT(*) AS order_count
 FROM orders WHERE order_status='Completed' GROUP BY session_id
) o ON s.session_id=o.session_id;

-- BUSINESS KPIS: ONE ROW, SESSION CONVERSION AND COMPLETED REVENUE
CREATE OR REPLACE VIEW vw_business_kpis AS
SELECT COUNT(*) AS total_sessions,COUNT(DISTINCT visitor_id) AS total_visitors,
 SUM(order_count) AS total_orders,SUM(revenue_inr) AS total_revenue_inr,
 SUM(purchase_flag)/NULLIF(COUNT(*),0) AS conversion_rate,
 SUM(revenue_inr)/NULLIF(SUM(order_count),0) AS average_order_value_inr,
 AVG(engaged_flag) AS engagement_rate,
 1-SUM(purchase_flag)/NULLIF(SUM(checkout_flag),0) AS checkout_abandonment
FROM vw_session_features;

-- FUNNEL: ORDERED SESSION STAGES AND STAGE-TO-STAGE LOSS
CREATE OR REPLACE VIEW vw_funnel AS
WITH counts AS (
 SELECT COUNT(*) AS sessions,SUM(viewed_flag) AS views,SUM(cart_flag) AS carts,
 SUM(checkout_flag) AS checkouts,SUM(purchase_flag) AS purchases FROM vw_session_features
), stages AS (
 SELECT 1 AS stage_order,'Sessions' AS stage,sessions AS reached,sessions AS previous FROM counts
 UNION ALL SELECT 2,'Product view',views,sessions FROM counts
 UNION ALL SELECT 3,'Add to cart',carts,views FROM counts
 UNION ALL SELECT 4,'Checkout',checkouts,carts FROM counts
 UNION ALL SELECT 5,'Purchase',purchases,checkouts FROM counts
)
SELECT *,reached/NULLIF(previous,0) AS stage_conversion,
 previous-reached AS drop_off,(previous-reached)/NULLIF(previous,0) AS drop_off_rate FROM stages;

-- CHANNEL QUALITY: CONVERSION, VALUE AND ABANDONMENT
CREATE OR REPLACE VIEW vw_channel_performance AS
SELECT channel,COUNT(*) AS sessions,SUM(order_count) AS orders,SUM(revenue_inr) AS revenue_inr,
 SUM(purchase_flag)/COUNT(*) AS conversion_rate,
 SUM(revenue_inr)/COUNT(*) AS revenue_per_session,
 1-SUM(purchase_flag)/NULLIF(SUM(checkout_flag),0) AS checkout_abandonment
FROM vw_session_features GROUP BY channel;

-- DEVICE AND LANDING PAGE PERFORMANCE
CREATE OR REPLACE VIEW vw_device_landing AS
SELECT device_type,landing_page,COUNT(*) AS sessions,AVG(duration_seconds) AS average_seconds,
 AVG(page_views) AS pages_per_session,AVG(engaged_flag) AS engagement_rate,
 SUM(purchase_flag)/COUNT(*) AS conversion_rate,
 1-SUM(purchase_flag)/NULLIF(SUM(checkout_flag),0) AS checkout_abandonment
FROM vw_session_features GROUP BY device_type,landing_page;

-- CAMPAIGNS: FULL LIFETIME COST, NOT A DATE-PRORATED SPEND SERIES
CREATE OR REPLACE VIEW vw_campaign_performance AS
SELECT c.campaign_id,c.campaign_name,c.channel,c.campaign_spend,
 COUNT(f.session_id) AS sessions,COALESCE(SUM(f.purchase_flag),0) AS purchasing_sessions,
 COALESCE(SUM(f.revenue_inr),0) AS revenue_inr,
 SUM(f.purchase_flag)/NULLIF(COUNT(f.session_id),0) AS conversion_rate,
 1-SUM(f.purchase_flag)/NULLIF(SUM(f.checkout_flag),0) AS checkout_abandonment,
 SUM(f.revenue_inr)/NULLIF(c.campaign_spend,0) AS diagnostic_roas
FROM campaigns c LEFT JOIN vw_session_features f ON c.campaign_id=f.campaign_id
GROUP BY c.campaign_id,c.campaign_name,c.channel,c.campaign_spend;

-- CONVERSION OPPORTUNITY SCORE: TRANSPARENT RULE, NOT PREDICTED UPLIFT
-- This unfiltered SQL benchmark is across all attributed campaigns; report slicers make DAX contextual.
CREATE OR REPLACE VIEW vw_campaign_opportunity AS
WITH peers AS (
 SELECT *,SUM(purchasing_sessions) OVER()/NULLIF(SUM(sessions) OVER(),0) AS peer_cvr,
 MAX(sessions) OVER() AS max_traffic FROM vw_campaign_performance
)
SELECT *,CASE WHEN sessions>=100 THEN
 100*(0.45*LEAST(1,GREATEST(0,(peer_cvr-conversion_rate)/NULLIF(peer_cvr,0)))
 +0.30*COALESCE(checkout_abandonment,0)+0.25*sessions/NULLIF(max_traffic,0))
 END AS opportunity_score FROM peers;

-- DAILY VISITS: DEDUPLICATE MULTIPLE SESSIONS ON THE SAME DAY
CREATE OR REPLACE VIEW vw_daily_visits AS
SELECT DISTINCT visitor_id,DATE(session_start) AS visit_date FROM sessions;

-- FIRST-OBSERVED COHORT AND EXACT-DAY RETENTION ELIGIBILITY
CREATE OR REPLACE VIEW vw_visitor_retention AS
WITH first_visits AS (
 SELECT visitor_id,MIN(visit_date) AS first_visit_date FROM vw_daily_visits GROUP BY visitor_id
), boundary AS (SELECT MAX(visit_date) AS last_date FROM vw_daily_visits)
SELECT f.visitor_id,f.first_visit_date,DATE_FORMAT(f.first_visit_date,'%Y-%m') AS cohort_month,
 MAX(DATEDIFF(d.visit_date,f.first_visit_date)=1) AS retained_d1,
 MAX(DATEDIFF(d.visit_date,f.first_visit_date)=7) AS retained_d7,
 MAX(DATEDIFF(d.visit_date,f.first_visit_date)=30) AS retained_d30,
 (f.first_visit_date<=DATE_SUB(b.last_date,INTERVAL 1 DAY)) AS eligible_d1,
 (f.first_visit_date<=DATE_SUB(b.last_date,INTERVAL 7 DAY)) AS eligible_d7,
 (f.first_visit_date<=DATE_SUB(b.last_date,INTERVAL 30 DAY)) AS eligible_d30
FROM first_visits f JOIN vw_daily_visits d ON f.visitor_id=d.visitor_id CROSS JOIN boundary b
GROUP BY f.visitor_id,f.first_visit_date,b.last_date;

-- MATURE EXACT-DAY COHORT RETENTION: SEPARATE DENOMINATORS FOR EACH OFFSET
CREATE OR REPLACE VIEW vw_cohort_retention AS
SELECT cohort_month,COUNT(*) AS visitors,
 SUM(retained_d1*eligible_d1)/NULLIF(SUM(eligible_d1),0) AS d1_retention,
 SUM(retained_d7*eligible_d7)/NULLIF(SUM(eligible_d7),0) AS d7_retention,
 SUM(retained_d30*eligible_d30)/NULLIF(SUM(eligible_d30),0) AS d30_retention
FROM vw_visitor_retention GROUP BY cohort_month;

-- MONTHLY REVENUE: CHRONOLOGICAL YEAR-MONTH ON SESSION START DATE
CREATE OR REPLACE VIEW vw_monthly_performance AS
SELECT DATE_FORMAT(session_date,'%Y-%m') AS year_month,COUNT(*) AS sessions,
 SUM(revenue_inr) AS revenue_inr,SUM(purchase_flag)/COUNT(*) AS conversion_rate
FROM vw_session_features GROUP BY DATE_FORMAT(session_date,'%Y-%m');
