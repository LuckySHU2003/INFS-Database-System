CREATE DATABASE customer_db
WITH
	OWNER = Lucky
	LC_COLLATE = 'C'
	LC_CTYPE = 'C'
	TABLESPACE = pg_default
	CONNECTION LIMIT = -1;

\l customer_db