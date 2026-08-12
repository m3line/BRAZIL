#CREATE DATABASE olist_ecommerce;
USE olist_ecommerce; 
ALTER TABLE olist_orders_dataset ADD INDEX (customer_id);
ALTER TABLE olist_orders_dataset ADD INDEX (order_id);
ALTER TABLE olist_order_items_dataset ADD INDEX (order_id);
ALTER TABLE olist_products_dataset ADD INDEX (product_id);
ALTER TABLE olist_order_reviews_dataset ADD INDEX (order_id);
ALTER TABLE olist_sellers_dataset ADD INDEX (seller_id);


-- KPI 1 (Key Performance Indicator) : Customer Lifetime Value (CLV) Analysis by Region

        #CALCULATE INDIVIDUAL CUSTOMER METRICS (CTE)
        WITH CustomerPurchases AS (
            SELECT 
                c.customer_unique_id,
                c.customer_state,
                SUM(it.price + it.freight_value) AS lifetime_spent -- freight_value = frais de ports

            FROM olist_orders_dataset o
            INNER JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
            INNER JOIN olist_order_items_dataset it ON o.order_id = it.order_id
            WHERE o.order_status = 'delivered'
            GROUP BY c.customer_unique_id, c.customer_state
        )
        #REGIONAL AGGREGATION & STRATEGIC INSIGHTS
        SELECT 
            customer_state AS state,
            COUNT(DISTINCT customer_unique_id) AS total_customers,
            ROUND(SUM(lifetime_spent), 2) AS total_clv,
            ROUND(AVG(lifetime_spent), 2) AS avg_clv,
            ROUND(MAX(lifetime_spent), 2) AS max_clv,
            ROUND(MIN(lifetime_spent), 2) AS min_clv
        FROM CustomerPurchases
        GROUP BY customer_state
        ORDER BY avg_clv DESC;


-- KPI 2 (Key Performance Indicator) : Sales Revenue Performance

        SELECT 
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,
            COUNT(DISTINCT o.order_id) AS total_orders_volume,
            ROUND(SUM(it.price), 2) AS pure_sales_revenue,
            ROUND(SUM(it.price + it.freight_value), 2) AS gross_merchandise_value
        FROM 
            olist_orders_dataset o
        INNER JOIN 
            olist_order_items_dataset it ON o.order_id = it.order_id
        WHERE 
            o.order_status IN ('delivered', 'shipped')
        GROUP BY 
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
        ORDER BY 
            sales_month ASC;


-- KPI 3 (Key Performance Indicator) : Average Purchase Value (APV) every time they place an order 

        SELECT 
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,
            ROUND(SUM(it.price), 2) AS monthly_pure_sales,
            COUNT(DISTINCT o.order_id) AS monthly_orders_volume,
            -- APV based on pure product price
            ROUND(SUM(it.price) / COUNT(DISTINCT o.order_id), 2) AS average_purchase_value_apv,
            -- Gross APV (pure product price + what clients spend on shipping)
            ROUND(SUM(it.price + it.freight_value) / COUNT(DISTINCT o.order_id), 2) AS gross_average_purchase_value
        FROM 
            olist_orders_dataset o
        INNER JOIN 
            olist_order_items_dataset it ON o.order_id = it.order_id
        WHERE 
            o.order_status IN ('delivered', 'shipped')
        GROUP BY 
            DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
        ORDER BY 
            sales_month ASC;


-- KPI 4 (Key Performance Indicator) : Customer Loyalty +  Re-purchase Behavior

        WITH CustomerOrderCounts AS (
            SELECT 
                c.customer_unique_id,
                -- Count total orders per unique id
                COUNT(DISTINCT o.order_id) AS total_orders_per_customer
            FROM 
                olist_orders_dataset o
            INNER JOIN 
                olist_customers_dataset c ON o.customer_id = c.customer_id
            WHERE 
                o.order_status = 'delivered'
            GROUP BY 
                c.customer_unique_id
        )
        SELECT 
            COUNT(*) AS total_unique_buyers,
            -- Number of loyal customers who came back at least once
            SUM(CASE WHEN total_orders_per_customer > 1 THEN 1 ELSE 0 END) AS repeat_customers_volume,
             -- Number of loyal customers who came back at least once in %
            ROUND(
                SUM(CASE WHEN total_orders_per_customer > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2) AS repeat_buyer_rate_pct,
            -- Number of customers who only ordered once and never returned in % 
            ROUND(
                SUM(CASE WHEN total_orders_per_customer = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*),2 ) AS one_time_buyer_rate_pct
        FROM 
            CustomerOrderCounts;


-- KPI 5 (Key Performance Indicator) : Advanced Logistics & Loyalty Correlation Matrix (DOUBLE CTE)
-- Objective: Analyze the direct correlation between company logistics performance (orders being delivered late,..) and customer repeat purchase behavior.

        WITH CustomerLogistics AS (
            SELECT 
                c.customer_unique_id,
                -- Count total orders per unique id
                COUNT(DISTINCT o.order_id) AS total_orders,
                -- captures the worst shipping delay a customer ever experienced in their lifecycle
                MAX(DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date)) AS worst_delay
            FROM olist_orders_dataset o
            INNER JOIN olist_customers_dataset c ON o.customer_id = c.customer_id
            WHERE o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL
            GROUP BY c.customer_unique_id
        ),

        DeliveryExperienceGroups AS (
            SELECT 
                customer_unique_id,
                total_orders,
                CASE 
                    WHEN worst_delay > 0 THEN ' Experienced Late Delivery'
                    ELSE 'All Deliveries On-Time / Early'
                END AS logistics_experience
            FROM CustomerLogistics
        )

        SELECT 
            logistics_experience,
            COUNT(*) AS total_customers_in_segment,
            -- Calculate the repeat buyer rate for each specific group
            ROUND(SUM(CASE WHEN total_orders > 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS repeat_buyer_rate_pct,
            -- Calculate the one-time buyer rate for each specific group
            ROUND(SUM(CASE WHEN total_orders = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS one_time_buyer_rate_pct
        FROM DeliveryExperienceGroups
        GROUP BY logistics_experience;

-- KPI 6 (Key Performance Indicator) :Sales Growth Rate (monthly)

 WITH MonthlyRevenue AS (
            SELECT 
                DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS sales_month,
                ROUND(SUM(it.price), 2) AS current_month_sales
            FROM olist_orders_dataset o
            INNER JOIN olist_order_items_dataset it ON o.order_id = it.order_id
            WHERE o.order_status IN ('delivered', 'shipped')
            GROUP BY DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')
        ),
        WithLag AS (
            SELECT 
                sales_month,
                current_month_sales,
                LAG(current_month_sales, 1) OVER (ORDER BY sales_month) AS previous_month_sales
            FROM MonthlyRevenue
        )
        SELECT 
            sales_month,
            current_month_sales AS sales_revenue,
            previous_month_sales,
            ROUND((current_month_sales - previous_month_sales) * 100.0 / previous_month_sales, 2) AS sales_growth_rate_pct
        FROM WithLag
        -- Excludes the test period (late 2016) to ensure legible charts and avoid calculation errors.
        WHERE sales_month >= '2017-02' 
        ORDER BY sales_month ASC;

-- KPI 7 (Key Performance Indicator) : Product Performance Analysis

        SELECT 
                    p.product_category_name AS product_category,
                    COUNT(DISTINCT o.order_id) AS total_orders_volume,
                    ROUND(SUM(it.price), 2) AS pure_sales_revenue,
                    ROUND(SUM(it.price + it.freight_value), 2) AS gross_merchandise_value,
                    -- % of freights cost relative to the product price
                    ROUND((SUM(it.freight_value) / SUM(it.price)) * 100.0, 2) AS logistics_cost_ratio_pct
                FROM 
                    olist_orders_dataset o
                INNER JOIN 
                    olist_order_items_dataset it ON o.order_id = it.order_id
                INNER JOIN 
                    olist_products_dataset p ON it.product_id = p.product_id
                WHERE 
                    o.order_status = 'delivered'
                    AND p.product_category_name IS NOT NULL
                GROUP BY 
                    p.product_category_name
                ORDER BY 
                    pure_sales_revenue DESC
                LIMIT 15; 

-- KPI 8 (Key Performance Indicator) : Customer Experience >>> Review Score + Delay Correlation

        WITH CustomerLogistics AS (
            SELECT 
                o.order_id,
                DATEDIFF(o.order_delivered_customer_date, o.order_estimated_delivery_date) AS delivery_delay
            FROM olist_orders_dataset o
            WHERE o.order_status = 'delivered'
              AND o.order_delivered_customer_date IS NOT NULL
        ),

        DeliveryExperienceGroups AS (
            SELECT 
                order_id,
                CASE 
                    WHEN delivery_delay > 0 THEN ' Experienced Late Delivery'
                    ELSE 'All Deliveries On-Time / Early'
                END AS logistics_experience
            FROM CustomerLogistics
        )

        SELECT 
            g.logistics_experience,
            COUNT(*) AS total_reviews_analyzed,
            ROUND(AVG(r.review_score), 2) AS avg_customer_satisfaction_score
        FROM DeliveryExperienceGroups g
        INNER JOIN olist_order_reviews_dataset r ON g.order_id = r.order_id
        GROUP BY g.logistics_experience;
