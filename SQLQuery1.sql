USE ExideDB; 
SELECT DB_NAME() AS current_database;

--Verify the import

SELECT 'fact_sales'    AS table_name, COUNT(*) AS row_count FROM dbo.fact_sales
UNION ALL SELECT 'fact_warranty', COUNT(*) FROM dbo.fact_warranty
UNION ALL SELECT 'dim_dealer',    COUNT(*) FROM dbo.dim_dealer
UNION ALL SELECT 'dim_product',   COUNT(*) FROM dbo.dim_product;

--Column data types 

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('OrderID', 'ClaimID', 'DealerID', 'ProductID',
                      'OrderDate', 'ClaimDate', 'JoinDate', 'Revenue', 'ResolutionDays')
ORDER BY TABLE_NAME, COLUMN_NAME;

USE ExideDB;
SELECT TOP 3 DealerID FROM dbo.dim_dealer;
SELECT TOP 3 ProductID FROM dbo.dim_product;


-- Remove the three tables whose ID columns were damaged during import
USE ExideDB;
DROP TABLE IF EXISTS dbo.fact_sales;
DROP TABLE IF EXISTS dbo.dim_dealer;
DROP TABLE IF EXISTS dbo.dim_product;

USE ExideDB;



SELECT TOP 3 DealerID, DealerName, Region FROM dbo.dim_dealer;
SELECT COUNT(*) AS row_count FROM dbo.dim_dealer;

SELECT TOP 3 ProductID, ProductName, PlantID FROM dbo.dim_product;
SELECT COUNT(*) AS row_count FROM dbo.dim_product

SELECT TOP 3 OrderID, DealerID, ProductID, Revenue FROM dbo.fact_sales;
SELECT COUNT(*) AS row_count FROM dbo.fact_sales
----------------------------------------------------------

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('OrderID', 'ClaimID', 'DealerID', 'ProductID', 'PlantID',
                      'OrderDate', 'ClaimDate', 'JoinDate', 'Revenue', 'ResolutionDays')
ORDER BY TABLE_NAME, COLUMN_NAME;

SELECT 'fact_sales'    AS table_name, COUNT(*) AS row_count FROM dbo.fact_sales
UNION ALL SELECT 'fact_warranty', COUNT(*) FROM dbo.fact_warranty
UNION ALL SELECT 'dim_dealer',    COUNT(*) FROM dbo.dim_dealer
UNION ALL SELECT 'dim_product',   COUNT(*) FROM dbo.dim_product

-- Step 4b: Check column data types
-- Purpose: IDs must be text, dates must be DATE, ResolutionDays must allow NULL
USE ExideDB;

SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE COLUMN_NAME IN ('OrderID', 'ClaimID', 'DealerID', 'ProductID', 'PlantID',
                      'OrderDate', 'ClaimDate', 'JoinDate', 'Revenue', 'ResolutionDays')
ORDER BY TABLE_NAME, COLUMN_NAME;



-- Step 4c: Reconcile totals with Python (revenue 567.91 Cr, GP 28.2%, on-time 80.1%)
USE ExideDB;

WITH totals AS (
    SELECT COUNT(*)                     AS orders,
           SUM(Revenue)                 AS revenue,
           SUM(GrossProfit)             AS gross_profit,
           SUM(CAST(IsOnTime AS int))   AS on_time_orders
    FROM dbo.fact_sales
)
SELECT orders,
       CAST(revenue / 10000000.0         AS decimal(10,2)) AS revenue_cr,
       CAST(100.0 * gross_profit / revenue AS decimal(5,1)) AS gross_profit_pct,
       CAST(100.0 * on_time_orders / orders AS decimal(5,1)) AS on_time_pct
FROM totals

-- Check 3: How many warranty claims have no resolution date? (pending claims)
USE ExideDB;

SELECT COUNT(*) AS pending_claims_without_date
FROM dbo.fact_warranty
WHERE ResolutionDays IS NULL;

-- Check 4a: Sales orders whose dealer is not in the dealer list
USE ExideDB;

SELECT COUNT(*) AS orders_without_dealer
FROM dbo.fact_sales
WHERE DealerID NOT IN (SELECT DealerID FROM dbo.dim_dealer);

-- Check 4b: Sales orders whose product is not in the product list
SELECT COUNT(*) AS orders_without_product
FROM dbo.fact_sales
WHERE ProductID NOT IN (SELECT ProductID FROM dbo.dim_product)

-- Step 5a: Give key columns the same data type and make primary key columns NOT NULL
-- Why: a foreign key needs identical data types on both sides
USE ExideDB;
GO

GO




-- Step 5b: Add primary keys (one unique ID per row)
-- Why: it stops duplicate orders, dealers, products and claims from entering the tables
USE ExideDB;
GO
ALTER TABLE dbo.dim_dealer    ADD CONSTRAINT PK_dim_dealer    PRIMARY KEY (DealerID);
ALTER TABLE dbo.dim_product   ADD CONSTRAINT PK_dim_product   PRIMARY KEY (ProductID);
ALTER TABLE dbo.fact_sales    ADD CONSTRAINT PK_fact_sales    PRIMARY KEY (OrderID);
ALTER TABLE dbo.fact_warranty ADD CONSTRAINT PK_fact_warranty PRIMARY KEY (ClaimID);
GO

-- Step 5c: Add foreign keys (these link the four tables together)
-- Why: every order must have a real dealer and product, and every claim a real order
USE ExideDB;
GO
ALTER TABLE dbo.fact_sales    ADD CONSTRAINT FK_sales_dealer     FOREIGN KEY (DealerID)  REFERENCES dbo.dim_dealer(DealerID);
ALTER TABLE dbo.fact_sales    ADD CONSTRAINT FK_sales_product    FOREIGN KEY (ProductID) REFERENCES dbo.dim_product(ProductID);
ALTER TABLE dbo.fact_warranty ADD CONSTRAINT FK_warranty_sales   FOREIGN KEY (OrderID)   REFERENCES dbo.fact_sales(OrderID);
ALTER TABLE dbo.fact_warranty ADD CONSTRAINT FK_warranty_product FOREIGN KEY (ProductID) REFERENCES dbo.dim_product(ProductID);
ALTER TABLE dbo.fact_warranty ADD CONSTRAINT FK_warranty_dealer  FOREIGN KEY (DealerID)  REFERENCES dbo.dim_dealer(DealerID);


-- Step 5d: Confirm that the keys exist
SELECT type_desc, COUNT(*) AS constraint_count
FROM sys.objects
WHERE type IN ('PK', 'F')
GROUP BY type_desc;

-------------------------------------------------------------------------------------------------

--  Revenue by region
-- Business question (Sales Head): Which region brings the most revenue?
-- Concepts: JOIN, GROUP BY, SUM, COUNT, ORDER BY

SELECT d.Region,
       COUNT(*)                          AS orders,
       ROUND(SUM(s.Revenue) / 10000000, 2) AS revenue_cr
FROM dbo.fact_sales AS s
JOIN dbo.dim_dealer AS d
     ON s.DealerID = d.DealerID
GROUP BY d.Region
ORDER BY revenue_cr DESC;

/*South	21566	217.39
North	15765	164.37
West	19105	145.53
East	6544	40.62*/

--  Revenue by region and year
-- Business question (Sales Head): Is each region growing year after year?
-- Concepts: JOIN, GROUP BY on two columns, YEAR(), SUM, ORDER BY

SELECT d.Region,
       YEAR(s.OrderDate)                   AS order_year,
       ROUND(SUM(s.Revenue) / 10000000, 2) AS revenue_cr
FROM dbo.fact_sales AS s
JOIN dbo.dim_dealer AS d
     ON s.DealerID = d.DealerID
GROUP BY d.Region, YEAR(s.OrderDate)
ORDER BY d.Region, order_year;

--  Top 5 dealers by revenue
-- Business question (Sales Head): Which dealers bring the most revenue?
-- Concepts: JOIN, GROUP BY, SUM, ORDER BY DESC, TOP

SELECT TOP 5
       d.DealerName,
       d.Region,
       d.DealerType,
       COUNT(*)                            AS orders,
       ROUND(SUM(s.Revenue) / 10000000, 2) AS revenue_cr
FROM dbo.fact_sales AS s
JOIN dbo.dim_dealer AS d
     ON s.DealerID = d.DealerID
GROUP BY d.DealerName, d.Region, d.DealerType
ORDER BY SUM(s.Revenue) DESC;


--  On-time delivery % by region
-- Business question (Supply Chain Head): Which region delivers late the most?
-- Concepts: JOIN, GROUP BY, CASE, SUM, ORDER BY
-- Rule: an order is late when DeliveryDays is greater than PromisedDays (IsOnTime = 0)

SELECT d.Region,
       COUNT(*)                                          AS orders,
       SUM(CASE WHEN s.IsOnTime = 0 THEN 1 ELSE 0 END)   AS late_orders,
       ROUND(100.0 * SUM(CASE WHEN s.IsOnTime = 1 THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_pct
FROM dbo.fact_sales AS s
JOIN dbo.dim_dealer AS d
     ON s.DealerID = d.DealerID
GROUP BY d.Region
ORDER BY on_time_pct;



--  Warranty claim rate by product category
-- Business question (Quality Head): Which product category fails the most?
-- Concepts: CTE (two steps), JOIN, GROUP BY, SUM, percentage
-- Claim rate = units claimed / units sold

WITH sold AS (                                   -- Step 1: units sold per category
    SELECT p.Category, SUM(s.Quantity) AS units_sold
    FROM dbo.fact_sales AS s
    JOIN dbo.dim_product AS p ON s.ProductID = p.ProductID
    GROUP BY p.Category
),
claimed AS (                                     -- Step 2: units claimed per category
    SELECT p.Category, SUM(w.QtyClaimed) AS units_claimed
    FROM dbo.fact_warranty AS w
    JOIN dbo.dim_product AS p ON w.ProductID = p.ProductID
    GROUP BY p.Category
)
SELECT sold.Category,                            -- Step 3: combine both and calculate the rate
       sold.units_sold,
       claimed.units_claimed,
       ROUND(100.0 * claimed.units_claimed / sold.units_sold, 2) AS claim_rate_pct
FROM sold
JOIN claimed ON sold.Category = claimed.Category
ORDER BY claim_rate_pct DESC;



-- Warranty claims by reason
-- Business question (Quality Head): Why do customers claim, and which reason costs the most?
-- Concepts: GROUP BY, COUNT, SUM, ORDER BY
-- Approved amount is 0 for rejected and pending claims


SELECT Reason,
       COUNT(*)                              AS claims,
       ROUND(SUM(ApprovedAmount) / 100000, 1) AS approved_cost_lakh
FROM dbo.fact_warranty
GROUP BY Reason
ORDER BY claims DESC;

--  Find batches with an unusually high warranty claim rate
-- Business question (Quality Head): Which production batches fail the most?
-- Concepts: CTE (two steps), HAVING, LEFT JOIN, ISNULL
-- Rules: only batches with 300+ units sold (small batches are unreliable);
--        flag batches whose claim rate is above 8%


WITH batch_sold AS (                                    -- Step 1: units sold per batch and product
    SELECT BatchID, ProductID, SUM(Quantity) AS units_sold
    FROM dbo.fact_sales
    GROUP BY BatchID, ProductID
    HAVING SUM(Quantity) >= 300
),
batch_claims AS (                                       -- Step 2: units claimed per batch and product
    SELECT BatchID, ProductID, SUM(QtyClaimed) AS units_claimed
    FROM dbo.fact_warranty
    GROUP BY BatchID, ProductID
)
SELECT s.BatchID,                                       -- Step 3: combine and calculate the rate
       p.ProductName,
       s.units_sold,
       ISNULL(c.units_claimed, 0) AS units_claimed,
       ROUND(100.0 * ISNULL(c.units_claimed, 0) / s.units_sold, 1) AS claim_rate_pct
FROM batch_sold AS s
LEFT JOIN batch_claims AS c
       ON s.BatchID = c.BatchID AND s.ProductID = c.ProductID
JOIN dbo.dim_product AS p
       ON s.ProductID = p.ProductID
WHERE 100.0 * ISNULL(c.units_claimed, 0) / s.units_sold > 8
ORDER BY claim_rate_pct DESC;


--  Top 3 dealers in each region
-- Business question (Sales Head): Who are the best dealers in each region?
-- Concepts: CTE, JOIN, GROUP BY, RANK() with PARTITION BY
-- Why CTE: a RANK() result cannot be filtered in the same SELECT, so we rank first and filter after

WITH dealer_revenue AS (                                    -- Step 1: revenue per dealer
    SELECT d.Region, d.DealerName, d.DealerType,
           SUM(s.Revenue) AS revenue
    FROM dbo.fact_sales AS s
    JOIN dbo.dim_dealer AS d ON s.DealerID = d.DealerID
    GROUP BY d.Region, d.DealerName, d.DealerType
),
ranked AS (                                                 -- Step 2: rank dealers inside each region
    SELECT Region, DealerName, DealerType, revenue,
           RANK() OVER (PARTITION BY Region ORDER BY revenue DESC) AS rnk
    FROM dealer_revenue
)
SELECT Region, rnk, DealerName, DealerType,                 -- Step 3: keep only the top 3
       ROUND(revenue / 10000000, 2) AS revenue_cr
FROM ranked
WHERE rnk <= 3
ORDER BY Region, rnk;


--  Dealers with revenue above the average dealer
-- Business question (Sales Head): Which dealers bring more revenue than the average dealer?
-- Concepts: CTE, JOIN, GROUP BY, AVG, subquery in WHERE
-- Why CTE: we need each dealer's revenue first, then compare it with the average of those revenues

WITH dealer_revenue AS (                                  -- Step 1: revenue per dealer
    SELECT d.DealerName, d.Region, d.DealerType,
           SUM(s.Revenue) AS revenue
    FROM dbo.fact_sales AS s
    JOIN dbo.dim_dealer AS d ON s.DealerID = d.DealerID
    GROUP BY d.DealerName, d.Region, d.DealerType
)
SELECT DealerName, Region, DealerType,                    -- Step 2: keep dealers above the average
       ROUND(revenue / 10000000, 2) AS revenue_cr
FROM dealer_revenue
WHERE revenue > (SELECT AVG(revenue) FROM dealer_revenue)
ORDER BY revenue DESC;

SELECT 1 AS test;

-----------------------------------------------------------------------------------
-- View 1: Sales report for Power BI
-- Purpose: one ready table with order, dealer and product details


CREATE VIEW dbo.vw_sales_report AS
SELECT s.OrderID,
       s.OrderDate,
       YEAR(s.OrderDate)  AS OrderYear,
       MONTH(s.OrderDate) AS OrderMonth,
       d.DealerName,
       d.DealerType,
       d.Region,
       d.State,
       p.ProductName,
       p.Category,
       s.Quantity,
       s.Revenue,
       s.GrossProfit,
       s.PromisedDays,
       s.DeliveryDays,
       s.IsOnTime,
       s.BatchID
FROM dbo.fact_sales AS s
JOIN dbo.dim_dealer  AS d ON s.DealerID  = d.DealerID
JOIN dbo.dim_product AS p ON s.ProductID = p.ProductID;
GO



-- View 2: Warranty report for Power BI
-- Purpose: one ready table with claim, product and dealer details


CREATE VIEW dbo.vw_warranty_report AS
SELECT w.ClaimID,
       w.ClaimDate,
       YEAR(w.ClaimDate) AS ClaimYear,
       w.OrderID,
       w.BatchID,
       p.ProductName,
       p.Category,
       d.Region,
       d.DealerName,
       w.Reason,
       w.ClaimStatus,
       w.QtyClaimed,
       w.ClaimAmount,
       w.ApprovedAmount,
       w.ResolutionDays
FROM dbo.fact_warranty AS w
JOIN dbo.dim_product AS p ON w.ProductID = p.ProductID
JOIN dbo.dim_dealer  AS d ON w.DealerID  = d.DealerID;
GO



-- View check: the views must give the same totals as the tables


SELECT COUNT(*)                          AS orders,
       ROUND(SUM(Revenue) / 10000000, 2) AS revenue_cr
FROM dbo.vw_sales_report;

SELECT COUNT(*)                          AS claims,
       SUM(QtyClaimed)                   AS units_claimed
FROM dbo.vw_warranty_report;

--SELECT * FROM dbo.vw_warranty_report;
--SELECT * FROM dbo.vw_sales_report;