/*
=======================================================================================
CUSTOMER REPORT
=======================================================================================
Purpose:
	This report consolidates key customer metrics and behaviours.

Highlights:
	1. Gathers esential fields such as names,ages and transaction details.
	2. Segments customers into categories (VIP, Regular, New) and Age groups.
	3. Aggregates Customer level metrics:
		- total orders
		- total Sales 
		- total quantity purchased 
		- total products
		-lifespan (in months)
	4. Calculates Valuable KPI's:
		- recency (months since last order)
		- average order value
		- average monthly spend
=======================================================================================
*/
CREATE VIEW gold.report_customers AS 
WITH base_query AS (
/*-------------------------------------------------------------------------------------
Retrieving Core columns from tables
---------------------------------------------------------------------------------------*/
SELECT 
f.order_number,
f.product_key,
f.order_date,
f.sales_amount,
f.quantity,
c.customer_key,
c.customer_number,
CONCAT(c.firtsname, ' ', c.lastname) AS full_name,
DATEDIFF(year, c.birthday, GETDATE()) AS age
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key=c.customer_key
WHERE f.order_date IS NOT NULL
)

, customer_aggregation AS (
/*-------------------------------------------------------------------------------------
Customer Aggregation: Summarizes key metrics at the customer level.
---------------------------------------------------------------------------------------*/
SELECT 
	customer_key,
	customer_number,
	full_name,
	age,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT product_key) AS total_products,
	MAX(order_date) AS last_order_date,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan
FROM base_query
GROUP BY 
	customer_key,
	customer_number,
	full_name,
	age
)
SELECT
customer_key,
customer_number,
full_name,
age,
CASE WHEN age<20 THEN 'Below 20'
	 WHEN age BETWEEN 20 AND 29 THEN '20-29'
	 WHEN age BETWEEN 30 AND 39 THEN '30-39'
	 WHEN age BETWEEN 40 AND 49 THEN '40-49'
	 ELSE '50 and above'
END AS age_group,
CASE WHEN lifespan>=12 AND total_sales>5000 THEN 'VIP'
		 WHEN lifespan>=12 AND total_sales<=5000 THEN 'Regular'
		 ELSE 'New'
	END AS customer_segment,
last_order_date,
DATEDIFF(month, last_order_date, GETDATE()) AS recency,
total_orders,
total_sales,
total_quantity,
total_products,
lifespan,
--Compute average order value (AVO)
CASE WHEN total_orders=0 THEN 0
	ELSE total_sales/total_orders 
END AS avg_order_value,
--Compute average monthly spend(AMS)
CASE WHEN lifespan=0 then total_sales
	 ELSE total_sales/lifespan
END AS avg_monthly_spend
FROM customer_aggregation