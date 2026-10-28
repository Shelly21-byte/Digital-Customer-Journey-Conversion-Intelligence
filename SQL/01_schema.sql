-- DIGITAL CUSTOMER JOURNEY: FRESH DATABASE SETUP (MYSQL 8+)
-- Run this file first. It does not delete or truncate existing data.
CREATE DATABASE IF NOT EXISTS digital_customer_journey;
USE digital_customer_journey;

-- CUSTOMERS TABLE: REGISTERED CUSTOMER ATTRIBUTES
CREATE TABLE IF NOT EXISTS customers (
 customer_id INT PRIMARY KEY, signup_date DATETIME NOT NULL,
 city VARCHAR(100), state VARCHAR(100), acquisition_channel VARCHAR(50)
);

-- CAMPAIGNS TABLE: ONE LIFETIME BUDGET PER CAMPAIGN
CREATE TABLE IF NOT EXISTS campaigns (
 campaign_id INT PRIMARY KEY, campaign_name VARCHAR(150), channel VARCHAR(50),
 start_date DATE, end_date DATE, campaign_spend DECIMAL(14,2)
);

-- PRODUCTS TABLE: CATALOG ATTRIBUTES, NOT ORDER-LINE AMOUNTS
CREATE TABLE IF NOT EXISTS products (
 product_id INT PRIMARY KEY, product_name VARCHAR(150), category VARCHAR(100), price_inr DECIMAL(14,2)
);

-- SESSIONS TABLE: ONE ROW PER SESSION
CREATE TABLE IF NOT EXISTS sessions (
 session_id INT PRIMARY KEY, customer_id INT NULL, visitor_id VARCHAR(50) NOT NULL,
 session_start DATETIME NOT NULL, session_end DATETIME NOT NULL,
 device_type VARCHAR(50), channel VARCHAR(50), campaign_id INT NULL, landing_page VARCHAR(150),
 FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
 FOREIGN KEY (campaign_id) REFERENCES campaigns(campaign_id),
 INDEX ix_session_visitor_date (visitor_id,session_start)
);

-- ORDERS TABLE: ONE ROW PER ORDER
CREATE TABLE IF NOT EXISTS orders (
 order_id INT PRIMARY KEY, session_id INT NOT NULL, customer_id INT NULL,
 order_timestamp DATETIME NOT NULL, order_value_inr DECIMAL(16,2) NOT NULL, order_status VARCHAR(30),
 FOREIGN KEY (session_id) REFERENCES sessions(session_id),
 FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- EVENTS TABLE: EVENT GRAIN; DO NOT SUM ORDER VALUE AFTER JOINING IT HERE
CREATE TABLE IF NOT EXISTS events (
 event_id INT PRIMARY KEY, session_id INT NOT NULL, event_timestamp DATETIME NOT NULL,
 event_name VARCHAR(50) NOT NULL, product_id INT NULL, order_id INT NULL,
 FOREIGN KEY (session_id) REFERENCES sessions(session_id),
 FOREIGN KEY (product_id) REFERENCES products(product_id),
 FOREIGN KEY (order_id) REFERENCES orders(order_id),
 INDEX ix_event_session_type (session_id,event_name)
);
