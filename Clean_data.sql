-- Clean data 
Select * From public.sales_dataset_rfm_prj

-- Convert appropriate data types for fields
ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN ordernumber TYPE numeric USING (TRIM(ordernumber):: numeric)

ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN quantityordered TYPE numeric USING (TRIM(quantityordered):: numeric)
  
ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN priceeach TYPE numeric USING (TRIM(priceeach):: numeric)
  
ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN orderlinenumber TYPE numeric USING (TRIM(orderlinenumber):: numeric);

ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN sales TYPE float USING (TRIM(sales):: float);

SET datestyle = 'iso,mdy';  
ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN orderdate TYPE date USING (TRIM(orderdate):: date);

ALTER TABLE sales_dataset_rfm_prj
ALTER COLUMN msrp TYPE numeric USING (TRIM(msrp):: numeric)

--Check NULL/BLANK 
Select * From sales_dataset_rfm_prj
Where QUANTITYORDERED is null
Or ORDERNUMBER is null
Or PRICEEACH is null
Or ORDERLINENUMBER is null
Or SALES is null
Or ORDERDATE is null

/* Normalize CONTACTFULLNAME:
Add column CONTACTLASTNAME, CONTACTFIRSTNAME extracted from CONTACTFULLNAME.
Normalize CONTACTLASTNAME, CONTACTFIRSTNAME to capitalize the first letter.
*/
Alter table sales_dataset_rfm_prj
Add column CONTACTFIRSTNAME character varying(100);
Alter table sales_dataset_rfm_prj
Add column CONTACTLASTNAME character varying(100);

Update sales_dataset_rfm_prj
Set 
	CONTACTLASTNAME = (Left(contactfullname,position('-' IN contactfullname)-1) ),
	CONTACTFIRSTNAME = (RIGHT(contactfullname,length(contactfullname) - position('-' IN contactfullname)) )
	
UPDATE SALES_DATASET_RFM_PRJ
SET contactlastname = UPPER(LEFT(contactlastname, 1)) || RIGHT(contactlastname, LENgth(contactlastname) - 1),
    contactfirstname = UPPER(LEFT(contactfirstname, 1)) || RIGHT(contactfirstname, LENgth(contactfirstname) - 1);

-- Data Transformation:
-- Add columns QTR_ID, MONTH_ID, YEAR_ID respectively representing Quarter, Month, Year extracted from ORDERDATE
ALTER TABLE SALES_DATASET_RFM_PRJ
ADD COLUMN qtrid INT,
ADD COLUMN monthid INT,
ADD COLUMN yearid INT;

UPDATE SALES_DATASET_RFM_PRJ
SET qtrid = EXTRACT('quarter' FROM ORDERDATE),
  	monthid = EXTRACT('month' FROM ORDERDATE),
  	yearid = EXTRACT('year' FROM ORDERDATE);

-- Detecting outliers and handling outlier values
-- Use box plot: min = Q1 -IQR*1,5: Max = Q3+IQR*1.5
With cte_iqr  as (
Select 
	Q1 - IQR*1,5 as min_v,
	Q3 + IQR*1.5 as max_v
From(
Select 
 Percentile_cont(0.25) within group(order by quantityordered) as Q1,
 Percentile_cont(0.75) within group(order by quantityordered) as Q3,
 Percentile_cont(0.75) within group(order by quantityordered) - percentile_cont(0.25) within group(order by quantityordered) as IQR
From SALES_DATASET_RFM_PRJ) as ab)
Select * From SALES_DATASET_RFM_PRJ 
Where quantityordered > (select max_v from cte_iqr)
Or quantityordered < (select min_v from cte_iqr)

-- Use z-score = (quantityordered - avg)/STDDEV
With CTE_ZSCORE as (
Select
	quantityordered,
	(SELECT
  	AVG(quantityordered) 
	FROM SALES_DATASET_RFM_PRJ) AS avg_quantityordered,
	(SELECT
  	STDDEV(quantityordered) 
	FROM SALES_DATASET_RFM_PRJ) AS std_quantityordered
FROM SALES_DATASET_RFM_PRJ
)
,twt_outlier as (
Select 
	quantityordered,
	(quantityordered - avg_quantityordered)/std_quantityordered as z_score
From CTE_ZSCORE
Where abs((quantityordered - avg_quantityordered)/std_quantityordered) >3
Or abs((quantityordered - avg_quantityordered)/std_quantityordered) <-3
)

--- Outlier treatment
-- Update outlier values with the mean value
Update SALES_DATASET_RFM_PRJ
Set quantityordered = (SELECT AVG(quantityordered) FROM SALES_DATASET_RFM_PRJ)
Where quantityordered in (select quantityordered from twt_outlier)
					   
-- Delete outlier values
Delete From SALES_DATASET_RFM_PRJ
Where quantityordered in (select * from twt_outlier)


-- After cleaning the data, save it to a new table named SALES_DATASET_RFM_PRJ_CLEAN.

CREATE TABLE SALES_DATASET_RFM_PRJ_CLEAN AS
SELECT *
FROM sales_dataset_rfm_prj
WHERE 
    ORDERNUMBER IS NOT NULL AND
    QUANTITYORDERED IS NOT NULL AND
    PRICEEACH IS NOT NULL AND
    ORDERLINENUMBER IS NOT NULL AND
    SALES IS NOT NULL AND
    ORDERDATE IS NOT NULL;

Select * From SALES_DATASET_RFM_PRJ_CLEAN

