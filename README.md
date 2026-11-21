Project Explanation: Sales and Warranty Analytics 
Nov 19, 2026 · @Mohit
I built an end-to-end analytics project for a battery manufacturer with Python, SQL Server and Power BI to answer three business questions: where revenue is weak, why deliveries are late, and which production batches cause warranty claims. The data is simulated, and this guide explains every step with the numbers to quote.
Project at a glance
Item	Detail
Business	Battery manufacturer (Exide-type scenario), 120 dealers, 4 regions, 24 products
Data	Simulated, Jan 2022 to Dec 2025: 62,980 sales orders, 8,530 warranty claims after cleaning
Tools	Python (Pandas, NumPy, Matplotlib, Seaborn), SQL Server (SSMS), Power BI (DAX, Power Query)
Output	Requirement document, cleaned data, 9 SQL queries and 2 views, 3-page dashboard with drill-through and row-level security
Headline numbers	Revenue Rs 567.91 Cr, gross profit 28.2%, on-time delivery 80.1%, warranty claim rate 1.54%
1. Business problem and requirements
Sales, delivery and warranty data sat in separate files, so managers had no single view. I wrote a requirement document first, because every query and visual should answer a stakeholder question.
Stakeholder	Question	Where it is answered
Sales Head	Which regions, dealers and categories under-perform?	Dashboard page 1, SQL queries 1, 2, 3, 8, 9
Supply Chain Head	Why do customers complain about late delivery?	Dashboard page 2, SQL query 4
Quality Head	Where do warranty claims come from?	Dashboard page 2, SQL queries 5, 6, 7
The document also holds KPI formulas, assumptions and acceptance criteria (totals must match between Python and SQL, and no orphan records).
2. Data used
Table	Type	Rows (clean)	One row is
fact_sales	Fact	62,980	one order
fact_warranty	Fact	8,530	one claim
dim_dealer	Dimension	120	one dealer
dim_product	Dimension	24	one product
A batch ID is plant code plus production month, for example TLJ-2405 means Taloja plant, May 2024.
3. Python: profiling and cleaning
I profiled the raw files first, then fixed each problem and logged every rule as an assumption.
Problem found	Count	Fix	Why
Duplicate sales rows	947	Dropped	Duplicates double-count revenue
Mixed date formats (DD-MM-YYYY text)	1,947	Parsed both formats into one date type	Date functions need real dates
Zero quantity	170	Dropped	Not a real order
Negative quantity	347 (344 after de-duplication)	Converted to positive	Treated as a typing error (assumption)
Blank discount	1,288	Filled with the median discount of the same dealer type	Filling with 0 would inflate revenue
Blank delivery days	595	Filled with promised days	Assumed delivered on time (assumption)
Dealer region in mixed case and spaces	10 values instead of 4	Trimmed and title-cased	One value per region
State spelling (MH, Maharastra)	Several	Mapped to Maharashtra	Consistent grouping
Warranty duplicates	43	Dropped	Same as sales
Warranty reason spelling	27 values instead of 10	Standardised (9 reasons plus Unknown)	Clean claim-reason analysis
Claims dated before 2022 or without a valid order	Removed	Dropped	Impossible records
Result: sales 64,097 to 62,980 rows and warranty 8,619 to 8,530 rows. I then created Revenue (quantity x price x (1 - discount)), COGS, GrossProfit and IsOnTime columns, and saved clean files separate from the raw files so the originals stay untouched.
4. Python: exploratory analysis
I used pandas (groupby, pivot_table, merge), NumPy (np.where, np.select, np.percentile) and seaborn and matplotlib (7 charts).
Analysis	Result
Revenue by region	South 217.39, North 164.37, West 145.53, East 40.62 (Rs Cr)
Growth 2022 to 2025 (CAGR)	South 21.3%, North 15.9%, West 15.1%, East 1.4%
Outliers (IQR method)	10.5% of orders bring 51.2% of revenue (bulk and OEM orders)
Claim rate by category	Inverter 2.07%, Two-Wheeler 1.71%, Automotive 1.35%, Solar 0.83%, Industrial 0.70%
Bad-batch scan	Compared each batch with its product's normal rate, flagged batches above 2.5x
Seasonality heatmap	Inverter peaks in April and May, Two-Wheeler in October
5. SQL Server
Setup. I created the ExideDB database and imported the four clean files. The import wizard guessed wrong types, so I verified every column after loading (see the problems section). I then added 4 primary keys and 5 foreign keys.
Checks before analysis. SQL totals matched Python: 62,980 orders, Rs 567.91 Cr revenue, 28.2% gross profit and 80.1% on-time delivery. Orphan checks returned 0 (every order has a valid dealer and product, every claim has a valid order). The 138 blank resolution dates are pending claims, which is expected.
Nine business queries.
#	Question	SQL used	Finding
1	Revenue by region	JOIN, GROUP BY	South 38.3% of revenue, East only 7.2%
2	Revenue by year and region	YEAR, two-column GROUP BY	East 9.64, 10.66, 10.30, 10.01 Cr: flat
3	Top 5 dealers	TOP, ORDER BY	Top 5 bring 25.4%; Patna dealer is 4th
4	On-time delivery by region	CASE	East 64.3%, North 75.5%, South 84.3%, West 84.4%
5	Claim rate by category	CTE (sales and claims totals combined)	Inverter 2.07%, three times Industrial
6	Claim reasons	GROUP BY	Manufacturing Defect and Cell Short Circuit cost Rs 152 lakh, 39% of warranty cost
7	Bad batches	CTE, HAVING, LEFT JOIN, ISNULL	8 Taloja batches (Feb to May 2024) with 12.7% to 15.1% claim rate
8	Top 3 dealers per region	CTE and RANK with PARTITION BY	Patna dealer is 57% of East revenue
9	Dealers above average	CTE and subquery	37 of 120 dealers bring 83.9%; only 2 of 18 East dealers
I used a CTE only where it made the query clearer: combining two tables' totals, ranking before filtering, and comparing with an average. I also created two views (sales report and warranty report) as reusable reporting queries.
6. Power BI
Load and model. Import mode from SQL Server. I removed the navigation columns that the connector adds and fixed a cyclic-reference error by keeping each query tied only to its SQL source. The model has 3 dimensions (dealer, product, date) and 2 fact tables (sales, warranty) joined by 6 one-to-many, single-direction relationships. I created the date table in DAX, marked it as a date table and sorted months by month number.
DAX (25+ measures in a separate measures table). Revenue, gross profit %, on-time %, claim rate %, revenue last year with SAMEPERIODLASTYEAR, YoY % protected with HASONEVALUE, batch claim rate with TREATAS, and colour measures that drive red, amber and green formatting.
Three pages, one per stakeholder.
Page	Audience	Contents
1. Sales Performance Overview	Sales Head	KPI cards, slicers, revenue by region (East in red), regional trend, top 5 dealers, category split, key insights
2. Delivery and Warranty	Supply Chain and Quality Heads	On-time by region against an 85% target line, claim rate by category, claim reasons, bad-batch table, key insights
3. Dealer Detail	Sales Head	Drill-through from any dealer: KPIs, revenue trend, category mix and dynamic insight text
Dynamic insights. On page 3, DAX measures compare the selected dealer with the company average. For the Patna dealer the page shows a risk flag (57.4% of East revenue), growth of 15.1% against 58.7% for the company, delivery 15.8 points below average and margin 6.2 points below.
Design rules. One theme, business-question titles, red only for problems, neutral grey elsewhere, consistent number formats and aligned visuals.
Row-level security. Four static roles (North, South, East, West Manager) filter the dealer table by region, and the filter flows to both fact tables. I tested each role with View as; the East Manager sees Rs 40.62 Cr and 6,544 orders.
Refresh. Import mode copies the data, so the report updates on refresh. For company SQL Servers the Service needs a gateway and a scheduled refresh. Run this demo once before interviews: add one test order in SQL, refresh Power BI and see orders go from 62,980 to 62,981, then delete the test order.
7. Findings and recommended actions
Finding	Evidence	Action
East revenue is flat while other regions grow	Rs 9.6 Cr to Rs 10.0 Cr in four years, CAGR 1.4% against 15% to 21%	Add and activate dealers in East
East depends on one dealer	Patna dealer is 57% of East revenue; only 2 of 18 East dealers are above average	Build backup dealers and review the contract
East delivers late	64.3% on time against 84% in South and West; matching West avoids about 1,300 late orders	Review East logistics and warehouse
Inverter has the highest claim rate	2.07%, three times Industrial	Review inverter quality process
Eight Taloja batches are abnormal	Inva Master 150Ah and 200Ah, Feb to May 2024, 12.7% to 15.1% claim rate against about 1.5% normal (about 9 times); Rs 66.4 lakh, 17% of warranty cost, from 0.6% of units sold	Investigate the Taloja process and replace units proactively
8. Problems I faced and how I solved them
Problem	Cause	Fix
IDs became numbers like 1.00 after import	Wizard guessed the money type for text IDs	Dropped the tables, re-imported with text types, and now verify types after every import
Import failed on a blank value	Wizard reads the first rows only; pending claims with blank dates come at the end of the file	Allowed NULLs for the resolution days column
Extra columns in Power BI tables	Connector adds navigation columns from foreign keys	Removed them in Power Query
Cyclic reference error	A query depended on another query	Rebuilt each query from the SQL source only
Slicers and measures behaved wrongly	Warranty was linked to sales, creating two filter paths	Deleted the fact-to-fact link and joined both facts to the dimensions
YoY showed 0.45 with all years selected	Measure compared a whole range with a shifted range	Used HASONEVALUE so it shows only when one year is selected
Batch claim rate showed 0.01%	Batch is not in any dimension, so units sold were not filtered	Used TREATAS to apply the batch filter to both sides
Bad batches looked like 5x normal	The baseline included the bad batches themselves	Used the same products' other batches (1.49%), which gives about 9x
Rule-based colours did not apply	Rule setup is easy to get wrong	Put colours in DAX measures and used field-value formatting
9. Assumptions and limitations
•	The data is simulated. Say this at the start of every explanation.
•	Cleaning assumptions: negative quantity is a typing error, blank delivery days mean on time, blank discount is the dealer-type median.
•	Targets (85% on time, 8% batch threshold) are assumptions that the business would confirm.
•	Recent batches show fewer claims because customers have had little time to claim.
•	RLS roles are static, and the batch table ignores year slicers on purpose.
•	Not done: forecasting, live refresh with a gateway, dynamic RLS.
10. How to explain it
30 seconds. I built an end-to-end analytics project for a battery manufacturer using simulated data. I cleaned about 70 thousand records in Python, loaded them into SQL Server, wrote nine business queries and built a three-page Power BI dashboard with drill-through and region-level security. It showed East revenue is flat, one dealer brings 57% of East revenue, East delivers late, and eight Taloja batches have about nine times the normal warranty claims.
2 minutes. Start with the problem: managers had sales, delivery and warranty data in separate files. I wrote a requirement document with three stakeholder questions and KPI definitions. In Python I profiled and cleaned the data, for example 947 duplicates, mixed date formats and blank discounts, and I documented each assumption. In SQL Server I added keys, checked that totals matched Python (Rs 567.91 Cr, 62,980 orders) and answered the questions with nine queries. In Power BI I built a star-schema model, 25+ DAX measures and three pages, one per stakeholder. The findings were East revenue flat, one dealer as 57% of East, East on-time delivery 64% against 84%, and eight Taloja batches at 13% to 15% claim rate against about 1.5%. I recommended adding East dealers and investigating the Taloja process.
5 minutes. Use the 2-minute version, then add one detail from each phase: the reconciliation between Python and SQL, one CTE query (bad batches), the TREATAS fix for batch claim rate, row-level security with View as, and one problem you solved (the wrong ID types after import). Close with what you would do next: forecasting seasonal demand, scheduled refresh with a gateway, and alerts for batch claim spikes.
11. Interview questions and answers
Question	Answer
Is this real data?	No, it is simulated, built like a battery manufacturer's data. I followed the same workflow I use at work: requirement, data check, validation, dashboard.
Why a star schema?	Dimensions on top, facts below, one-to-many single-direction relationships. Filters flow cleanly and DAX stays simple. I have two facts sharing dealer, product and date.
Why not link warranty to sales?	It created two filter paths and made relationships inactive. Both facts connect to the dimensions instead.
Measure or calculated column?	A measure calculates at query time for the current filter and suits aggregations. A calculated column is stored for every row.
What does CALCULATE do?	It changes the filter context, for example SAMEPERIODLASTYEAR shifts the date filter by one year.
Where did you use a CTE?	When I had to combine totals from two tables, rank before filtering, or compare with an average. Simple queries stayed plain.
RANK, DENSE_RANK, ROW_NUMBER?	On ties, RANK skips numbers (1, 1, 3), DENSE_RANK does not (1, 1, 2), ROW_NUMBER gives unique numbers.
WHERE or HAVING?	WHERE filters rows before grouping, HAVING filters groups after aggregation.
How did you find bad batches?	Batch claim rate against the product's normal rate, only batches with 300+ units, flagged above 8% in SQL. Python used 2.5 times the product rate.
How did you validate numbers?	Compared SQL, Python and Power BI totals (567.91 Cr, 62,980, 28.2%, 80.1%) and ran orphan checks.
What is RLS?	A role filters rows by user. Mine filter the dealer table by region, and the filter reaches both fact tables. Workspace Admin, Member and Contributor bypass it.
Static or dynamic RLS?	Mine is static, with the region typed in each role. Dynamic uses USERPRINCIPALNAME and a user-region table.
Import or DirectQuery?	Import copies data into Power BI, which is fast but needs refresh. DirectQuery queries the source live but is slower.
Did you use AI?	Yes, for drafts, debugging and learning. I ran every query myself, tallied the numbers across tools and can explain each step.
What would you do next?	Seasonal forecasting, gateway with scheduled refresh, dynamic RLS and alerts when a batch claim rate spikes.
12. Numbers to remember
Metric	Value
Sales orders, warranty claims	62,980 and 8,530
Revenue, gross profit, on-time	Rs 567.91 Cr, 28.2%, 80.1%
Warranty claim rate, approved cost	1.54%, Rs 3.89 Cr (0.69% of revenue)
East revenue 2022 to 2025	Rs 9.64 Cr to Rs 10.01 Cr
Patna dealer share of East	57.4%
On-time: East against South and West	64.3% against about 84%
Inverter claim rate	2.07%
Bad batches	8 Taloja batches, 12.7% to 15.1%, Rs 66.4 lakh (17% of warranty cost)
Duplicates removed	947 sales, 43 warranty

