/*==========================================================================================
										CHANGE OVER TIME
============================================================================================*/

--Total Sales, Total Customers and Total Quantity by Month/Year.
SELECT 
YEAR(order_date) AS order_year,
MONTH(order_date) AS order_month,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_cutomers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date),MONTH(order_date)
ORDER BY YEAR(order_date),MONTH(order_date)
-------------------------------------------------------------------
SELECT 
DATETRUNC(MONTH,order_date) AS order_date,
SUM(sales_amount) AS total_sales,
COUNT(DISTINCT customer_key) AS total_cutomers,
SUM(quantity) AS total_quantity
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH,order_date)
ORDER BY DATETRUNC(MONTH,order_date) 

/*==========================================================================================
										CUMULATIVE ANALYSIS
============================================================================================*/

--Calculate the running total of sales over time.
--By Month
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (PARTITION BY order_date ORDER BY order_date) AS running_total_sales
FROM
(
SELECT
DATETRUNC(MONTH, order_date) AS order_date,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(MONTH, order_date)
)t 

--By year
SELECT
order_date,
total_sales,
SUM(total_sales) OVER (ORDER BY order_date) AS running_total_sales
FROM
(
SELECT
DATETRUNC(YEAR, order_date) AS order_date,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR, order_date)
)t 

--Calculate the Moving Average of price by year.
SELECT 
order_date,
avg_price,
AVG(avg_price) OVER (ORDER BY order_date) AS moving_avg
FROM
(
SELECT 
DATETRUNC(YEAR,order_date) AS order_date,
AVG(price) AS avg_price
FROM gold.fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(YEAR,order_date)
)t

/*==========================================================================================
										PERFORMANCE ANALYSIS
============================================================================================

--Analyze the yearly performance of the products by comparing it to the average sales performance and 
the sales performance of the previous year*/
WITH yearly_product_sales AS (
SELECT 
YEAR(f.order_date) AS order_year,
p.product_name,
SUM(f.sales_amount) AS current_sales
FROM gold.fact_sales f
JOIN gold.dim_products p
ON f.product_key= p.product_key
WHERE f.order_date IS NOT NULL
GROUP BY 
YEAR(f.order_date),
p.product_name
)

SELECT 
order_year,
product_name,
current_sales,
AVG(current_sales) OVER (PARTITION BY product_name) AS avg_sales,
current_sales- AVG(current_sales) OVER (PARTITION BY product_name) AS diff_avg,
CASE WHEN current_sales- AVG(current_sales) OVER (PARTITION BY product_name)>0 THEN 'Above Avg'
	 WHEN current_sales- AVG(current_sales) OVER (PARTITION BY product_name)<0 THEN 'Below Avg'
	 ELSE 'Avg'
END AS indicator,
LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS prev_year_sales,
current_sales-LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year) AS yoy_diff,
CASE WHEN current_sales-LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)>0 THEN 'Increase'
	 WHEN current_sales-LAG(current_sales) OVER (PARTITION BY product_name ORDER BY order_year)<0 THEN 'Decrease'
	 ELSE 'Equal'
END AS indicator
FROM yearly_product_sales
ORDER BY 
product_name,
order_year

/*==========================================================================================
										PROPORTION ANALYSIS
============================================================================================*/

--Which categories contribute the most to the overall sales.
WITH category_sales AS (
SELECT
category,
SUM(sales_amount) AS total_sales
FROM gold.fact_sales
JOIN gold.dim_products
ON gold.dim_products.product_key=gold.fact_sales.product_key
GROUP BY category
)

SELECT 
category,
total_sales,
SUM(total_sales) OVER () AS overall_sales,
CONCAT(ROUND(CAST(total_sales AS float)/SUM(total_sales) OVER ()*100, 2),'%') AS precentage_of_total
FROM category_sales
ORDER BY total_sales DESC

/*==========================================================================================
										DATA SEGMENTATION
============================================================================================

Segment products intio cost ranges and how many products fall into each segment.*/
WITH product_segment AS (
SELECT 
product_key,
product_name,
cost,
CASE WHEN cost < 100 THEN 'Below 100'
	 WHEN cost BETWEEN 100 AND 500 THEN '100-500'
	 WHEN cost BETWEEN 500 AND 1000 THEN '500-1000'
	 ELSE 'Above 1000'
END AS cost_range
FROM gold.dim_products
)

SELECT 
cost_range,
COUNT(product_key) AS total_products
FROM product_segment
GROUP BY cost_range
ORDER BY total_products DESC

/*Group customers into three segments based on their  spending behaviour:
	-VIP:Customers with atleast 12 months of history and spending more than $5000.
	-Regular:Customers with atleast 12months of history and spend of $5000 or less
	-New: Customers with history of less than 12 months.
And find the total number of customers by each group.*/

WITH customer_spending AS (
SELECT 
c.customer_key,
SUM(f.sales_amount) AS total_spending,
MIN(order_date) AS first_order,
MAX(order_date) AS last_order,
DATEDIFF(MONTH,MIN(order_date),MAX(order_date)) AS lifespan
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c
ON f.customer_key=c.customer_key
GROUP BY c.customer_key
)
SELECT
COUNT(customer_key) AS total_customers,
customer_segment
FROM(
	SELECT 
	customer_key,
	CASE WHEN lifespan>=12 AND total_spending>5000 THEN 'VIP'
		 WHEN lifespan>=12 AND total_spending<=5000 THEN 'Regular'
		 ELSE 'New'
	END AS customer_segment 
FROM customer_spending
)t 
GROUP BY customer_segment


