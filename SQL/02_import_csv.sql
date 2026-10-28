-- CSV IMPORT: FRESH EMPTY TABLES ONLY
-- Run 01_schema.sql first. Change paths if needed. Do not rerun on populated tables.
-- LOCAL INFILE must already be enabled by your own MySQL/Workbench configuration.
-- This script does not change server permissions or security settings.
-- CSV NULL keys and Windows carriage returns are handled explicitly.
USE digital_customer_journey;

-- IMPORT CUSTOMERS: customers.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/customers.csv' INTO TABLE customers
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(customer_id, signup_date, city, state, @last)
SET acquisition_channel = TRIM(REPLACE(@last, CHAR(13), ''));

-- IMPORT CAMPAIGNS: campaigns.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/campaigns.csv' INTO TABLE campaigns
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(campaign_id, campaign_name, channel, start_date, end_date, @last)
SET campaign_spend = CAST(TRIM(REPLACE(@last,CHAR(13),'')) AS DECIMAL(14,2));

-- IMPORT PRODUCTS: products.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/products.csv' INTO TABLE products
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(product_id, product_name, category, @last)
SET price_inr = CAST(TRIM(REPLACE(@last,CHAR(13),'')) AS DECIMAL(14,2));

-- IMPORT SESSIONS: sessions.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/sessions.csv' INTO TABLE sessions
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(session_id, @customer, visitor_id, session_start, session_end, device_type, channel, @campaign, @last)
SET customer_id = NULLIF(NULLIF(TRIM(@customer),''),'NULL'), campaign_id = NULLIF(NULLIF(TRIM(@campaign),''),'NULL'), landing_page = TRIM(REPLACE(@last,CHAR(13),''));

-- IMPORT ORDERS: orders.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/orders.csv' INTO TABLE orders
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(order_id, session_id, @customer, order_timestamp, order_value_inr, @last)
SET customer_id = NULLIF(NULLIF(TRIM(@customer),''),'NULL'), order_status = TRIM(REPLACE(@last,CHAR(13),''));

-- IMPORT EVENTS: events.csv
LOAD DATA LOCAL INFILE 'C:/DigitalCustomer/DATA/events.csv' INTO TABLE events
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n' IGNORE 1 LINES
(event_id, session_id, event_timestamp, event_name, @product, @last)
SET product_id = NULLIF(NULLIF(TRIM(@product),''),'NULL'), order_id = NULLIF(NULLIF(TRIM(REPLACE(@last,CHAR(13),'')),''),'NULL');
