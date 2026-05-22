CREATE DATABASE PROJECT;
USE PROJECT;

SELECT * FROM sales;
DESC sales;

set sql_safe_udates = 0;

UPDATE sales
SET new_shiporder = STR_TO_DATE(`ShipOrder`, '%d-%m-%Y');

ALTER TABLE sales
CHANGE COLUMN new_shiporder Date DATE;

UPDATE sales
SET new_orderdate = STR_TO_DATE(`OrderDate`, '%d-%m-%Y');

ALTER TABLE sales
CHANGE COLUMN new_orderdate Date DATE;


SELECT * FROM calender_file limit 10;
DESC calender_file;

set sql_safe_udates = 0;

UPDATE calender_file
SET new_date = STR_TO_DATE(`ï»¿Date`, '%d-%m-%Y');

ALTER TABLE calender_file
CHANGE COLUMN new_date Date DATE;

SELECT * FROM calender_file 
WHERE Date IS NULL OR
Year IS NULL OR
Quarter IS NULL	OR
`Quarter(Q)` IS NULL	OR
`Quarter_&_Year` IS NULL OR
Month IS NULL	OR
Month_Name IS NULL	OR
`Month_&_Year` IS NULL OR	
Week_of_Year IS NULL OR	
`Week_of_Year(W)` IS NULL OR	
Day_of_Week IS NULL	 OR
Day_Name IS NULL; 

SELECT * FROM sales
WHERE `ï»¿Row_ID` IS NULL OR	
Order_ID IS NULL OR	
OrderDate IS NULL OR	
ShipDate IS NULL OR	
Ship_Mode IS NULL OR	
Customer_ID IS NULL OR	
Customer_Name IS NULL OR	
Segment IS NULL OR	
Country IS NULL OR	
City IS NULL OR	
State IS NULL OR	
Postal_Code IS NULL OR	
Region IS NULL OR	
Retail_Sales_People IS NULL OR	
Product_ID IS NULL OR	
Category IS NULL OR	
`Sub-Category` IS NULL OR	
Product_Name IS NULL OR	
Returned IS NULL OR	
Sales IS NULL OR	
Quantity IS NULL OR	
Discount IS NULL OR	
Profit IS NULL;
 
-- 1. Year-over-Year (YoY) Sales & Profit Growt

SELECT Year, ROUND(SUM(Sales),2) AS Total_Sales,
             ROUND(SUM(Profit),2) AS Total_Profit
FROM sales AS s             
JOIN calender_file AS c
ON s.orderdate = c.Date
GROUP BY Year
ORDER BY Year;

-- 2. Seasonality (The Weekend Effect)

SELECT Day_Name, SUM(Sales) as Total_Sales, 
				 SUM(CASE WHEN Returned = "Yes" THEN 1 ELSE 0 END) AS Total_Return
FROM Sales AS s
JOIN Calender_file AS c
ON s.orderdate = c.Date
GROUP BY Day_Name
ORDER BY Total_Sales DESC;                  

-- 3.The Best Quarter 

SELECT Year, `Quarter(Q)`,
       ROUND(SUM(Sales),2) AS Total_Sales
FROM Sales AS s
JOIN Calender_file AS c     
ON s.orderdate = c.Date
GROUP BY Year, `Quarter(Q)`
ORDER BY Total_Sales DESC
LIMIT 1;  

-- 4.The Discount Trap

SELECT Category, `Sub-Category`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Discount) * 100, 2) AS AVG_Discount,
    ROUND(SUM(Profit), 2) AS Total_Profit
FROM Sales
GROUP BY Category, `Sub-Category`
ORDER BY Total_Profit ASC;

-- 5. The Return Problem

SELECT Region, COUNT(*) AS Total_Orders,
		SUM(CASE WHEN Returned = "Yes" THEN 1 ELSE 0 END) AS Return_Order,
        ROUND((SUM(CASE WHEN Returned = "Yes" THEN 1 ELSE 0 END) / COUNT(*)) * 100 ,2) AS AVG_Return
FROM Sales
GROUP BY Region
ORDER BY AVG_Return DESC;

-- 6.Top 10 Loss-Making Customers

SELECT Customer_ID, Customer_Name,
		ROUND(SUM(Sales),2) AS total_Sales,
        ROUND(SUM(Profit),2) AS total_loss
FROM Sales 
GROUP BY Customer_ID, Customer_Name
HAVING total_loss < 0
ORDER BY total_loss ASC
LIMIT 10;      
 
 -- 7. Shipping Delay Analysis
 
SELECT Ship_Mode,
		ROUND(AVG(DATEDIFF(ShipDate,OrderDate)),2) AS total_shipping_days
FROM Sales 
GROUP BY Ship_Mode
ORDER BY total_shipping_days ASC;

-- 8. Late Delivery Impact

WITH shipingdata AS (
		SELECT Order_ID, Returned,
        DATEDIFF(ShipDate, OrderDate) AS delivery_days
FROM Sales)

SELECT
	CASE WHEN delivery_days > 3 THEN "Late ( > 3 days)"  
    ELSE "On Time (<= 3 Days)" END AS Delivery_Status,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN Returned = "Yes" THEN 1 ELSE 0 END) AS Returns_orders,
    ROUND((SUM(CASE WHEN Returned = "Yes" THEN 1 ELSE 0 END) / COUNT(*)) * 100,2) AS return_rate
FROM shipingdata
GROUP BY Delivery_Status;   

-- 9. Salesperson Performance

SELECT
    Retail_Sales_People,
    ROUND(SUM(sales), 2) AS total_sales,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND((SUM(profit) / SUM(sales)) * 100, 2) AS profit_margin_pct
FROM sales
GROUP BY Retail_Sales_People
ORDER BY total_sales DESC;

-- 10. The Pareto Principle (80/20 Rule)

WITH customers_sales AS (
    SELECT Customer_ID, SUM(sales) AS total_sales
    FROM sales
    GROUP BY Customer_ID
),

ranked_customers AS (

    SELECT Customer_ID, total_sales,
    SUM(total_sales) OVER (ORDER BY total_sales DESC) AS runnig_total,
    (SELECT SUM(sales) FROM sales) AS grand_total
    FROM customers_sales
)

SELECT 
    COUNT(DISTINCT Customer_ID) AS top_customers_count,

    (SELECT COUNT(DISTINCT Customer_ID) 
     FROM sales) AS total_customers,

    ROUND(
        COUNT(DISTINCT Customer_ID) * 100.0 /
        (SELECT COUNT(DISTINCT Customer_ID) FROM sales),2)
     AS pct_of_cust_generating_80_pct_sales

FROM ranked_customers
WHERE runnig_total <= grand_total * 0.80;

-- 11. Customer Churn

WITH customer_years AS (
    SELECT 
        Customer_ID,
        Year
    FROM sales AS s
    JOIN calender_file AS c
        ON c.Date = s.OrderDate
    GROUP BY s.Customer_ID, c.Year
)
SELECT DISTINCT Customer_ID FROM customer_years
WHERE Customer_ID IN (
    SELECT Customer_ID
    FROM customer_years
    WHERE Year IN (2015, 2016)
)
AND Customer_ID NOT IN (
    SELECT Customer_ID
    FROM customer_years
    WHERE Year = 2017
);
-- 12. 30-Day Moving Average

WITH daily_sales AS (
SELECT Date AS order_date,
        SUM(Sales) AS daily_sales
    FROM Sales AS s
    JOIN Calender_file AS c
    ON s.OrderDate = c.Date
    GROUP BY order_date)

SELECT order_date, daily_sales,
    ROUND(AVG(daily_sales) OVER (ORDER BY order_date
            ROWS BETWEEN 29 PRECEDING AND CURRENT ROW),2) AS 30_day_moving_avg
FROM daily_sales
ORDER BY order_date;       

-- 13. Customer Segmentation (Mini RFM)

SELECT Customer_ID,
       Customer_Name,
       COUNT(DISTINCT Order_ID) AS total_orders,
       ROUND(SUM(sales),2) AS total_sales,
       CASE
           WHEN COUNT(DISTINCT Order_ID) = 1
                THEN 'One_time_buyer'
           WHEN SUM(sales) > 5000
                THEN 'VIP'
           ELSE 'REGULAR'
       END AS customer_segment
FROM sales
GROUP BY Customer_ID,
         Customer_Name
ORDER BY total_sales DESC;

-- 14. Month-over-Month (MoM) Growth

WITH monthly_sales AS (
    SELECT Year, Month, SUM(s.Sales) AS current_month_sales
    FROM sales AS s
    JOIN calender_file AS c
	ON c.Date = s.OrderDate
    GROUP BY Year, Month)

SELECT Year, Month,
		ROUND(current_month_sales,2) AS current_sales,
       ROUND(LAG(current_month_sales) OVER (ORDER BY Year, Month),2) AS 
       prev_month_sales,
       (((current_month_sales - LAG(current_month_sales) OVER (ORDER BY Year, Month))
			/ LAG(current_month_sales) OVER (ORDER BY Year, Month)) * 100) AS mom_growth_pct
        FROM monthly_sales;

-- 15. Most Profitable Route

SELECT
    State, City,
    COUNT(Order_ID) AS Total_Orders,
    ROUND(SUM(profit),2) AS total_profit,
    ROUND(SUM(profit) / COUNT(Order_ID),2) AS profit_per_order
FROM sales
GROUP BY State, City
HAVING Total_Orders > 10
ORDER BY profit_per_order DESC
LIMIT 5;
