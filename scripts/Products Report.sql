/*
=======================================================================================
PRODUCT REPORT
=======================================================================================
Purpose:
	This report consolidates key product metrics and behaviours.

Highlights:
	1. Gathers esential fields such as product name, category, subcategory and cost.
	2. Segments products by revenue to segment high-performers, mid-range and low-performers.
	3. Aggregates product level metrics:
		- total orders
		- total Sales 
		- total quantity sold
		- total customers (unique)
		-lifespan (in months)
	4. Calculates Valuable KPI's:
		- recency (months since last sale)
		- average order revenue
		- average monthly revenue
=======================================================================================
*/

CREATE VIEW gold.report_products AS 
WITH base_query AS (
/*-------------------------------------------------------------------------------------
Retrieving Core columns from tables
---------------------------------------------------------------------------------------*/

SELECT 
	f.order_date,
	f.order_number,
	f.sales_amount,
	f.quantity,
	f.customer_key,
	p.product_key,
	p.category,
	p.product_name,
	p.sub_category,
	p.cost
FROM gold.fact_sales f
	LEFT JOIN gold.dim_products p
	ON f.product_key=p.product_key
WHERE order_date IS NOT NULL
) ,

product_aggregation AS (
/*-------------------------------------------------------------------------------------
Product Aggregation: Summarizes key metrics at the product level.
---------------------------------------------------------------------------------------*/
SELECT
	product_key,
	product_name,
	category,
	sub_category,
	cost,
	DATEDIFF(month, MIN(order_date), MAX(order_date)) AS lifespan,
	COUNT(DISTINCT order_number) AS total_orders,
	SUM(sales_amount) AS total_sales,
	SUM(quantity) AS total_quantity,
	COUNT(DISTINCT customer_key) AS total_customers,
	MAX(order_date) AS last_sale_date,
	ROUND(AVG(CAST(sales_amount AS FLOAT)/ NULLIF(quantity,0)),1) AS avg_selling_price
FROM base_query
GROUP BY 
	product_key,
	product_name,
	category,
	sub_category,
	cost
)

/*-------------------------------------------------------------------------------------
Final Query: Combines all results in a single output.
---------------------------------------------------------------------------------------*/

SELECT
	product_key,
	product_name,
	category,
	sub_category,
	cost,
	last_sale_date,
	DATEDIFF(MONTH, last_sale_date, GETDATE()) AS recency_in_months,
	CASE 
		WHEN total_sales >50000 THEN 'High-performer'
		WHEN total_sales >=10000 THEN 'Mid-range'
		ELSE 'Low-performer'
	END AS product_segment,
	lifespan,
	total_orders,
	total_sales,
	total_quantity,
	total_customers,
	avg_selling_price,
--AVERAGE ORDER REVENUE
	CASE 
		WHEN total_orders=0 THEN 0
		ELSE total_sales / total_orders
	END AS avg_order_revenue,

--AVERAGE MONTHLY REVENUE
	CASE 
		WHEN lifespan=0 THEN 0
		ELSE total_sales / lifespan
	END AS avg_monthly_revenue

FROM product_aggregation