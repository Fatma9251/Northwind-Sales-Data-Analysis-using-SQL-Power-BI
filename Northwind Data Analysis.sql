-------- General Questions popped up to my mind during analysis ----------------

-- From what date is that data being collected?
SELECT MIN(DATE(orderdate))
from Orders
-- From September, 2012 / Approx. 12 years

-- what is the total revenue along this period?
SELECT SUM(unitprice*quantity*(1-discount)) AS Total_Revenue
FROM "Order Details"
-- 448,386,633$ (0.5 billion dollars approx.)

--------------------------------------- Customer Segmentation Section ------------------------------------------------
---------------------------- RFM-wise Customer Segmentation --------------------------------------------------------
-------Create a view to hold the RFM Analysis on Customers----------------------
DROP VIEW IF EXISTS RFM_CustomersView
CREATE VIEW RFM_CustomersView
AS 
select customerid
, ROUND(MIN(julianday(DATE('Now')) - julianday(orderdate))) AS Recency
, COUNT(Orders.orderid) AS Frequency
, Round(SUM(unitprice*quantity*(1-discount)), 2) AS Revenue
FROM Orders
JOIN "Order Details"
ON Orders.OrderID = "Order Details"."OrderID"
GROUP by 1
order by 2 
-----------------------------------------------------------------------------
Select * 
FROM RFM_CustomersView
-----------------------------------------------------------------------------
-- Now Let'e use it to segment customers to {Champions, Potential Loyalists, At Risk}
-- At first, I need to navigate the RFM_CustomersView to 
-- learn more about how I m*ay define the boundaries for each Segment

-- How many customers in the analysis?
SELECT COUNT(*)
FROM RFM_CustomersView
-- There're 93 customers under analysis

-- What's the min, max, and avg of Recency, Frequency, Revenue?
SELECT MIN(Recency), AVG(Recency), MAX(Recency)
FROM RFM_CustomersView
-- min = 423 , avg = 449.96,  max = 593

SELECT MIN(Frequency), AVG(Frequency), MAX(Frequency)
FROM RFM_CustomersView
-- min = 5325 , avg = 6551,  max = 8287

SELECT MIN(Revenue), AVG(Revenue), MAX(Revenue), SUM(Revenue)
FROM RFM_CustomersView
-- min = 3,965,464$ -- avg = 4,821,361$ --  max = 6,154,115  
-- Total_Revenue = 448,386,633$ (0.5 billion dollars approx.)

--------- Having these RFM ranges; Let's Define the segments boundaries ------------
-- For Recency (The lower the better):
------ Champions: receny < 440 
------ Potential Loyalists: recency between 440 and 495
------ At Risk: recency > 495

-- For Frequency (The higher the better):
------ Champions: Freq > 7200 
------ Potential Loyalists: Freq between 6000 and 7199
------ At Risk: Freq < 6000

-- For Revenue (The higher the better):
------ Champions: Rev > 5.5 million dollars 
------ Potential Loyalists: Freq between 4.5 and 5.5 million dollars
------ At Risk: Rev < 4.5 million dollars

--------- Let's write some starting queries for this and iterate if needed ------
SELECT 
CASE 
WHEN Recency < 440 THEN 'Champion'
WHEN (Recency >= 440 AND Recency < 495) THEN 'Potential Loyalist'
WHEN Recency >= 495 THEN 'At Risk'
ELSE 'Not Defined'     -- For checking a healthy case statement
END AS CustomerSegment, 
COUNT(*) as countOfSegment
FROM RFM_CustomersView
GROUP by 1

-- Let's combine the other features (Freq, Revenue) to the segmentation----------
DROP VIEW IF EXISTS CustomerSegmentView
CREATE VIEW CustomerSegmentView
AS
SELECT *,
CASE 
WHEN (Recency <= 440) And (Frequency > 7200) AND (Revenue > 5500000) THEN 'Champion'
WHEN (Frequency BETWEEN 6200 AND 7200)
    OR (Revenue BETWEEN 4500000 AND 5500000) 
    THEN 'Potential Loyalist'
ELSE 'AT RISK'       
END AS CustomerSegment
FROM RFM_CustomersView


/* SELECT 
CASE 
WHEN (Recency <= 440) And (Frequency > 7200) AND (Revenue > 5500000) THEN 'Champion'
WHEN (Frequency BETWEEN 6200 AND 7200)
    OR (Revenue BETWEEN 4500000 AND 5500000) 
    THEN 'Potential Loyalist'
ELSE 'AT RISK'    
END AS CustomerSegment, 
COUNT(*) as countOfSegment
FROM RFM_CustomersView
GROUP by 1
*/

SELECT CustomerSegment, COUNT(*)
FROM CustomerSegmentView
GROUP by 1

-- according to our analysis:
-- 5 Champions
-- 68 are potential loyals (we need to work on winning this wide range of potential customers)
-- 20 At risk   (we need to minimmize this number as much as we can)

------- For Further analysis let's see more info about our 4 Champions ----------
/*SELECT customerid, companyname, region, country
FROM Customers
WHERE customerid IN (SELECT customerid 
                     from CustomerSegmentView 
                     Where CustomerSegment = 'Champion')*/
             
SELECT Customers.customerid, companyname, region, country
FROM Customers
JOIN CustomerSegmentView
ON Customers.CustomerID = CustomerSegmentView.CustomerID
WHERE CustomerSegment = 'Champion'                   
-- Insight: They're distributed over different countries i.e. Mexico, USA, UK, France, Brazil

------- For Further analysis let's see more info about our 21 At Risk customers ----------
SELECT Customers.customerid, companyname, region, country
FROM Customers
JOIN CustomerSegmentView
ON Customers.CustomerID = CustomerSegmentView.CustomerID
WHERE CustomerSegment = 'AT RISK'  
                     
SELECT country, count(country) AS AtRiskCustomersCount
FROM Customers
JOIN CustomerSegmentView
ON Customers.CustomerID = CustomerSegmentView.CustomerID
WHERE CustomerSegment = 'AT RISK' 
GROUP BY 1
order by 2 Desc
-- Insight: Germany has the highest number of "At Risk" customers
-- Countries like {USA, UK, France, Brazil} who had a champion, also recorded 2 AT RISK customers


SELECT country, count(customerid) as customersCount
FROM Customers
GROUP by 1
order by 2 desc
------- For Further analysis let's see more info about our 68 Potential Loyal customers ----------
SELECT Customers.customerid, companyname, region, country
FROM Customers
JOIN CustomerSegmentView
ON Customers.CustomerID = CustomerSegmentView.CustomerID
WHERE CustomerSegment = 'Potential Loyalist' 
                     
SELECT country, count(country) AS PotentialLoyalCustomersCount
FROM Customers
JOIN CustomerSegmentView
ON Customers.CustomerID = CustomerSegmentView.CustomerID
WHERE CustomerSegment = 'Potential Loyalist' 
AND country IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC
-- USA has 10 potential customers
-- France and Germany  has 8, 7 potential customers
---------------- NULL in Customer Country ----------------------
SELECT *
from Customers
WHERE country IS NULL
-- 2 rows in the customer table with null values in all customer info cols

------------------------------------ Order-wise Customer Segmentation ------------------------------------------------
-- High-Value, Medium-Value, Low-Value customers 
-- based on their avarage order revenue value. 
DROP VIEW IF EXISTS OrderValue_CustomerView
CREATE VIEW OrderValue_CustomerView
AS
SELECT Orders.customerid, ROUND(AVG(unitprice*quantity*(1-discount)),2) AS AvgOrderValue
FROM Orders
JOIN "Order Details" od
ON od.orderId = Orders.OrderID
GROUP BY 1
Order by 2 desc

SELECT * 
FROM OrderValue_CustomerView

------ Let's calc the OrderValue ranges to determine the ranges of the segments
SELECT MIN(AvgOrderValue), ROUND(AVG(AvgOrderValue), 2), MAX(AvgOrderValue)
FROM OrderValue_CustomerView
-- min = 713.63   -- avg = 735.93  -- max = 755.25

----- Defining Segments Boundaries:
--- For High-Value:
	-- AvgOrderValue > 745$
--- For Medium-Value:
	-- AvgOrderValue between 725$ and 745
--- For low-Value:
	-- AvgOrderValue < 725$
    
--------- Let's write some starting queries for this and iterate if needed ------------
drop if EXISTS OrderValCustomerSegmentView
CREATE view OrderValCustomerSegmentView
AS
SELECT customerid,
CASE 
WHEN AvgOrderValue > 745 THEN 'High-Value'
WHEN AvgOrderValue BETWEEN 725 AND 745 THEN 'Medium-Value'
WHEN AvgOrderValue < 725 THEN 'Low-Value'
ELSE 'NOT DEFINED'   -- for checking a healthy case statement
END AS OrderValSegment
From OrderValue_CustomerView

SELECT OrderValSegment
, COUNT(*) AS CustomerCountInSegments
From OrderValCustomerSegmentView
GROUP BY 1
-- 14 customers are in the High-Value Category
-- 11 customers are in the Low-Value Category
-- 68 customers are in the Medium-Value Category

-------------- we may do the same geographic analysis on the customer segments by order-value -----------------------
SELECT country, COUNT(OrderValSegment) AS HighValueSegmentCount
FROM Customers
JOIN OrderValCustomerSegmentView osv
ON osv.customerid = customers.CustomerID
WHERE OrderValSegment = 'High-Value'
and country IS NOT NULL  -- Handling the nulls in country
GROUP BY 1 
ORDER BY 2 DESC
-- Germany has the most high-value customers i.e. 3 customers
-- then comes venzuela and brazil
-- USA who had a champion and 10 potential loyals had only 1 customer in the High-Value segment!!

SELECT country, COUNT(OrderValSegment) AS MediumValueSegmentCount
FROM Customers
JOIN OrderValCustomerSegmentView osv
ON osv.customerid = customers.CustomerID
WHERE OrderValSegment = 'Medium-Value'
and country IS NOT NULL  -- Handling the nulls in country
GROUP BY 1 
ORDER BY 2 DESC
-- USA plays well in the average class in our database 
-- Germany comes in the top 3 countries with Medium-Value Class
-- All countries that had appeared in the Champion segment are in the top 5 in the Medium-Value Segment

SELECT country, COUNT(OrderValSegment) AS LowValueSegmentCount
FROM Customers
JOIN OrderValCustomerSegmentView osv
ON osv.customerid = customers.CustomerID
WHERE OrderValSegment = 'Low-Value'
and country IS NOT NULL  -- Handling the nulls in country
GROUP BY 1 
ORDER BY 2 DESC
-- USA comes first with 3 customers in the LOW class

-- Actually I have a question: How many customers in each country in general?
SELECT country, COUNT(customerid) As Customers
FROM Customers
WHERE country is not NULL    -- Handling nulls
GROUP BY country
Order By 2 DESC
-- Makes sense that countries like USA, UK, Germany, France who has many customers participate strongly 
-- in all segments
-- Insight: Venzuela with only 4 customers had 2 of them in the High-Value Class -- !!INTERESTING!!


----------------------------------- Product Analysis Section ---------------------------------------------------------
-- How many product do my store have?
SELECT COUNT(productid) As productsCount
FROM Products
-- 77 products
-- How many product Categories?
SELECT count(categoryid) AS CategoriesCount
FROM Categories
-- 8 Categories
-- Top 10 products (revenue-wise)
SELECT productname
, ROUND(SUM(od.unitprice*quantity*(1-discount)), 2) As ProductRevenue
FROM Products p
JOIN "Order Details" od
ON p.ProductID = od.productID
GROUP BY 1
Order by 2 desc
LIMIT 10

-- In what categories are my top revenue-wise product?
SELECT DISTINCT categoryname
FROM Categories c
JOIN Products p
ON c.CategoryID = p.CategoryID
WHere productname IN ( SELECT productname
                      from (SELECT productname
					  , ROUND(SUM(od.unitprice*quantity*(1-discount)), 2) As ProductRevenue
					  FROM Products p
					  JOIN "Order Details" od
					  ON p.ProductID = od.productID
					  GROUP BY 1
                      ORDER BY 2 DESC
					  LIMIT 10 ))
-- Meat, Seafood, Confections, Produce, Beverages

-- Top 10 products (frequency ordered - wise)
SELECT productname
, SUM(quantity) As ProductFrequency
FROM Products p
JOIN "Order Details" od
ON p.ProductID = od.productID
GROUP BY 1
Order by 2 desc
LIMIT 10 

-- Another solution (counting the product id)-- 
SELECT productname
, COUNT(od.productid) As ProductFrequency
FROM Products p
JOIN "Order Details" od
ON p.ProductID = od.productID
GROUP BY 1
Order by 2 desc
LIMIT 10 
-----
SELECT DISTINCT categoryname
FROM Categories c
JOIN Products p
ON c.CategoryID = p.CategoryID
WHere productname IN ( SELECT productname
                      from (SELECT productname
					  , SUM(od.quantity) As ProductFreq
					  FROM Products p
					  JOIN "Order Details" od
					  ON p.ProductID = od.productID
					  GROUP BY 1
                      ORDER BY 2 DESC
					  LIMIT 10 ))
-- Produce, Confections, Beverages, Cereals, Dairy Products

-- Do the most frequent ordered products make the highest revenue??
SELECT productname
from ( SELECT produc*tname
    , ROUND(SUM(od.unitprice*quantity*(1-discount)), 2) As ProductRevenue
    FROM Products p
    JOIN "Order Details" od
    ON p.ProductID = od.productID
    GROUP BY 1
    Order by 2 desc
    LIMIT 10)
INTERSECT
SELECT productname
FROM ( SELECT productname
    , SUM(quantity) As ProductFrequency
    FROM Products p
    JOIN "Order Details" od
    ON p.ProductID = od.productID
    GROUP BY 1
    Order by 2 desc
    LIMIT 10)
-- output: Raclette Courdavault, Sir Rodney's Marmalade
-- from what category are these two peoducts (highest revenue, highest order frequency)?
SELECT productname, categoryname
from Categories c
join Products p
ON c.CategoryID = p.CategoryID
WHERE productname IN ('Raclette Courdavault', 'Sir Rodney''s Marmalade')
-- Sir Rodney's Marmalade: Confections
-- Raclette Courdavault: Dairy Products
-- What are the least 5 products with volume sales (Slow Movers)
SELECT productname
, SUM(quantity) As ProductFrequency
FROM Products p
JOIN "Order Details" od
ON p.ProductID = od.productID
GROUP BY 1
Order by 2 ASC
LIMIT 5 
-----------------------------------------------------------------------------------------------------------------------
----------------------------------- Order Analysis--------------------------------------------------------------------
-- How many orders are there?
SELECT count(orderid) AS Orders
from Orders
-- 16282
-- What's the distribution of these orders over years?
SELECT STRFTIME('%Y', DATE(orderdate)) AS "year"
, count(orderid) as OrdersCount
FROM Orders
GROUP BY 1
ORDER BY 2 DESC  
-- What's the distribution of these orders over months?
SELECT STRFTIME('%m', DATE(orderdate)) AS "month"
, count(orderid) as OrdersCount
FROM Orders
GROUP BY 1
ORDER BY 2 desc

-- What's the distribution of these orders over months of the yeas?
SELECT STRFTIME('%Y', DATE(orderdate)) AS "year"
, STRFTIME('%m', DATE(orderdate)) AS "month"
, count(orderid) as OrdersCount
FROM Orders
GROUP BY 1, 2
ORDER BY 1, 2 

-- Day-of-the-Week Analysis: Determine the most popular order days
SELECT STRFTIME('%w', DATE(orderdate)) AS DayNumber
, CASE STRFTIME('%w', DATE(orderdate))
WHEN '0' THEN 'Sunday'
WHEN '1' THEN 'Monday'
WHEN '2' THEN 'Tuesday'
WHEN '3' THEN 'Wednesday'
WHEN '4' THEN 'Thursday'
WHEN '5' THEN 'Friday'
WHEN '6' THEN 'Saturday'
ELSE 'NOT A DAY'         -- for a healthy case statment ")
END AS DayName
, count(orderid) as OrdersCount
FROM Orders
GROUP BY 1, 2
ORDER BY 3 DESC  -- From high days of orders to lowest days of orders
---------------
-- Let's now see the day of the week where most orders happened?
-- Monday is the winner with 2448 orders on Mondays
-- Thursday is the least day with orders on it.
-----------------------------------------------------------------------------------------------------------
-- Order Size distribution Analysis
SELECT orderid, SUM(quantity) AS OrderSize
FROM "Order Details"
GROUP by 1
order by 2 desc
LIMIT 5
---- I think of categorizing the order size into [small - Medium - Large] order size categories
-- Let's at first check the dipersion and mean of the order sizes
SELECT MIN(OrderSize), AVG(OrderSize), MAX(OrderSize)
FROM ( SELECT orderid, SUM(quantity) AS OrderSize
	   FROM "Order Details"
	   GROUP by 1
	   order by 2 desc )
-- min = 1      -- avg = 954.34       -- max = 2308        (Oops! Outliers)  
-- I think of categorizing them into [small - medium - large] and a category for the {very small} orders
       
SELECT *, 
CASE 
WHEN OrderSize BETWEEN 1 AND 50 THEN 'Very Small'
WHEN OrderSize BETWEEN 51 AND 500 THEN 'Small'
WHEN OrderSize BETWEEN 501 AND 1500 THEN 'Medium'
WHEN OrderSize > 1500 THEN 'Large'
ELSE 'Not Defined'
END AS OrderSizeCategory
FROM ( SELECT orderid, SUM(quantity) AS OrderSize
	   FROM "Order Details"
	   GROUP by 1
	   order by 2 desc )
---- Let's group by the OrderSize Category
SELECT CASE 
WHEN OrderSize BETWEEN 1 AND 50 THEN 'Very Small'
WHEN OrderSize BETWEEN 51 AND 500 THEN 'Small'
WHEN OrderSize BETWEEN 501 AND 1500 THEN 'Medium'
WHEN OrderSize > 1500 THEN 'Large'
ELSE 'Not Defined'
END AS OrderSizeCategory, 
COUNT(*) AS OrdersCount
FROM ( SELECT orderid, SUM(quantity) AS OrderSize
	   FROM "Order Details"
	   GROUP by 1
	   order by 2 desc )
GROUP by 1

-- Most of the orders made are of medium size
----------------------------------------------------------------------------------------------------------------------
-------------------------------------- Employee Performance Analysis --------------------------------------------------
-- At First; How many employees work for my company?
SELECT COUNT(employeeid) AS employeesCount
FROM Employees
-- we have 9 employees
-- Analysis of these employees performance by:
-- -- -- Revenue-achieved:
SELECT CONCAT(firstname, ' ', lastname) as EmployeeFullName
, ROUND(SUM(unitprice*quantity*(1-discount)), 2) AS RevenueAchieved
FROM Employees emp
JOIN Orders o
ON emp.EmployeeID = o.EmployeeID
JOIN "Order Details" od
ON o.OrderID = od.OrderID
GROUP BY 1
ORDER BY 2 DESC

-- Who is the employee with the highest revenue?
SELECT CONCAT(firstname, ' ', lastname) as GoldenEmployeeName
, ROUND(SUM(unitprice*quantity*(1-discount)), 2) AS RevenueAchieved
FROM Employees emp
JOIN Orders o
ON emp.EmployeeID = o.EmployeeID
JOIN "Order Details" od
ON o.OrderID = od.OrderID
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1
-- Margaret Peacock

-- -- -- by Number of orders processed:
SELECT CONCAT(firstname, ' ', lastname) as EmployeeName
, COUNT(orderid) AS OrdersProcessed
FROM Employees emp
JOIN Orders O
ON emp.EmployeeID = O.EmployeeID
GROUP by 1
ORDER BY 2 DESC
-- Margaret Peacock is also the GoldenEmployee with the most orders processed

-- -- -- by Average Order Value:
SELECT CONCAT(firstname, ' ', lastname) as GoldenEmployeeName
, ROUND(AVG(unitprice*quantity*(1-discount)), 2) AS AvgOrderValue
FROM Employees emp
JOIN Orders o
ON emp.EmployeeID = o.EmployeeID
JOIN "Order Details" od
ON o.OrderID = od.OrderID
GROUP BY 1
ORDER BY 2 DESC 
-- Michael Suyama made the highest order value average
-- Margaret Peacock who achieved the highest revenue and the most orders processed 
-- came the 5th in the average order value; that means he made many average sized orders (That makes sense)

------------ I think of categorizing my employees into [Gold, Silver, Bronze] employees ---------------------
--------------------------------- using the above performance metrics -------------------------------------------
WITH EmployeePerformance AS (
  SELECT 
    CONCAT(emp.FirstName, ' ', emp.LastName) AS EmployeeFullName,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS RevenueAchieved,
    COUNT(o.OrderID) AS OrdersProcessed,
    ROUND(AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS AvgOrderValue
  FROM Employees emp
  JOIN Orders o ON emp.EmployeeID = o.EmployeeID
  JOIN "Order Details" od ON o.OrderID = od.OrderID
  GROUP BY emp.EmployeeID
),
EmployeePerformanceRanked AS (
	SELECT 	EmployeeFullName, 
  			DENSE_RANK() OVER (ORDER BY RevenueAchieved DESC) AS RevenueAchievedRank,
  		 	DENSE_RANK() OVER (ORDER BY OrdersProcessed DESC) AS OrdersProcessedRank,
  			DENSE_RANK() OVER (ORDER BY AvgOrderValue DESC) AS AvgOrderValueRank
  	FROM EmployeePerformance
)
SELECT EmployeeFullName, 
CASE 
WHEN RevenueAchievedRank = 1 
	OR OrdersProcessedRank = 1
    or AvgOrderValueRank = 1
THEN 'Gold'
WHEN RevenueAchievedRank BETWEEN 2 AND 4
	or OrdersProcessedRank BETWEEN 2 AND 4
    or AvgOrderValueRank BETWEEN 2 AND 4
then 'Silver'
WHEN RevenueAchievedRank > 5 
	OR OrdersProcessedRank > 5
    or AvgOrderValueRank > 5
THEN 'Bronze'
ELSE 'Not Defined'
END AS EmployeeClass
FROM EmployeePerformanceRanked

-- 2 Gold, 5 silver, 2 Bronze



-- Another solution

WITH EmployeePerformance AS (
  SELECT 
    CONCAT(emp.FirstName, ' ', emp.LastName) AS EmployeeFullName,
    ROUND(SUM(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS RevenueAchieved,
    COUNT(o.OrderID) AS OrdersProcessed,
    ROUND(AVG(od.UnitPrice * od.Quantity * (1 - od.Discount)), 2) AS AvgOrderValue
  FROM Employees emp
  JOIN Orders o ON emp.EmployeeID = o.EmployeeID
  JOIN "Order Details" od ON o.OrderID = od.OrderID
  GROUP BY emp.EmployeeID
),
EmpPerformanceDescription AS (
  SELECT 
    MIN(RevenueAchieved) AS MIN_REV, AVG(RevenueAchieved) AS AVG_REV, MAX(RevenueAchieved) AS MAX_REV,
    MIN(OrdersProcessed) AS MIN_OP, AVG(OrdersProcessed) AS AVG_OP, MAX(OrdersProcessed) AS MAX_OP,
    MIN(AvgOrderValue) AS MIN_OV, AVG(AvgOrderValue) AS AVG_OV, MAX(AvgOrderValue) AS MAX_OV
  FROM EmployeePerformance
)
SELECT 
  ep.EmployeeFullName,
  CASE 
    WHEN ep.RevenueAchieved = (SELECT MAX_REV FROM EmpPerformanceDescription) 
         OR ep.OrdersProcessed = (SELECT MAX_OP FROM EmpPerformanceDescription) 
         OR ep.AvgOrderValue = (SELECT MAX_OV FROM EmpPerformanceDescription) 
    THEN 'Gold'
    WHEN ep.RevenueAchieved BETWEEN (SELECT AVG_REV FROM EmpPerformanceDescription) AND ((SELECT MAX_REV FROM EmpPerformanceDescription) - 1)
         OR ep.OrdersProcessed BETWEEN (SELECT AVG_OP FROM EmpPerformanceDescription) AND ((SELECT MAX_OP FROM EmpPerformanceDescription) - 1)
         OR ep.AvgOrderValue BETWEEN (SELECT AVG_OV FROM EmpPerformanceDescription) AND ((SELECT MAX_OV FROM EmpPerformanceDescription) - 1)
    THEN 'Silver'
    ELSE 'Bronze'
  END AS 'EmployeeClass'
FROM EmployeePerformance ep
ORDER BY EmployeeClass DESC

-- 2 Gold Employees, 4 Silver Employees, 3 Bronze Employees










