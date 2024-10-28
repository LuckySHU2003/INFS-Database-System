
\pset format wrapped 
\pset columns 77

\echo '================================ Practical 2 ================================'
\! mget -O ~~/stor/data/practicals/2/sol-2.sql
\i ./sol-2.sql



\echo '================================ Practical 3 ================================'
\echo 'Dropping trigger from DIY practical 2'
drop trigger if exists check_salary on emp; 
/*

*/



\echo '1. Create your own script to define sequences and triggers'
\echo '============================================================================='
/*
Now, open a new text file in NotePad to create your own script.

Assume that you want the values of the EMPNO column to be automatically populated. You
need to create a SEQUENCE object to generate values for this column. A sequence is an object
in Oracle that is used to generate a number sequence. In NotePad, type the following command:
*/
CREATE SEQUENCE EMPNO_SEQ
  MINVALUE 1000
  MAXVALUE 9999
  INCREMENT BY 1
  START WITH 1000;

/*
An Oracle trigger is a block of code to be executed in response to certain events on a particular
table, schema, or database. To bind the sequence object EMPNO_SEQ to the EMPNO column, you need 
to define a TRIGGER which populates values of EMPNO_SEQ to the EMPNO column. The trigger should 
be fired before a row is inserted into the EMP table. Add the command below to your script to 
define this trigger:
*/
-- create a function that is invoked by the trigger 
CREATE OR REPLACE FUNCTION generate_empno()
RETURNS TRIGGER AS $$
BEGIN
  NEW.EMPNO := nextval('EMPNO_SEQ');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- trigger uses the function generate_empno
CREATE TRIGGER BI_EMP
BEFORE INSERT ON EMP
FOR EACH ROW
EXECUTE FUNCTION generate_empno();

/*
Similarly, type the following commands in your script to populate values for the DEPTNO
column in the DEPT table. Note that the value of DEPTNO_SEQ is increased by 10 every time it
is accessed.
*/
CREATE SEQUENCE DEPTNO_SEQ
  MINVALUE 50
  MAXVALUE 99
  INCREMENT BY 10
  START WITH 50;

-- create a function that is invoked by the trigger 
CREATE OR REPLACE FUNCTION set_deptno()
RETURNS TRIGGER AS $$
BEGIN
  NEW.DEPTNO := nextval('DEPTNO_SEQ');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- trigger uses the function set_deptno
CREATE TRIGGER BI_DEPT
BEFORE INSERT ON DEPT
FOR EACH ROW
EXECUTE FUNCTION set_deptno();

/*
Type the following INSERT command in your script to insert the Accounting department to the
DEPT table.
*/
-- Test it out! 
INSERT INTO DEPT(DNAME, LOCATION) VALUES ('Training','Brisbane');
/*
In this command, you can see that DEPTNO is not specified. That is because the value of
DEPTNO will be populated automatically by the trigger BI_DEPT. Similarly, insert the
following departments and employees to DEPT and EMP tables to verify the effect of the
triggers.
*/
/*
DNAME       LOCATION
Accounting  Brisbane
Marketing   Sydney
Engineering Gold Coast
*/
/*
ENAME           JOB         MGR   HIREDATE    SAL   DEPTNO
John Clay       Accountant        2010-12-17  75000 10
Paul Hayes      Engineer          2006-07-20  85000 30
Nikki Jolie     Accountant  1001  2011-02-10  55000 10
James Stephens  Accountant  1001  2011-05-10  60000 10
Clara Jonathan  Engineer    1002  2011-02-13  60000 30
*/
\echo 



\echo '2. View sequences and triggers'
\echo '============================================================================='
/*
To view information about sequences, use the following command:
*/
-- for sequences, query the standardised information_schema.sequence 
SELECT 
    sequence_schema AS schema_name,
    sequence_name,
    start_value,
    minimum_value AS min_value,
    maximum_value AS max_value,
    cycle_option AS cycle -- whether sequence cycles after reaching max value 
FROM information_schema.sequences
ORDER BY schema_name, sequence_name;

/*
To view information about triggers, use the following commands:
*/
-- For triggers, must use system catalogue pg_trigger.
-- It is possible to get more information about triggers, such as when they're fired 
-- and on what events (e.g. BEFORE INSERT). However, this would be a far more complicated 
-- query which involves breaking down an 8-bit sequence (pg_trigger.tgtype).
-- In general, there is always lots of information in system catalogues if you wanted to 
-- do some digging; pg_class, pg_proc, pg_namespace etc. 
SELECT
    t.tgname AS trigger_name,
    c.relname AS table_name
FROM
    pg_trigger t
JOIN
    pg_class c ON t.tgrelid = c.oid
WHERE
    NOT t.tgisinternal; -- we don't want internal (system) triggers 



\echo '3. Drop sequences and triggers'
\echo '============================================================================='
/*
To remove sequences and triggers, use the DROP SEQUENCE IF EXISTS and DROP TRIGGER 
IF EXISTS commands.
*/
DROP SEQUENCE IF EXISTS EMPNO_SEQ;
DROP TRIGGER IF EXISTS BI_EMP ON EMP;

DROP SEQUENCE IF EXISTS DEPTNO_SEQ;
DROP TRIGGER IF EXISTS BI_DEPT ON DEPT;
\echo 



\echo '4. Do It Yourself'
\echo '============================================================================='
/*
a. Write a script to perform the following tasks:
    i. Remove all data records from table EMP.
    ii. Change the data type of the EMPNO column in the EMP table from Number to Varchar(10).
    iii. Create a trigger to generate values for this column in the following format: DeptInit_DeptEmpSeq. 
        DeptInit is extracted from the first 3 characters of the department name. 
        DeptEmpSeq is the sequence number of the employee in the department. 
        For example, assuming Jay and Bill are the 1st and the 5th employee in the ENGINEERING department, 
        their EMPNO values would be ENG_1 and ENG_5.
        Hint: You will need to use built-in functions for string manipulation e.g. LEFT, 
        QUOTE_LITERAL
*/
/* i. */
DELETE FROM EMP;

/* ii. */ 
ALTER TABLE EMP
ALTER COLUMN EMPNO TYPE VARCHAR(10); 

/* iii. */
-- first need a sequence (for each department) to generate employee numbers 
DO $$
DECLARE
    dept RECORD;
BEGIN
    FOR dept IN SELECT DISTINCT DNAME FROM DEPT LOOP
        EXECUTE 'CREATE SEQUENCE IF NOT EXISTS ' || left(dept.dname, 3) || '_emp_seq';
    END LOOP;
END $$;

-- the function invoked by the trigger 
CREATE OR REPLACE FUNCTION set_empno()
RETURNS TRIGGER AS $$
DECLARE
    dept_initial VARCHAR(3);
    dept_emp_seq INTEGER;
BEGIN
    -- first 3 characters of the department name
    SELECT LEFT(d.dname, 3) INTO dept_initial
    FROM DEPT d
    WHERE d.deptno = NEW.deptno;
    -- next sequence number for the department
    EXECUTE 'SELECT nextval(' || quote_literal(dept_initial || '_emp_seq') || ')' INTO dept_emp_seq;
    -- set new EMPNO value
    NEW.empno := dept_initial || '_' || dept_emp_seq;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- create trigger 
CREATE TRIGGER BI_EMP
BEFORE INSERT ON EMP
FOR EACH ROW
EXECUTE FUNCTION set_empno();

-- Test it out! 
ALTER TABLE EMP
ALTER COLUMN MGR TYPE VARCHAR(10);
-- requires knowing that Training department will have deptno of 50 and that format will be 'Tra_x' 
-- Future extension idea: using 1,2... (in place of mgr) create 'Tra_x' 
-- Note: must be 1,2... and not unique ID (since unique empno's won't be saved so no way to track)
INSERT INTO EMP(ENAME, JOB, MGR, HIREDATE, SAL, DEPTNO) VALUES 
  ('Xue Li', 'Coordinator', NULL, '2010-12-17', 90000, 50),
  ('Alex Jago', 'Supertutor', 'Tra_1', '2020-06-28', 80000, 50),
  ('Nick Chang', 'Tutor', 'Tra_2', '2024-06-28', 75000, 50);

\echo 


/*
b. Triggers are usually used to enforce database constraints. Use triggers to implement the
constraint on employee salary as described in the Do It Yourself section of Practical 2.
*/
-- refer to sol-2.sql
CREATE TRIGGER check_salary 
BEFORE INSERT OR UPDATE OF SAL ON EMP 
FOR EACH ROW EXECUTE FUNCTION salary(); 

INSERT INTO EMP VALUES ('4', 'Allan Chuang', 'Tutor', 'Tra_2', '2023-06-28', 85000, 50);

\echo 


\set QUIET on
\! rm sol-2.sql 
\set QUIET off 

