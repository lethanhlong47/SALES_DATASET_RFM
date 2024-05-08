-- Data analysis
Select * From public.sales_dataset_rfm_prj_clean
-- Revenue by ProductLine, Year, and DealSize
SELECT 
	productline, 
	yearid, 
	dealsize,
	cast(SUM (sales) as decimal ) AS revenue
FROM sales_dataset_rfm_prj
GROUP BY productline, yearid, dealsize
Order by yearid ASC , revenue DESC


-- Which month had the highest sales each year?
-- Which month has the highest revenue?
SELECT 
	monthid,
	yearid,
	CAST(SUM (sales) as decimal) AS revenue,
	count(distinct ordernumber) AS total_order,
	
FROM sales_dataset_rfm_prj
GROUP BY monthid, yearid
ORDER BY yearid ASC, revenue DESC 
 
rank() OVER(PARTITION BY yearid, monthid  ORDER BY revenue DESC ) AS RANK1

 
--Which product line sells the most in November?
SELECT 
	monthid,
	yearid,
	productline,
	CAST(SUM (sales) AS DECIMAL) AS revenue,
	count( distinct ordernumber) AS order_quantity
FROM sales_dataset_rfm_prj
WHERE monthid = 11
GROUP BY monthid,productline,yearid
ORDER BY revenue DESC

--4) What is the top-selling product in the UK each year by revenue?

SELECT 
	yearid,
	productline,
	revenue
FROM (
	SELECT *,
	DENSE_RANK () OVER (PARTITION BY yearid ORDER BY revenue DESC) AS RANK
	FROM (
		SELECT 
			yearid, 
			productline, 
			cast(SUM (sales) as decimal) AS revenue
		FROM sales_dataset_rfm_prj
		WHERE country = 'UK'
		GROUP BY yearid, productline, country
		 ) as revenue_year
	) as rank_year
WHERE RANK = 1

-- Who are the best customers, RFM analysis

CREATE TABLE segment_score
(
    segment Varchar,
    scores Varchar)
Select * From public.segment_score

Select *
From public.sales_dataset_rfm_prj_clean;

With RFM_CTE as (
Select 
	customername,
	current_date - Max(orderdate) as Recency,
	count(Distinct ordernumber) as Frequency,
	sum(sales) as Monetary
From public.sales_dataset_rfm_prj_clean
Group by customername)
, RFM_SCORE AS (
Select 
	*,
	ntile(5) Over(Order by Recency DESC) AS R_Score,
	ntile(5) Over(Order by Frequency) as F_Score,
	ntile(5) Over(Order by Monetary) as M_Score
From RFM_CTE)
, RFM_FINAL AS (
Select 
	*,
	cast(R_Score as varchar) || cast(F_Score as varchar) || cast(M_Score as varchar) as RFM
From RFM_SCORE)

Select 
	*
From RFM_FINAL a join public.segment_score b on a.RFM =b.scores