# 🏦 Banking Customer Analytics – SQL Project

![SQL](https://img.shields.io/badge/Tool-SQL%20Server-blue)
![Analytics](https://img.shields.io/badge/Focus-Data%20Analytics-green)
---

## 🚀 Project Overview

This project focuses on **customer analytics in a banking environment**, using SQL to transform raw transactional data into **actionable business insights**.

The main goal was to simulate a real-world analytical scenario where a data analyst:

* cleans and prepares data
* builds analytical datasets
* identifies patterns in customer behavior
* evaluates churn risk and financial activity

---

## 🎯 Objectives

* Analyze customer transactions and behavior
* Identify **high-risk (churn) customers**
* Evaluate **financial activity patterns**
* Build a reusable **analytical SQL layer**
* Demonstrate SQL skills required for banking/data analyst roles

---

## 🗂️ Data Model

The dataset simulates a banking system with multiple entities:

* **Customers** – demographic and segmentation data
* **Accounts** – account details and status
* **Transactions** – financial activity
* **Loans** – credit products
* **Cards** – payment instruments

---

## 🛠️ SQL Techniques Used

This project demonstrates practical SQL skills used in real analytics work:

### 🔹 Data Cleaning

* Handling nulls and missing values
* Standardizing text fields (TRIM, UPPER/LOWER)
* Creating derived columns (age, tenure, segments)

---

### 🔹 Data Transformation

* Creating **clean views** for analysis
* Building a **Customer 360 dataset**
* Aggregating transactional data

---

### 🔹 Advanced SQL

#### ✔ Window Functions

* `ROW_NUMBER()` → latest transaction per account
* `RANK()` → ranking customers by inflows
* `LAG()` → month-over-month analysis
* `LEAD()` → next transaction tracking

---

#### ✔ CTE (Common Table Expressions)

* Multi-step transformations
* Monthly cash flow analysis
* Customer segmentation logic

---

#### ✔ Subqueries

* Filtering above-average behavior
* Comparing customer activity vs global metrics

---

#### ✔ GROUP BY & HAVING

* Customer segmentation
* Transaction aggregation
* Fraud rate calculation

---

#### ✔ Temporary Tables

* Identifying high-value customers
* Intermediate analysis layers

---

## 📊 Key Analytical Outputs

### 🔹 Customer 360 View

A unified dataset combining:

* transactions
* loans
* behavioral metrics
* churn risk

---

### 🔹 Churn Risk Analysis

Customers are segmented into:

* 🔴 High Risk
* 🟠 Medium Risk
* 🟢 Low Risk

Based on:

* inactivity
* transaction frequency
* financial behavior

---

### 🔹 Transaction Analysis

* monthly inflows vs outflows
* channel performance
* fraud rate by channel

---

### 🔹 Loan Analysis

* loan distribution by type
* risk segmentation based on interest rates

---

## 💡 Key Business Insights

* Customers with **low activity** are significantly more likely to churn
* **High outflows vs inflows** may indicate financial risk
* A small group of customers generates the majority of transaction volume
* Loan characteristics can help identify **risk segments**

---

## 📈 Example Queries

### 🔹 Churn Risk Customers

```sql
SELECT *
FROM dbo.vw_customer_360
WHERE Churn_Risk = 'High';
```

---

### 🔹 Monthly Cash Flow Trend

```sql
SELECT
    Transaction_Month,
    SUM(CASE WHEN Direction = 'In' THEN Amount_Abs ELSE 0 END) AS Inflows,
    SUM(CASE WHEN Direction = 'Out' THEN Amount_Abs ELSE 0 END) AS Outflows
FROM dbo.vw_clean_transactions
GROUP BY Transaction_Month;
```

---

### 🔹 Top Customers by Inflows

```sql
SELECT
    Customer_ID,
    Total_Inflows,
    RANK() OVER (ORDER BY Total_Inflows DESC) AS Rank
FROM dbo.vw_customer_360;
```

---

## 🧠 What I Learned

* How to structure SQL code for **real analytical projects**
* How to move from raw data to **business insights**
* Practical usage of **window functions and CTEs**
* Designing datasets ready for **BI tools (Power BI / Excel)**

---

## 📌 Project Highlights

* Realistic banking scenario
* Clean and structured SQL code
* Strong focus on **business logic**
* End-to-end analytical workflow

---

## 📎 How to Use

1. Run the raw dataset script:

```sql
banking_test_dataset.sql
```

2. Run the analytics layer:

```sql
banking_analytics_recruitment_pack.sql
```

3. Explore queries and views

---

## 📬 Contact

If you'd like to connect or discuss this project:

👉 GitHub: *(your link)*
👉 LinkedIn: *(your link)*

---

⭐ If you found this useful, feel free to leave a star!
