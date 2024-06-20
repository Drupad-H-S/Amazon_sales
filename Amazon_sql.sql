--  top 5 customers who made the highest profits

SELECT c.customer_name,
       SUM(o.sale) as total_sales
FROM customers c 
     join orders o
     on c.customer_id = o.customer_id
group by 1
order by 2 DESC
LIMIT 5;



-- Find out the average quantity ordered per category

SELECT category,
	   AVG (quantity) AS avg_percategory
	FROM orders
	WHERE category IS NOT NULL
GROUP BY 1



-- Identify the top 5 products that have generated the highest revenue.

SELECT 
    p.product_name,
    SUM(o.quantity * (p.price - p.cogs)) AS total_profit
FROM
    products p
JOIN
    orders o ON p.product_id = o.product_id
GROUP BY
    p.product_name
ORDER BY
    total_profit DESC
LIMIT 5;



--Determine the top 5 products whose revenue has decreased compared to last year

with y22
AS
(
	SELECT 
	product_id,
	EXTRACT(YEAR FROM order_date ) as y_22,
	sale as sale_22
	FROM orders
	WHERE EXTRACT(YEAR FROM order_date ) = 2022
),

y23
as
(
	SELECT
	product_id,
	EXTRACT (YEAR FROM order_date) as y_23,
	sale as sale_23
	from orders
	WHERE EXTRACT(YEAR FROM order_date) = 2023
)
SELECT p.product_name,
	y22.sale_22,
	y23.sale_23,
y22.sale_22 - y23.sale_23 as revenue_decreased
FROM y22
join y23 on y22.product_id = y23.product_id
join products p on y23.product_id = p.product_id
ORDER BY  revenue_decreased DESC
	limit 5;



-- Identify the highest profitable sub-category.

SELECT 
    o.sub_category,
   sum(p.price - p.cogs) AS profits
FROM orders o
JOIN products p ON p.product_id = o.product_id
	group by 1
ORDER BY profits DESC
	limit 1;


--  Find out the states with the highest total orders.

SELECT state,
 count(order_id) as no_of_orders
from orders
	WHERE state IS NOT NULL
group by 1


-- Determine the month with the highest number of orders

WITH monthly_orders AS (
    SELECT 
        EXTRACT(YEAR FROM order_date) AS order_year,
        EXTRACT(MONTH FROM order_date) AS order_month,
        order_date,
        COUNT(order_id) AS total_orders
    FROM orders
    GROUP BY order_year, order_month, order_date
)
SELECT 
    mo.order_year,
    TO_CHAR(mo.order_date, 'Month') AS highest_month,
    mo.total_orders AS max_orders
FROM monthly_orders mo
JOIN (
    SELECT 
        order_year,
        MAX(total_orders) AS max_orders
    FROM monthly_orders
    GROUP BY order_year
) max_per_year ON mo.order_year = max_per_year.order_year AND mo.total_orders = max_per_year.max_orders
ORDER BY mo.order_year;



--Calculate the profit margin percentage for each sale (Profit divided by Sales).

SELECT 
    o.order_id,
    p.product_name,
    o.quantity,
    o.price_per_unit,
    o.sale,
    p.cogs,
    (o.sale - (o.quantity * p.cogs)) AS profit,
    ((o.sale - (o.quantity * p.cogs)) / o.sale) * 100 AS profit_margin_percentage
FROM orders o
JOIN products p ON o.product_id = p.product_id;



-- Calculate the percentage contribution of each sub-category.

WITH sub_category_sales AS (
    SELECT 
        sub_category,
        SUM(sale) AS total_sales
    FROM orders
    GROUP BY sub_category
),
total_sales AS (
    SELECT 
        SUM(sale) AS grand_total_sales
    FROM orders
)
SELECT 
    sc.sub_category,
    sc.total_sales,
    (sc.total_sales / ts.grand_total_sales) * 100 AS percentage_contribution
FROM sub_category_sales sc, total_sales ts
ORDER BY percentage_contribution DESC;


-- Identify the top 2 categories that have received maximum returns and their return percentage.

WITH category_returns AS (
    SELECT 
        o.category,
        COUNT(r.return_id) AS total_returns
    FROM returns r
    JOIN orders o ON r.order_id = o.order_id
    GROUP BY o.category
),
category_orders AS (
    SELECT 
        o.category,
        COUNT(o.order_id) AS total_orders
    FROM orders o
    GROUP BY o.category
)
SELECT 
    cr.category,
    cr.total_returns,
    co.total_orders,
    (cr.total_returns::decimal / co.total_orders) * 100 AS return_percentage
FROM category_returns cr
JOIN category_orders co ON cr.category = co.category
ORDER BY cr.total_returns DESC
LIMIT 2;


/*Determine the top 5 products whose revenue has decreased compared to the previous year(2022) current year(2023).
return product_id, last year_sale, current_year sale, decreasing ratio and we need top 5 */

SELECT *
FROM 
(    
    WITH last_year_sale
    AS
    (    
        SELECT 
            product_id,
            SUM(sale) as lr_total_sale
        FROM orders
        WHERE order_date BETWEEN '2022-01-01' AND '2022-12-31'
        GROUP BY product_id
    ),
    
    current_year_sale
    AS   
    (
        SELECT 
            product_id,
            SUM(sale) as cr_total_sale
        FROM orders
        WHERE order_date BETWEEN '2023-01-01' AND '2023-12-31'
        GROUP BY product_id
    )
    
    SELECT *,
        (ls.lr_total_sale - cs.cr_total_sale) as amt_reduce,
        (ls.lr_total_sale - cs.cr_total_sale)::numeric/ls.lr_total_sale::numeric  * 100 as percentage_reduce,
        DENSE_RANK() OVER(ORDER  BY (ls.lr_total_sale - cs.cr_total_sale)::numeric/ls.lr_total_sale::numeric  * 100 DESC)
        as d_rank
    FROM last_year_sale as ls
    JOIN
    current_year_sale as cs
    ON  ls.product_id = cs.product_id
    WHERE ls.lr_total_sale > cs.cr_total_sale

)    as x
WHERE d_rank <= 5;


--Find Top 5 states by total orders where each state sale is greater than average orders accross orders.

SELECT 
    state, -- 1
    COUNT(*) as total_orders
FROM orders
WHERE state IS NOT NULL    
GROUP BY 1
HAVING  COUNT(*) > (SELECT COUNT(*)/(SELECT COUNT(DISTINCT state) FROM orders) FROM orders)
ORDER BY 2 DESc
    lIMIT 5


	
--10 customers details who has spent more than average spent by all customers,return customer_name, total_spent
select 
    c.customer_id,
    c.customer_name,
    ROUND(Sum(o.sale)::numeric, 2) as Total_Sale
from orders o 
join customers c
on c.customer_id=o.customer_id    
group by c.customer_id, c.customer_name
having Sum(o.sale) > (select SUM(sale)/COUNT(DIStinct customer_id) from orders)
order by Total_Sale desc
limit 10;


/*Identify returning customers: Label customers as "Returning" if they have placed more than one returns; 
otherwise, mark them as "New." return customer_id, total_orders, total_returns*/

SELECT 
    o.customer_id,
    c.customer_name,
    COUNT(o.order_id) as total_orders,
    COUNT(r.return_id) as total_orders_returned,
    CASE
        WHEN COUNT(r.return_id) > 1 THEN 'returning_customer'
        ELSE 'new_customre'
    END as cx_category
FROM orders as o
LEFT JOIN 
returns as r
ON r.order_id = o.order_id
INNER JOIN customers as c
ON o.customer_id = c.customer_id
GROUP BY o.customer_id, c.customer_name




















