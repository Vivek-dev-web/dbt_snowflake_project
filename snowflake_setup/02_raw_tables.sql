-- =============================================================================
-- STEP 2 — Create raw tables in the RAW schema
-- Run after 01_setup.sql
-- =============================================================================

USE DATABASE DBT_PRACTICE;
USE SCHEMA   RAW;
USE WAREHOUSE DBT_WH;

-- ---------------------------------------------------------------------------
-- DEPARTMENTS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.departments (
    department_id   INTEGER       NOT NULL PRIMARY KEY,
    department_name VARCHAR(100)  NOT NULL,
    location        VARCHAR(100),
    manager_id      INTEGER,
    budget          NUMBER(12, 2)
);

-- ---------------------------------------------------------------------------
-- EMPLOYEES
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.employees (
    employee_id       INTEGER       NOT NULL PRIMARY KEY,
    first_name        VARCHAR(100)  NOT NULL,
    last_name         VARCHAR(100)  NOT NULL,
    email             VARCHAR(200)  NOT NULL UNIQUE,
    phone             VARCHAR(30),
    department_id     INTEGER       NOT NULL REFERENCES raw.departments(department_id),
    job_title         VARCHAR(150),
    salary            NUMBER(12, 2),
    hire_date         DATE,
    manager_id        INTEGER,
    employment_status VARCHAR(20)   DEFAULT 'active',
    city              VARCHAR(100),
    state             VARCHAR(10)
);

-- ---------------------------------------------------------------------------
-- CUSTOMERS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.customers (
    customer_id       INTEGER       NOT NULL PRIMARY KEY,
    first_name        VARCHAR(100)  NOT NULL,
    last_name         VARCHAR(100)  NOT NULL,
    email             VARCHAR(200)  NOT NULL UNIQUE,
    phone             VARCHAR(30),
    city              VARCHAR(100),
    state             VARCHAR(10),
    country           VARCHAR(50)   DEFAULT 'USA',
    registration_date DATE,
    date_of_birth     DATE,
    customer_segment  VARCHAR(20),   -- standard | gold | premium
    credit_limit      NUMBER(10, 2),
    is_active         BOOLEAN        DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- PRODUCTS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.products (
    product_id    INTEGER       NOT NULL PRIMARY KEY,
    product_name  VARCHAR(200)  NOT NULL,
    category_id   INTEGER,
    category_name VARCHAR(100),
    unit_price    NUMBER(10, 2),
    units_in_stock INTEGER       DEFAULT 0,
    supplier      VARCHAR(200),
    is_active     BOOLEAN        DEFAULT TRUE
);

-- ---------------------------------------------------------------------------
-- ORDERS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.orders (
    order_id               INTEGER       NOT NULL PRIMARY KEY,
    customer_id            INTEGER       NOT NULL REFERENCES raw.customers(customer_id),
    employee_id            INTEGER,
    order_date             DATE          NOT NULL,
    status                 VARCHAR(20)   NOT NULL,  -- pending | processing | delivered | cancelled | refunded
    total_amount           NUMBER(12, 2),
    shipping_address_city  VARCHAR(100),
    shipping_address_state VARCHAR(10),
    payment_method         VARCHAR(30),
    notes                  VARCHAR(500)
);

-- ---------------------------------------------------------------------------
-- ORDER ITEMS
-- ---------------------------------------------------------------------------
CREATE OR REPLACE TABLE raw.order_items (
    order_item_id INTEGER       NOT NULL PRIMARY KEY,
    order_id      INTEGER       NOT NULL REFERENCES raw.orders(order_id),
    product_id    INTEGER       NOT NULL REFERENCES raw.products(product_id),
    quantity      INTEGER       NOT NULL DEFAULT 1,
    unit_price    NUMBER(10, 2) NOT NULL,
    discount_pct  NUMBER(5, 2)  DEFAULT 0
);
