\set ECHO none
\set QUIET on

vacuum;

\c postgres

drop database if exists a1_marking_2024 with (force);

create database a1_marking_2024;

\c a1_marking_2024

BEGIN TRANSACTION;

-- we're running in a fresh copy of the DB so no need to drop anything individually

--- Create fresh versions of the tables ---
CREATE TABLE WORKS (
    isbn VARCHAR PRIMARY KEY, 
    cost INTEGER, 
    title VARCHAR);

CREATE TABLE ITEMS (
    item_id VARCHAR PRIMARY KEY, 
    isbn VARCHAR NOT NULL REFERENCES WORKS);

CREATE TABLE PATRONS (
    patron_id SERIAL PRIMARY KEY, 
    patron_name VARCHAR NOT NULL, 
    email_address VARCHAR, 
    dob DATE NOT NULL, 
    guardian INTEGER REFERENCES PATRONS);

CREATE TABLE EVENTS (
    event_id SERIAL PRIMARY KEY, 
    patron_id INTEGER NOT NULL REFERENCES PATRONS, 
    item_id VARCHAR NOT NULL REFERENCES ITEMS, 
    event_type VARCHAR NOT NULL, 
    time_stamp TIMESTAMP NOT NULL, 
    CHARGE INTEGER);

COMMIT;

--------------------
-- Database reset --
--------------------

-- We need a couple of inserts to start

insert into patrons (patron_name, email_address, dob) values 
    ('Charles III', 'charles.windsor@example.uk', '1948-11-14');

INSERT INTO WORKS (isbn,cost,title) VALUES 
    ('1000000000041',8393,'Mysterious Whisper'),
    ('1000000000082',6786,'Enchanted Shadow'),
    ('9000000000001',-314159,'Anomalous Mystery 1'),
    ('9000000000002',-314159,'Anomalous Mystery 2'),
    ('9000000000003',-314159,'Anomalous Mystery 3');

INSERT INTO ITEMS (item_id,isbn) VALUES
    ('UQ01000000001','1000000000041'),
    ('UQ01000000012','1000000000082');

-- from here: 
-- run student code
-- run test script