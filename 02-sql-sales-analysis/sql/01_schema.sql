-- UrbanCart sales database schema (star schema)
-- Works in SQLite; minor type changes for MySQL / PostgreSQL / SQL Server

CREATE TABLE regions (
    region_id   TEXT PRIMARY KEY,
    region      TEXT NOT NULL,
    city        TEXT NOT NULL,
    country     TEXT NOT NULL
);

CREATE TABLE products (
    product_id    TEXT PRIMARY KEY,
    product_name  TEXT NOT NULL,
    category      TEXT NOT NULL,
    sub_category  TEXT NOT NULL,
    unit_price    DECIMAL(10,2) NOT NULL,
    unit_cost     DECIMAL(10,2) NOT NULL
);

CREATE TABLE customers (
    customer_id    TEXT PRIMARY KEY,
    customer_name  TEXT NOT NULL,
    segment        TEXT NOT NULL,
    region_id      TEXT NOT NULL REFERENCES regions(region_id),
    join_date      DATE NOT NULL
);

CREATE TABLE order_lines (
    order_id        TEXT NOT NULL,
    order_date      DATE NOT NULL,
    ship_date       DATE NOT NULL,
    ship_mode       TEXT NOT NULL,
    customer_id     TEXT NOT NULL REFERENCES customers(customer_id),
    product_id      TEXT NOT NULL REFERENCES products(product_id),
    region_id       TEXT NOT NULL REFERENCES regions(region_id),
    sales_channel   TEXT NOT NULL,
    payment_method  TEXT NOT NULL,
    quantity        INTEGER NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(4,2) NOT NULL,
    sales_amount    DECIMAL(12,2) NOT NULL,
    cost_amount     DECIMAL(12,2) NOT NULL,
    profit          DECIMAL(12,2) NOT NULL,
    returned        TEXT NOT NULL CHECK (returned IN ('Yes','No'))
);

CREATE TABLE sales_targets (
    month_start   DATE NOT NULL,
    region        TEXT NOT NULL,
    sales_target  DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (month_start, region)
);

CREATE INDEX idx_lines_date     ON order_lines(order_date);
CREATE INDEX idx_lines_product  ON order_lines(product_id);
CREATE INDEX idx_lines_customer ON order_lines(customer_id);
