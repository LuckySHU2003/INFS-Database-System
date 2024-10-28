
\pset format wrapped 
\pset columns 77

\echo '================================ Practical 4 ================================'

\echo '1. Create views'
\echo '============================================================================='
/*
A view is a “virtual” table which is based on one or more tables or views. Data is stored in the
base table while the view contains no data itself.
Execute the following command to create a view named V_EMP_ACC:
*/
CREATE VIEW V_EMP_ACC AS
SELECT EMPNO, ENAME, DEPTNO
FROM EMP
WHERE DEPTNO = 30;
/*
This view shows all employees in the Accounting department (DEPTNO=30). After the view is
created, you can query data from the view:
*/
SELECT * FROM V_EMP_ACC;
/*
PostGreSQL supports updateable views but with limitations which you learn about in lectures. 
*/
INSERT INTO V_EMP_ACC (empno, ename, deptno) VALUES (3035, 'NICK COLES', 30);
UPDATE V_EMP_ACC SET ename = 'JAMES ADAM' WHERE empno = 3035;
/*
After executing the commands above, you should see the data being updated in the base table
EMP for those records in the view V_EMP_ACC.
*/
SELECT * FROM EMP WHERE DEPTNO = 30;
/*
For views that are not "updateable", you can use INSTEAD OF triggers to define custom 
behaviour when an INSERT, UPDATE or DELETE operation is performed on the view. 
*/
\echo 



\echo '2. Modify and drop views'
\echo '============================================================================='
/*
When redefining a view in PostGreSQL, you will first need to drop the original view if 
redefining changes the column structure of the view. 
*/
DROP VIEW IF EXISTS V_EMP_ACC;
CREATE VIEW V_EMP_ACC AS
SELECT COUNT(*) AS EMP_COUNT, AVG(SAL) AS AVG_SAL
FROM EMP
WHERE DEPTNO = 30;
/*
Note that after the modification, the view is no longer updatable. You will get error messages if
you attempt to insert or update data via this view. PostGreSQL uses a complicated set of rules that
restrict when a view is updateable, which basically requires that every update operation to be
translatable into an unambiguous change to the base tables. The use of aggregate functions in the
view V_EMP_ACC makes PostGreSQL unable to translate the changes to concrete changes in the base
tables.
*/
/*
To drop a view, use the DROP VIEW command:
*/
DROP VIEW V_EMP_ACC;

\echo 



\echo '3. Create materialised views'
\echo '============================================================================='
/*
A materialized view is a database object that contains the results of a query. One of the
advantages of a materialized view versus a regular view is that the aggregations of table data are
pre-calculated and stored in the view, hence the aggregations do not need to be calculated again
whenever the view is accessed. In this section, you will perform an experiment to compare the
performance of a materialized view and a regular view.
*/
/*
Download and run the script prep.sql 
*/
-- prac4=# \i prep.sql
/*
Note that the execution of the script may take a while due to a large number of data records
being populated to the tables. You should have 4 tables created in the database: EMP and DEPT,
and their copies EMP1 and DEPT1. The copies have exactly the same structure and data as their
original tables. In the following, you will create a regular view on EMP and DEPT, and a
materialized view on EMP1 and DEPT1.
*/
/*
Create a view called V_DEPT_SAL as follows:
*/
CREATE VIEW V_DEPT_SAL AS
SELECT DNAME, AVG(SAL) AS DSAL, MAX(SAL) AS DMAXSAL, MIN(SAL) AS DMINSAL
FROM EMP
JOIN DEPT ON EMP.DEPTNO = DEPT.DEPTNO
GROUP BY DNAME;
/*
The view you created above shows the average, the highest, and the lowest employee salary in
each department. Similarly, create a materialized view called MV_DEPT_SAL to show the same
information:
*/
-- materialised views are built immediately by default in PostGreSQL 
CREATE MATERIALIZED VIEW MV_DEPT_SAL AS
SELECT DNAME, AVG(SAL) AS DSAL, MAX(SAL) AS DMAXSAL, MIN(SAL) AS DMINSAL
FROM EMP1
JOIN DEPT1 ON EMP1.DEPTNO = DEPT1.DEPTNO
GROUP BY DNAME;
/*
Enable timing in psql: 
*/
\timing on
/*
Then query the two views and compare the execution time.
*/
SELECT * FROM V_DEPT_SAL;
\echo 
SELECT * FROM MV_DEPT_SAL;
\echo
/*
To have a better understanding of the execution difference between querying materialized 
views and querying regular views, we can use the PostGreSQL EXPLAIN ANALYZE function. 
An execution plan defines various steps performed during query execution (For example, 
the order in which tables are read, if indexes are used, which join methods are used to
join tables, etc.).
*/
EXPLAIN ANALYZE SELECT * FROM V_DEPT_SAL;
\echo
EXPLAIN ANALYZE SELECT * FROM MV_DEPT_SAL;
\echo
/*
These two queries provide the execution plan and actual run-time statistic (by executing the queries). 
*/
/*
As you can see from the first execution plan, queries on the regular view V_DEPT_SAL will
be translated into another query on the base tables, which is called query modification. 

In this example, a hash join uses a condition (emp.deptno = dept.deptno) to perform a 
join after sequential scans of both emp and dept. 

At the last step, hash aggregation is used to compute the average, maximum and minimum values. 
Rows are aggregated (for the GROUP BY operation) using a hash table; the GROUP BY key of each 
tuple is hashed and that tuple is grouped according to its hash value. 

Whereas, the second execution plan shows that no query modification took place, as the query 
was a simple sequential scan directly executed on MV_DEPT_SAL, showing an advantage of 
materialised views. 
*/
