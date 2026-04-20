
/*
===========================================================
BANKING TEST DATASET - ANALYTICS LAYER / RECRUITMENT PACK
Target: SQL Server / SSMS
How to use:
1) Run banking_test_dataset.sql first
2) Run this script second

What this script gives you:
- data cleaning views
- analytical views
- GROUP BY / HAVING examples
- CTE examples
- subquery examples
- temp table example
- window functions:
  ROW_NUMBER(), RANK(), LAG(), LEAD()
- KPI queries useful for a bank/data analyst interview
===========================================================
*/

SET NOCOUNT ON;
GO

/* =========================================================
   1. DROP OLD OBJECTS
   ========================================================= */
DROP VIEW IF EXISTS dbo.vw_clean_customers;
DROP VIEW IF EXISTS dbo.vw_clean_accounts;
DROP VIEW IF EXISTS dbo.vw_clean_transactions;
DROP VIEW IF EXISTS dbo.vw_clean_loans;
DROP VIEW IF EXISTS dbo.vw_customer_360;
DROP VIEW IF EXISTS dbo.vw_monthly_customer_transactions;
DROP VIEW IF EXISTS dbo.vw_loan_risk_summary;
GO

/* =========================================================
   2. CLEANING VIEWS
   ========================================================= */

-- Customers: trim text, standardize city casing, calculate age/tenure buckets
CREATE VIEW dbo.vw_clean_customers
AS
SELECT
    c.Customer_ID,
    LTRIM(RTRIM(c.First_Name)) AS First_Name,
    LTRIM(RTRIM(c.Last_Name)) AS Last_Name,
    UPPER(c.Gender) AS Gender,
    c.Birth_Date,
    CASE
        WHEN c.City IS NULL OR LTRIM(RTRIM(c.City)) = '' THEN 'Unknown'
        ELSE UPPER(LEFT(LTRIM(RTRIM(c.City)),1)) + LOWER(SUBSTRING(LTRIM(RTRIM(c.City)),2,LEN(LTRIM(RTRIM(c.City)))))
    END AS City_Clean,
    LTRIM(RTRIM(c.Customer_Segment)) AS Customer_Segment,
    c.Join_Date,
    LTRIM(RTRIM(c.Status)) AS Customer_Status,
    DATEDIFF(YEAR, c.Birth_Date, GETDATE()) AS Age,
    DATEDIFF(MONTH, c.Join_Date, GETDATE()) AS Tenure_Months,
    CASE
        WHEN DATEDIFF(YEAR, c.Birth_Date, GETDATE()) < 25 THEN '18-24'
        WHEN DATEDIFF(YEAR, c.Birth_Date, GETDATE()) < 35 THEN '25-34'
        WHEN DATEDIFF(YEAR, c.Birth_Date, GETDATE()) < 45 THEN '35-44'
        WHEN DATEDIFF(YEAR, c.Birth_Date, GETDATE()) < 55 THEN '45-54'
        ELSE '55+'
    END AS Age_Group
FROM dbo.dim_customers c;
GO

-- Accounts: standardize status, derive account age
CREATE VIEW dbo.vw_clean_accounts
AS
SELECT
    a.Account_ID,
    a.Customer_ID,
    LTRIM(RTRIM(a.Account_Type)) AS Account_Type,
    a.Open_Date,
    a.Close_Date,
    UPPER(a.Currency) AS Currency_Code,
    LTRIM(RTRIM(a.Account_Status)) AS Account_Status,
    DATEDIFF(MONTH, a.Open_Date, ISNULL(a.Close_Date, GETDATE())) AS Account_Age_Months
FROM dbo.dim_accounts a;
GO

-- Transactions: standardize text, create signed/absolute amounts, month keys
CREATE VIEW dbo.vw_clean_transactions
AS
SELECT
    t.Transaction_ID,
    t.Account_ID,
    CAST(t.Transaction_Date AS DATE) AS Transaction_Date,
    DATEFROMPARTS(YEAR(t.Transaction_Date), MONTH(t.Transaction_Date), 1) AS Transaction_Month,
    YEAR(t.Transaction_Date) AS Transaction_Year,
    MONTH(t.Transaction_Date) AS Transaction_Month_Number,
    LTRIM(RTRIM(t.Transaction_Type)) AS Transaction_Type,
    LTRIM(RTRIM(t.Direction)) AS Direction,
    LTRIM(RTRIM(t.Merchant_Category)) AS Merchant_Category,
    LTRIM(RTRIM(t.Channel)) AS Channel,
    CASE
        WHEN t.City IS NULL OR LTRIM(RTRIM(t.City)) = '' THEN 'Unknown'
        ELSE UPPER(LEFT(LTRIM(RTRIM(t.City)),1)) + LOWER(SUBSTRING(LTRIM(RTRIM(t.City)),2,LEN(LTRIM(RTRIM(t.City)))))
    END AS City_Clean,
    t.Is_Fraud_Flag,
    CAST(t.Amount AS DECIMAL(12,2)) AS Amount,
    ABS(CAST(t.Amount AS DECIMAL(12,2))) AS Amount_Abs,
    CASE
        WHEN UPPER(LTRIM(RTRIM(t.Direction))) = 'IN' THEN CAST(t.Amount AS DECIMAL(12,2))
        WHEN UPPER(LTRIM(RTRIM(t.Direction))) = 'OUT' THEN CAST(t.Amount AS DECIMAL(12,2)) * -1
        ELSE CAST(t.Amount AS DECIMAL(12,2))
    END AS Signed_Amount
FROM dbo.fact_transactions t;
GO

-- Loans: standardize loan status and derive loan age
CREATE VIEW dbo.vw_clean_loans
AS
SELECT
    l.Loan_ID,
    l.Customer_ID,
    LTRIM(RTRIM(l.Loan_Type)) AS Loan_Type,
    CAST(l.Loan_Amount AS DECIMAL(14,2)) AS Loan_Amount,
    CAST(l.Interest_Rate AS DECIMAL(5,2)) AS Interest_Rate,
    l.Start_Date,
    l.End_Date,
    LTRIM(RTRIM(l.Loan_Status)) AS Loan_Status,
    CAST(l.Monthly_Installment AS DECIMAL(12,2)) AS Monthly_Installment,
    DATEDIFF(MONTH, l.Start_Date, ISNULL(l.End_Date, GETDATE())) AS Loan_Age_Months
FROM dbo.fact_loans l;
GO

/* =========================================================
   3. ANALYTICAL VIEWS
   ========================================================= */

-- Customer 360 view: one customer row with core metrics
CREATE VIEW dbo.vw_customer_360
AS
WITH txn AS
(
    SELECT
        a.Customer_ID,
        COUNT(*) AS Transactions_Count,
        SUM(CASE WHEN t.Direction = 'In' THEN t.Amount_Abs ELSE 0 END) AS Total_Inflows,
        SUM(CASE WHEN t.Direction = 'Out' THEN t.Amount_Abs ELSE 0 END) AS Total_Outflows,
        AVG(t.Amount_Abs) AS Avg_Transaction_Amount,
        MAX(t.Transaction_Date) AS Last_Transaction_Date
    FROM dbo.vw_clean_transactions t
    INNER JOIN dbo.vw_clean_accounts a
        ON t.Account_ID = a.Account_ID
    GROUP BY a.Customer_ID
),
loan_summary AS
(
    SELECT
        Customer_ID,
        COUNT(*) AS Loans_Count,
        SUM(Loan_Amount) AS Total_Loan_Amount,
        AVG(Interest_Rate) AS Avg_Interest_Rate
    FROM dbo.vw_clean_loans
    GROUP BY Customer_ID
)
SELECT
    c.Customer_ID,
    c.First_Name,
    c.Last_Name,
    c.Gender,
    c.City_Clean,
    c.Customer_Segment,
    c.Customer_Status,
    c.Age,
    c.Age_Group,
    c.Tenure_Months,
    ISNULL(txn.Transactions_Count, 0) AS Transactions_Count,
    ISNULL(txn.Total_Inflows, 0) AS Total_Inflows,
    ISNULL(txn.Total_Outflows, 0) AS Total_Outflows,
    ISNULL(txn.Avg_Transaction_Amount, 0) AS Avg_Transaction_Amount,
    txn.Last_Transaction_Date,
    DATEDIFF(DAY, txn.Last_Transaction_Date, GETDATE()) AS Days_Since_Last_Transaction,
    ISNULL(ls.Loans_Count, 0) AS Loans_Count,
    ISNULL(ls.Total_Loan_Amount, 0) AS Total_Loan_Amount,
    ISNULL(ls.Avg_Interest_Rate, 0) AS Avg_Interest_Rate,
    CASE
        WHEN c.Customer_Status = 'Inactive'
             AND ISNULL(txn.Transactions_Count, 0) <= 3 THEN 'High'
        WHEN DATEDIFF(DAY, txn.Last_Transaction_Date, GETDATE()) > 90
             OR ISNULL(txn.Total_Outflows,0) > ISNULL(txn.Total_Inflows,0) THEN 'Medium'
        ELSE 'Low'
    END AS Churn_Risk
FROM dbo.vw_clean_customers c
LEFT JOIN txn
    ON c.Customer_ID = txn.Customer_ID
LEFT JOIN loan_summary ls
    ON c.Customer_ID = ls.Customer_ID;
GO

-- Monthly customer transactions view
CREATE VIEW dbo.vw_monthly_customer_transactions
AS
SELECT
    a.Customer_ID,
    t.Transaction_Month,
    COUNT(*) AS Transactions_Count,
    SUM(CASE WHEN t.Direction = 'In' THEN t.Amount_Abs ELSE 0 END) AS Monthly_Inflows,
    SUM(CASE WHEN t.Direction = 'Out' THEN t.Amount_Abs ELSE 0 END) AS Monthly_Outflows
FROM dbo.vw_clean_transactions t
INNER JOIN dbo.vw_clean_accounts a
    ON t.Account_ID = a.Account_ID
GROUP BY
    a.Customer_ID,
    t.Transaction_Month;
GO

-- Loan risk summary
CREATE VIEW dbo.vw_loan_risk_summary
AS
SELECT
    Customer_ID,
    Loan_Type,
    COUNT(*) AS Loans_Count,
    SUM(Loan_Amount) AS Total_Loan_Amount,
    AVG(Interest_Rate) AS Avg_Interest_Rate,
    CASE
        WHEN AVG(Interest_Rate) >= 10 THEN 'High'
        WHEN AVG(Interest_Rate) >= 7 THEN 'Medium'
        ELSE 'Low'
    END AS Loan_Risk_Band
FROM dbo.vw_clean_loans
GROUP BY
    Customer_ID,
    Loan_Type;
GO

/* =========================================================
   4. DATA QUALITY CHECKS
   ========================================================= */

-- 4.1 Future join dates
SELECT *
FROM dbo.vw_clean_customers
WHERE Join_Date > GETDATE();

-- 4.2 Future transaction dates
SELECT *
FROM dbo.vw_clean_transactions
WHERE Transaction_Date > GETDATE();

-- 4.3 Customers without accounts
SELECT c.*
FROM dbo.vw_clean_customers c
LEFT JOIN dbo.vw_clean_accounts a
    ON c.Customer_ID = a.Customer_ID
WHERE a.Account_ID IS NULL;

-- 4.4 Accounts without transactions
SELECT a.*
FROM dbo.vw_clean_accounts a
LEFT JOIN dbo.vw_clean_transactions t
    ON a.Account_ID = t.Account_ID
WHERE t.Transaction_ID IS NULL;

-- 4.5 Possible duplicates by business key (same name + birth date)
SELECT
    First_Name,
    Last_Name,
    Birth_Date,
    COUNT(*) AS duplicate_count
FROM dbo.vw_clean_customers
GROUP BY
    First_Name,
    Last_Name,
    Birth_Date
HAVING COUNT(*) > 1;

/* =========================================================
   5. BASIC KPI / GROUP BY QUERIES
   ========================================================= */

-- Total customers by segment
SELECT
    Customer_Segment,
    COUNT(*) AS Customers_Count
FROM dbo.vw_clean_customers
GROUP BY Customer_Segment
ORDER BY Customers_Count DESC;

-- Customers by city
SELECT
    City_Clean,
    COUNT(*) AS Customers_Count
FROM dbo.vw_clean_customers
GROUP BY City_Clean
ORDER BY Customers_Count DESC;

-- Average transaction amount by channel
SELECT
    Channel,
    AVG(Amount_Abs) AS Avg_Transaction_Amount
FROM dbo.vw_clean_transactions
GROUP BY Channel
ORDER BY Avg_Transaction_Amount DESC;

-- Total inflows / outflows by month
SELECT
    Transaction_Month,
    SUM(CASE WHEN Direction = 'In' THEN Amount_Abs ELSE 0 END) AS Total_Inflows,
    SUM(CASE WHEN Direction = 'Out' THEN Amount_Abs ELSE 0 END) AS Total_Outflows
FROM dbo.vw_clean_transactions
GROUP BY Transaction_Month
ORDER BY Transaction_Month;

-- Fraud rate by channel
SELECT
    Channel,
    COUNT(*) AS Transactions_Count,
    SUM(CASE WHEN Is_Fraud_Flag = 1 THEN 1 ELSE 0 END) AS Fraud_Count,
    CAST(100.0 * SUM(CASE WHEN Is_Fraud_Flag = 1 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(10,2)) AS Fraud_Rate_Pct
FROM dbo.vw_clean_transactions
GROUP BY Channel
ORDER BY Fraud_Rate_Pct DESC;

/* =========================================================
   6. SUBQUERY EXAMPLES
   ========================================================= */

-- Customers with above-average total outflows
SELECT *
FROM dbo.vw_customer_360
WHERE Total_Outflows >
(
    SELECT AVG(Total_Outflows)
    FROM dbo.vw_customer_360
);

-- Accounts that have more transactions than the average account
SELECT
    a.Account_ID,
    COUNT(t.Transaction_ID) AS Txn_Count
FROM dbo.vw_clean_accounts a
LEFT JOIN dbo.vw_clean_transactions t
    ON a.Account_ID = t.Account_ID
GROUP BY a.Account_ID
HAVING COUNT(t.Transaction_ID) >
(
    SELECT AVG(Txn_Per_Account * 1.0)
    FROM
    (
        SELECT COUNT(*) AS Txn_Per_Account
        FROM dbo.vw_clean_transactions
        GROUP BY Account_ID
    ) s
);

/* =========================================================
   7. CTE EXAMPLES
   ========================================================= */

-- Top cities by customers and total loan amount
WITH city_base AS
(
    SELECT
        c.City_Clean,
        COUNT(DISTINCT c.Customer_ID) AS Customers_Count,
        SUM(ISNULL(l.Loan_Amount,0)) AS Total_Loan_Amount
    FROM dbo.vw_clean_customers c
    LEFT JOIN dbo.vw_clean_loans l
        ON c.Customer_ID = l.Customer_ID
    GROUP BY c.City_Clean
)
SELECT *
FROM city_base
ORDER BY Total_Loan_Amount DESC, Customers_Count DESC;

-- Monthly inflow/outflow net result
WITH monthly_cashflow AS
(
    SELECT
        Transaction_Month,
        SUM(CASE WHEN Direction = 'In' THEN Amount_Abs ELSE 0 END) AS Inflows,
        SUM(CASE WHEN Direction = 'Out' THEN Amount_Abs ELSE 0 END) AS Outflows
    FROM dbo.vw_clean_transactions
    GROUP BY Transaction_Month
)
SELECT
    Transaction_Month,
    Inflows,
    Outflows,
    Inflows - Outflows AS Net_Flow
FROM monthly_cashflow
ORDER BY Transaction_Month;

/* =========================================================
   8. TEMP TABLE EXAMPLE
   ========================================================= */

IF OBJECT_ID('tempdb..#high_value_customers') IS NOT NULL
    DROP TABLE #high_value_customers;

SELECT
    Customer_ID,
    First_Name,
    Last_Name,
    Total_Inflows,
    Total_Outflows,
    Churn_Risk
INTO #high_value_customers
FROM dbo.vw_customer_360
WHERE Total_Inflows > 5000;

SELECT *
FROM #high_value_customers
ORDER BY Total_Inflows DESC;

/* =========================================================
   9. WINDOW FUNCTIONS
   ========================================================= */

-- 9.1 ROW_NUMBER(): latest transaction per account
SELECT *
FROM
(
    SELECT
        t.*,
        ROW_NUMBER() OVER
        (
            PARTITION BY t.Account_ID
            ORDER BY t.Transaction_Date DESC, t.Transaction_ID DESC
        ) AS rn
    FROM dbo.vw_clean_transactions t
) x
WHERE rn = 1
ORDER BY Account_ID;

-- 9.2 RANK(): top customers by total inflows
SELECT
    Customer_ID,
    First_Name,
    Last_Name,
    Total_Inflows,
    RANK() OVER (ORDER BY Total_Inflows DESC) AS inflow_rank
FROM dbo.vw_customer_360
ORDER BY inflow_rank, Customer_ID;

-- 9.3 LAG(): month-over-month inflow change
WITH monthly_inflows AS
(
    SELECT
        Transaction_Month,
        SUM(CASE WHEN Direction = 'In' THEN Amount_Abs ELSE 0 END) AS Total_Inflows
    FROM dbo.vw_clean_transactions
    GROUP BY Transaction_Month
)
SELECT
    Transaction_Month,
    Total_Inflows,
    LAG(Total_Inflows) OVER (ORDER BY Transaction_Month) AS Prev_Month_Inflows,
    Total_Inflows - LAG(Total_Inflows) OVER (ORDER BY Transaction_Month) AS MoM_Change
FROM monthly_inflows
ORDER BY Transaction_Month;

-- 9.4 LEAD(): next transaction date per account
SELECT
    Account_ID,
    Transaction_ID,
    Transaction_Date,
    LEAD(Transaction_Date) OVER
    (
        PARTITION BY Account_ID
        ORDER BY Transaction_Date, Transaction_ID
    ) AS Next_Transaction_Date
FROM dbo.vw_clean_transactions
ORDER BY Account_ID, Transaction_Date;

-- 9.5 Running total by account
SELECT
    Account_ID,
    Transaction_Date,
    Transaction_ID,
    Signed_Amount,
    SUM(Signed_Amount) OVER
    (
        PARTITION BY Account_ID
        ORDER BY Transaction_Date, Transaction_ID
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Running_Balance_Change
FROM dbo.vw_clean_transactions
ORDER BY Account_ID, Transaction_Date, Transaction_ID;

/* =========================================================
   10. INTERVIEW-STYLE QUERIES
   ========================================================= */

-- 10.1 Which customers are most at risk of churn?
SELECT
    Customer_ID,
    First_Name,
    Last_Name,
    Customer_Status,
    Transactions_Count,
    Days_Since_Last_Transaction,
    Total_Inflows,
    Total_Outflows,
    Churn_Risk
FROM dbo.vw_customer_360
ORDER BY
    CASE Churn_Risk
        WHEN 'High' THEN 1
        WHEN 'Medium' THEN 2
        ELSE 3
    END,
    Days_Since_Last_Transaction DESC;

-- 10.2 Which cities generate the highest outflows?
SELECT
    City_Clean,
    SUM(Total_Outflows) AS Total_Outflows
FROM dbo.vw_customer_360
GROUP BY City_Clean
ORDER BY Total_Outflows DESC;

-- 10.3 Which customer segment has the highest average loan amount?
SELECT
    c.Customer_Segment,
    AVG(l.Loan_Amount) AS Avg_Loan_Amount
FROM dbo.vw_clean_customers c
INNER JOIN dbo.vw_clean_loans l
    ON c.Customer_ID = l.Customer_ID
GROUP BY c.Customer_Segment
ORDER BY Avg_Loan_Amount DESC;

-- 10.4 Which month had the highest transaction volume?
SELECT TOP 1
    Transaction_Month,
    COUNT(*) AS Transactions_Count,
    SUM(Amount_Abs) AS Total_Transaction_Volume
FROM dbo.vw_clean_transactions
GROUP BY Transaction_Month
ORDER BY Total_Transaction_Volume DESC;

-- 10.5 Find customers with no loans but high transaction activity
SELECT
    c.Customer_ID,
    c.First_Name,
    c.Last_Name,
    c.Transactions_Count,
    c.Total_Inflows,
    c.Total_Outflows
FROM dbo.vw_customer_360 c
WHERE c.Loans_Count = 0
  AND c.Transactions_Count >= 5
ORDER BY c.Transactions_Count DESC, c.Total_Inflows DESC;

/* =========================================================
   11. OPTIONAL: EXPORT-FRIENDLY FINAL VIEW
   ========================================================= */
SELECT
    Customer_ID,
    First_Name,
    Last_Name,
    Customer_Segment,
    Customer_Status,
    City_Clean,
    Age_Group,
    Tenure_Months,
    Transactions_Count,
    Total_Inflows,
    Total_Outflows,
    Avg_Transaction_Amount,
    Loans_Count,
    Total_Loan_Amount,
    Avg_Interest_Rate,
    Days_Since_Last_Transaction,
    Churn_Risk
FROM dbo.vw_customer_360
ORDER BY Customer_ID;
GO
