
\pset format wrapped 
\pset columns 77

\echo '================================ Practical 1 ================================'
\! mget -O ~~/stor/data/practicals/1/sol.sql
\i ./sol.sql

\echo '================================ Practical 2 ================================'
/*
In this practical, you will learn how to define table constraints in PostGreSQL. You will 
see some example constraints defining for a table called DEPT. This table stores 
information about departments in a company. You can create this table using the following 
command:
*/
\echo '0. Create DEPT table'
\echo '============================================================================='
CREATE TABLE DEPT (
    DEPTNO INTEGER,
    DNAME VARCHAR(14),
    LOCATION VARCHAR(13)
);
/*
Now, you are going to add some constraints to this table.
*/
\echo



/* 1. Create primary key constraints */ 
\echo '1. Create primary key constraints'
\echo '============================================================================='
/*
The DEPTNO column is the primary key of the DEPT table. You need to execute the
following command to add a PRIMARY KEY constraint on this column. The constraint is
named as PK_DEPTNO. By giving the constraint a name, you can later refer to it by its name
to modify or remove it.
*/
ALTER TABLE DEPT ADD CONSTRAINT PK_DEPTNO PRIMARY KEY (DEPTNO); 
\echo



/* 2. Create CHECK constraints */ 
\echo '2. Create CHECK constraints'
\echo '============================================================================='
/*
A CHECK constraint specifies requirements for the values of a column. The command below
defines a CHECK constraint to restrict a DEPTNO value to be a 2-digit number. 
*/
ALTER TABLE DEPT ADD CONSTRAINT CHK_DEPTNO
    CHECK ((DEPTNO > 9) AND (DEPTNO < 100));
\echo



/* 3. Create UNIQUE constraints */ 
\echo '3. Create UNIQUE constraints'
\echo '============================================================================='
/*
A column can be specified to be unique. In the DEPT table, you will define a UNIQUE
constraint on the column DNAME. That means it is impossible to have two departments with
the same name.
*/
ALTER TABLE DEPT ADD CONSTRAINT UN_DNAME UNIQUE (DNAME);
\echo



/* 4. Create NOT NULL constraints */ 
\echo '4. Create NOT NULL constraints'
\echo '============================================================================='
/*
A column can also be specified as NOT NULL. However, a NOT NULL constraint is not a
table level constraint but a column level constraint. Therefore, you cannot use the ALTER
TABLE ADD CONSTRAINT like sections 1-3. Below is the command to define a NOT
NULL constraint on the table DEPT.
*/
ALTER TABLE DEPT ALTER COLUMN LOCATION SET NOT NULL;
\echo



/* 5. Drop constraints */ 
\echo '5. Drop constraints'
\echo '============================================================================='
/*
The following example shows you how to drop a constraint. UN_DNAME is the name of the
constraint to be dropped.
*/
ALTER TABLE DEPT DROP CONSTRAINT UN_DNAME;
\echo



/* 6. View constraint description */ 
\echo '6. View constraint description'
\echo '============================================================================='
/*
PostGreSQL stores information about table constraints in system catalogs, namely pg_constraint 
and information_schema.table_constraints. To view table constraint descriptions, you will 
need to write queries to extract this information from the system catalogs. The following 
is a query which will get the named constraints of the table DEPT. 
*/
/*
The following query only gets named constraints; the column-level NOT NULL constraint 
of task 3 is not a named constraint and so will not show up (but it still exists). 
PostGreSQL does not provide a direct way to name column properties/constraints. The 
constraints still exist, there is just no name associated with them when you query 
information_schema.table_constraints.

pg_constraint is PostgreSQL-specific and provides more detailed, internal information about 
constraints. information_schema.table_constraints is part of the SQL standard and provides 
a more generalized view of constraints.
*/
SELECT 
    tc.constraint_name, 
    tc.table_name, 
    tc.constraint_type, 
    pg_get_constraintdef(pc.oid) AS search_condition
FROM 
    information_schema.table_constraints AS tc
JOIN 
    pg_constraint AS pc ON tc.constraint_name = pc.conname
WHERE 
    tc.table_name = 'dept' AND tc.constraint_schema = 'public';



/* 7. Insert data records to DEPT table */ 
\echo '7. Insert data records to DEPT table'
\echo '============================================================================='
/*
Use the INSERT command to insert the following departments to the DEPT table. If you don’t
remember this command, refer to Practical 1.

Note: Make sure you still have the UN_DNAME constraint. If you don’t have it, use the
following command to add it back:
*/
ALTER TABLE DEPT ADD CONSTRAINT UN_DNAME UNIQUE (DNAME);
/*
DEPTNO  DNAME       LOCATION
10      Accounting  Brisbane
20      Marketing   Sydney
30      Engineering Gold Coast
20      Management  Brisbane
9       Finance     Melbourne
70      Marketing   Brisbane
*/
INSERT INTO DEPT VALUES (10, 'Accounting', 'Brisbane'); 
INSERT INTO DEPT VALUES (20, 'Marketing', 'Sydney'); 
INSERT INTO DEPT VALUES (30, 'Engineering', 'Gold Coast');
INSERT INTO DEPT VALUES (20, 'Management', 'Brisbane');
INSERT INTO DEPT VALUES (9, 'Finance', 'Melbourne');
INSERT INTO DEPT VALUES (70, 'Marketing', 'Brisbane');
/*
You will notice that only the first three departments are inserted successfully. The last three
departments cannot be inserted because they violate the constraints. Check the error messages
to see which constraints they violate.
*/
\echo



/* 8. Create constraints for the EMP table */
\echo '8. Create constraints for the EMP table'
\echo '============================================================================='
/*
Recall that in Practical 1 you created a table called EMP. This table already had a PRIMARY
KEY constraint on the column EMPNO. However, this constraint was defined in a CREATE
TABLE command, which was another way to define constraints. Please use the ALTER
TABLE ADD CONSTRAINT commands showed in Sections 1-4 to define the following
constraints for the table EMP.

Column name |     Type      |       Constraints
------------+---------------+-------------------------
EMPNO       | INTEGER       | 
ENAME       | VARCHAR(20)   | UNIQUE
JOB         | VARCHAR(20)   | NOT NULL
MGR         | INTEGER       | 
HIREDATE    | VARCHAR(20)   | Must be after 2000-01-01
SAL         | NUMERIC(7,2)  | 
DEPTNO      | NUMERIC(7,2)  | 
*/
ALTER TABLE EMP ADD CONSTRAINT UN_ENAME UNIQUE (ENAME);
ALTER TABLE EMP ALTER COLUMN JOB SET NOT NULL;
ALTER TABLE EMP ADD CONSTRAINT CHK_HIREDATE CHECK (HIREDATE > '2000-01-01');
\echo



/* 9. Create foreign key constraints */ 
\echo '9. Create foreign key constraints'
\echo '============================================================================='
/*
Now, you are going to define a foreign key constraint named FK_DEPTNO on the DEPTNO
column of the table EMP to make sure that values of this column appear in the DEPTNO
column of the table DEPT. The following command creates this constraint.
*/
ALTER TABLE EMP ADD CONSTRAINT FK_DEPTNO
    FOREIGN KEY (DEPTNO) REFERENCES DEPT (DEPTNO);
/*
After creating FK_DEPTNO, whenever you insert a record to the EMP table, PostGreSQL will
check if the record violates the constraint. The command below inserts a new employee whose
department number is 40. It fails because there is no department with DEPTNO=40 in the
DEPT table.
*/
INSERT INTO EMP VALUES (1006, 'David Randstad', 'ARCHITECT', NULL, '2009-05-14', 80000, 40);
\echo



/* 10. Do It Yourself */
\echo '10. Do It Yourself'
\echo '============================================================================='
/*
Please state any possible data integrity problem when deleting the department
ENGINEERING from the DEPT table. Modify the existing constraints to solve the
problem. (Hint: You need to modify the FK_DEPTNO constraint to use the ON DELETE
CASCADE option. Use internet search engines to learn how to add this option.)
*/
ALTER TABLE EMP DROP CONSTRAINT FK_DEPTNO; -- drop first to re-add with ON DELETE CASCADE 
ALTER TABLE EMP ADD CONSTRAINT FK_DEPTNO
FOREIGN KEY (DEPTNO) REFERENCES DEPT (DEPTNO)
ON DELETE CASCADE;
/*
Is it possible to restrict employee salary not to exceed his/her manager’s salary using the
constraint types you learned in this practical? If yes, how? 
*/
CREATE OR REPLACE FUNCTION salary()
RETURNS TRIGGER AS $$
BEGIN 
    IF NEW.SAL > (SELECT SAL FROM EMP WHERE EMPNO = NEW.MGR) THEN
        RAISE EXCEPTION 'Employee salary cannot exceed manager''s salary';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql; 

CREATE TRIGGER check_salary 
BEFORE INSERT OR UPDATE OF SAL ON EMP 
FOR EACH ROW EXECUTE FUNCTION salary(); 

INSERT INTO DEPT(DEPTNO, DNAME, LOCATION) VALUES (99,'Training','Brisbane');
INSERT INTO EMP VALUES (1006, 'Xue Li', 'Coordinator', NULL, '2010-12-17', 90000, 99);
INSERT INTO EMP VALUES (1007, 'Alex Jago', 'Supertutor', 1006, '2020-06-28', 80000, 99);
INSERT INTO EMP VALUES (1008, 'Nick Chang', 'Tutor', 1007, '2024-06-28', 75000, 99);
INSERT INTO EMP VALUES (1009, 'Allan Chuang', 'Tutor', 1007, '2023-06-28', 85000, 99);

\echo


\set QUIET on
\! rm sol.sql 
\set QUIET off 
