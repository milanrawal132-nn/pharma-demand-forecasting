DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_category;

CREATE TABLE dim_category (
    category_code TEXT PRIMARY KEY,
    category_name TEXT NOT NULL
);

INSERT INTO dim_category (category_code, category_name) VALUES
    ('M01AB', 'Anti-inflammatory (acetic acid derivatives)'),
    ('M01AE', 'Anti-inflammatory (propionic acid derivatives)'),
    ('N02BA', 'Analgesics - salicylic acid derivatives'),
    ('N02BE', 'Analgesics - pyrazolones and anilides'),
    ('N05B',  'Anxiolytics'),
    ('N05C',  'Hypnotics and sedatives'),
    ('R03',   'Anti-asthmatic and COPD drugs'),
    ('R06',   'Antihistamines');

CREATE TABLE fact_sales (
    sale_date TEXT NOT NULL,
    category_code TEXT NOT NULL,
    granularity TEXT NOT NULL,
    units_sold REAL NOT NULL,
    FOREIGN KEY (category_code) REFERENCES dim_category(category_code)
);

CREATE INDEX idx_fact_sales_date ON fact_sales(sale_date);
CREATE INDEX idx_fact_sales_category ON fact_sales(category_code);
CREATE INDEX idx_fact_sales_granularity ON fact_sales(granularity);
