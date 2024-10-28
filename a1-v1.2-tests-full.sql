-----------------------------------------------------
----- RELEASED TO STUDENTS --------------------------
----- FOR PERUSAL AND CHECKING ----------------------
-----------------------------------------------------

-- INFS2200 2024 Sem. 2
-- Marking script for Assignment 1
-- Current for assignment version: v1.2

-- BEFORE running this file:
-- 1. run reset-a1.sql
-- 2. run submission script (4xxxxxxx.sql)

-- This file's edition: 2024-09-09 (minor modifications for release 2024-10-02)

\set q3score :q3score
\echo Question 3.3 output should be above and in the PDF.
\echo You need to check the code:
\echo 0.5 marks for not hardcoding sequence names 
\echo 0.5 marks for displaying the sequence details
\prompt 'Please score Q3.3 ([0], 0.5, 1). ' q3score

SELECT CASE
  WHEN :'q3score'= ''
  THEN '0'
  ELSE :'q3score'
END AS "q3score"  \gset

SELECT trigger_name as "MISNAMED TRIGGERS (if any)", event_object_table as "Table"
	from information_schema.triggers 
    where lower(event_object_table) in ('events', 'items', 'patrons', 'works')
    and lower(trigger_name) not in ('ai_missing_return', 'bi_holds', 'bi_loss_charge', 
        'bi_item_id', 'bi_email_addr', 'bi_guardian');

with t_names as (select * from (values 
    ('ai_missing_return'), ('bi_holds'), ('bi_loss_charge'), 
        ('bi_item_id'), ('bi_email_addr'), ('bi_guardian')) as t (t_name))
SELECT t_name as "MISSING TRIGGERS (if any)"
	from t_names left join information_schema.triggers 
    on (t_name = lower(trigger_name))
    where trigger_name is null;

-- We can also test for any missing/misnamed functions
with f_names as (select * from (values 
    ('udf_bi_guardian'), ('udf_bi_email_addr'), ('udf_bi_item_id'), 
    ('udf_bi_loss_charge'), ('udf_ai_missing_return'), ('udf_bi_holds')) as t (f_name))
select f_name as "MISSING/MISNAMED FUNCTIONS (if any)" 
    from f_names left join pg_catalog.pg_proc
    on (f_name = lower(proname))
    where proname is null;

\prompt 'Misnamed triggers & functions may be renamed to proceed. \nMissing altogether = 0 marks, even if some tests pass. \nPress ctrl-c to stop and edit the submission, or Enter to continue: ' x


-- Disable all assessed triggers
\echo Attempting to disable all triggers here, any mis-named ones will cause an error...
alter table EVENTS disable trigger AI_MISSING_RETURN;
alter table EVENTS disable trigger BI_HOLDS;
alter table EVENTS disable trigger BI_LOSS_CHARGE;

alter table ITEMS disable trigger BI_ITEM_ID;

alter table PATRONS disable trigger BI_EMAIL_ADDR;
alter table PATRONS disable trigger BI_GUARDIAN;

\set QUIET on
\set ECHO none
\set client_min_messages ERROR
\pset pager off

-- Additional setup

create temp table MARKS (question varchar, item varchar, score numeric, UNIQUE(question, item));

--------------------------------------------------------------------------------

\echo '\n==================== Q1 ====================\n'


-- Q1 Constraints
-- Two tests, one mark

-- \echo Q1 Showing all constraints for reference, including auto-generated ones
-- select constraint_name, table_name, constraint_type from information_schema.table_constraints 
--     where lower(table_name) in ('events', 'items', 'patrons', 'works');

do $$
begin
	begin
		-- should block
        insert into events (patron_id, item_id, event_type, time_stamp) values
            (1, 'UQ01000000001', 'Found', '3024-01-01');
	exception
		when check_violation then
			insert into MARKS VALUES ('1', 'CK_EVENT_TYPE block', 0.5);
		when others then
			raise notice 'CK_EVENT_TYPE unexpected error';
	end;
    
    -- Try to perform a successful insert, too
    insert into events (patron_id, item_id, event_type, time_stamp) values
        (1, 'UQ01000000012', 'Loss', '3024-01-01');

    insert into MARKS select '1', 'CK_EVENT_TYPE allow', 0.5 from Events 
        where item_id = 'UQ01000000012' and event_type = 'Loss' and time_stamp = '3024-01-01';

end;
$$ language plpgsql;

--------------------------------------------------------------------------------

\echo '\n==================== Q2 ====================\n'


-- Q2.1 Guardian
alter table PATRONS enable trigger BI_GUARDIAN;
-- Make sure that we can have inserts at all, also no prohibition on adults having guardians
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('William Windsor', 'william.windsor@example.uk', '1982-06-21', 1);
-- Correct child
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('George Windsor', 'george.windsor@example.uk', '2013-07-22', 1);
do $$ begin
begin
-- Incorrect child #1 (null guardian)
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('Charlotte Windsor', 'charlotte.windsor@example.uk', '2015-05-02', null);
exception when raise_exception then end;
begin
-- Incorrect child #2 should either go through to the FK or be rejected directly
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('Louis Windsor', 'louis.windsor@example.uk', '2018-04-23', 987654);
exception 
    when raise_exception OR foreign_key_violation then end;
end $$ language plpgsql;

alter table PATRONS disable trigger BI_GUARDIAN;

insert into MARKS select '2.1', 'BI_GUARDIAN adult OK', 0.25 
    from Patrons where email_address = 'william.windsor@example.uk';

insert into MARKS select '2.1', 'BI_GUARDIAN child OK', 0.25 
    from Patrons where email_address = 'george.windsor@example.uk';

insert into MARKS select '2.1', 'BI_GUARDIAN child null', 1.0 - count(*) from Patrons
    where email_address = 'charlotte.windsor@example.uk';

insert into MARKS select '2.1', 'BI_GUARDIAN child guardian FK', 0.5 * (1 - count(*)) from Patrons
    where email_address = 'louis.windsor@example.uk';



-- Q2.2 Email addresses
alter table PATRONS enable trigger BI_EMAIL_ADDR;

-- Adults must have an email address, children may have an email address
-- Correct adult
insert into patrons (patron_name, email_address, dob) 
    values ('Anne Windsor', 'anne.windsor@example.uk', '1950-08-15');
-- Permitted child 
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('Archie Windsor', 'archie.windsor@example.uk', '2019-05-06', 1);
-- Child can be missing or null 
insert into patrons (patron_name, email_address, dob, guardian) 
    values ('Lilibet Windsor', null, '2021-06-04', 1);
do $$ begin
begin
-- Incorrect adult (null email)
insert into patrons (patron_name, email_address, dob) 
    values ('Elizabeth II', null, '1926-04-21');
exception when raise_exception then end;
begin
-- Incorrect adult (empty string)
insert into patrons (patron_name, email_address, dob) 
    values ('Harry Windsor', '', '1984-09-15');
exception when raise_exception then end;
end $$ language plpgsql;

alter table PATRONS disable trigger BI_EMAIL_ADDR;


insert into MARKS select '2.2', 'BI_EMAIL_ADDR adult OK', 0.2 
    from Patrons where email_address = 'anne.windsor@example.uk' limit 1;

insert into MARKS select '2.2', 'BI_EMAIL_ADDR child OK (email)', 0.2 
    from Patrons where email_address = 'archie.windsor@example.uk' limit 1;

insert into MARKS select '2.2', 'BI_EMAIL_ADDR child OK (no email)', 0.2 
    from Patrons where patron_name = 'Lilibet Windsor' limit 1;

insert into MARKS select '2.2', 'BI_EMAIL_ADDR adult null email', 0.7 * (1 - count(*)) from Patrons
    where patron_name = 'Elizabeth II';

insert into MARKS select '2.2', 'BI_EMAIL_ADDR adult empty email', 0.7 * (1 - count(*)) from Patrons
    where patron_name = 'Harry Windsor';

--------------------------------------------------------------------------------

-- Q3.1 

\echo '\n==================== Q3 ====================\n\n'

SELECT
sequence_name,
start_value,
maximum_value AS max_value ,
increment
FROM information_schema.sequences
WHERE lower(sequence_name) like '%item%';

insert into MARKS select '3.1', 'ITEM_ID_SEQ name', 0.25 
FROM information_schema.sequences
where lower(sequence_name) = 'item_id_seq';

insert into MARKS select '3.1', 'ITEM_ID_SEQ start', 0.25 
FROM information_schema.sequences
where lower(sequence_name) = 'item_id_seq' and cast(start_value as bigint)  = 1000000000;

insert into MARKS select '3.1', 'ITEM_ID_SEQ max', 0.25 
FROM information_schema.sequences
where lower(sequence_name) = 'item_id_seq' and cast(maximum_value as bigint) = 9999999999;

insert into MARKS select '3.1', 'ITEM_ID_SEQ incr', 0.25 
FROM information_schema.sequences
where lower(sequence_name) = 'item_id_seq' and cast(increment as bigint)  = 1;


-- Q3.2

alter table ITEMS enable trigger BI_ITEM_ID;

-- Default case
do $$ 
begin
    PERFORM setval('ITEM_ID_SEQ', 1910000000, false);
    for i in 0..4 loop
        -- let the sequence value do what it will
        insert into ITEMS (isbn) values ('9000000000001');
    end loop;
end;
$$ language plpgsql;


-- What if I skip the sequence around?
do $$ 
declare
    seq_val bigint;
begin 
for i in 5..9 loop
    seq_val := 1919100014 - i;
    PERFORM setval('ITEM_ID_SEQ', seq_val, false); 
    insert into ITEMS (isbn) values ('9000000000002');
end loop;
end $$ language plpgsql;


-- Things should Just Work if an item_id is already supplied too, right?
do $$ 
begin
    PERFORM setval('ITEM_ID_SEQ', 1919100010, false);
    insert into ITEMS (item_id, isbn) values ('UQ19191910067', '9000000000003');
end $$ language plpgsql;

alter table ITEMS disable trigger BI_ITEM_ID;


-- main: checksum 1-5
insert into MARKS select '3.2', 'BI_ITEM_ID main', 0.19 * count(*)
    from ITEMS where isbn = '9000000000001' and 
    item_id in ('UQ19100000001', 'UQ19100000012', 'UQ19100000023', 
        'UQ19100000034', 'UQ19100000045')
    group by isbn
    having count(*) <= 5;

-- skip: checksum 6-0
insert into MARKS select '3.2', 'BI_ITEM_ID skip', 0.19 * count(*)
    from ITEMS where isbn = '9000000000002' and 
    item_id in ('UQ19191000056', 'UQ19191000067', 'UQ19191000078',
        'UQ19191000089', 'UQ19191000090')
    having count(*) <= 5;

-- extra: don't throw a hissy fit (doesn't matter which ID)
insert into MARKS select '3.2', 'BI_ITEM_ID extra', 0.1 * count(*)
    from ITEMS where isbn = '9000000000003' 
    and not (item_id like 'UQ02%')
    having count(*) = 1;


-- Q3 insert
insert into MARKS values ('3.3', 'SERIAL query', cast(:'q3score' as numeric));
\prompt 'pause: ' _
--------------------------------------------------------------------------------
\echo '\n==================== Q4 ====================\n\n'

-- Q4.1
-- We need to set up a fairly specific supporting cast

do $$ begin PERFORM setval('patrons_patron_id_seq', 1000, false); end $$ language plpgsql;

insert into patrons (patron_name, email_address, dob) values
    ('Henry Jekyll', 'henry.jekyll@example.com', '1886-01-05');
insert into patrons (patron_name, email_address, dob, guardian) values
    ('Edward Hyde', 'edward.hyde@example.com', '2016-01-05', 1000);
insert into patrons (patron_name, email_address, dob) values
    ('Gabriel Utterson', 'gabriel.utterson@example.com', '1850-11-13');

-- The item ID trigger shouldn't be running at this point, let's load up some items 
-- 3x items for 4.1
insert into ITEMS (item_id, isbn) values ('UQ02000000002', '9000000000001');
insert into ITEMS (item_id, isbn) values ('UQ02000000013', '9000000000001');
insert into ITEMS (item_id, isbn) values ('UQ02000000024', '9000000000001');

-- 4x items for 4.2
insert into ITEMS (item_id, isbn) values ('UQ02000000035', '9000000000002');
insert into ITEMS (item_id, isbn) values ('UQ02000000046', '9000000000002');
insert into ITEMS (item_id, isbn) values ('UQ02000000057', '9000000000002');
insert into ITEMS (item_id, isbn) values ('UQ02000000068', '9000000000002');

-- 10x items for 4.3
insert into ITEMS (item_id, isbn) values ('UQ02000000079', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000080', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000091', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000103', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000114', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000125', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000136', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000147', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000158', '9000000000003');
insert into ITEMS (item_id, isbn) values ('UQ02000000169', '9000000000003');


-- Q4.1
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000002', 'Loan', '2025-01-01');

insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000013', 'Loan', '2025-01-01');

insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000024', 'Loan', '2025-01-01');

alter table EVENTS enable trigger BI_LOSS_CHARGE;

-- Adult OK 
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000002', 'Return', '2025-01-29 10:01:00+00');

-- Child OK
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000013', 'Return', '2025-01-29 10:02:00+00');

-- Adult loss
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000024', 'Loss', '2025-01-29 10:03:00+00');

alter table EVENTS disable trigger BI_LOSS_CHARGE;

insert into MARKS select '4.1', 'BI_LOSS_CHARGE Adult return', 0.5 from Events 
where item_id = 'UQ02000000002' and time_stamp = '2025-01-29 10:01:00+00' and patron_id = 1000 
    and event_type = 'Return' 
    and (charge is null or charge = 0)
;

insert into MARKS select '4.1', 'BI_LOSS_CHARGE Child return', 0.5 from Events 
where item_id = 'UQ02000000013' and time_stamp = '2025-01-29 10:02:00+00' and patron_id = 1001 
    and event_type = 'Return' 
    and (charge is null or charge = 0)
;

insert into MARKS select '4.1', 'BI_LOSS_CHARGE Amount OK', 1.0 from Events 
    where item_id = 'UQ02000000024' and time_stamp = '2025-01-29 10:03:00+00' and patron_id = 1000 
    and event_type = 'Loss' 
    and charge = -314159
;
-- great question on EdStem about what if the ISBN is invalid?
-- the actual details here are implementation specific
-- If your trigger uses an explicit JOIN internally you'll have an error there
-- If your trigger looks things up manually you'll have a null somewhere along the line and have to report it
-- Similar behaviour for an invalid item ID.


-- Q4.2 

-- 3 marks for adding returns across 3 scenarios

-- a) Loan; *Return Loan 
--      basic scenario
-- b) Loan Hold; *Return Loan
--      basic but it also had a hold 
-- c) Loan *Return Loan; *Return Loan
--      i.e. existing data has a faked return too

-- 1 mark for not doing the wrong thing 
-- d) ; Loan; Loss
--      new Item, on loan, then lost

-- (a) Loan only
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000035', 'Loan', '2025-02-01 10:01:00+00');

-- (b) Loan Hold 
-- (note due to statement made on EdStem #425 we will not test loans made after holds)
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000046', 'Loan', '2025-01-01 10:02:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000046', 'Hold', '2025-02-12 10:02:00+00');

-- (c) Loan *Return Loan
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000057', 'Loan', '2025-02-01 10:03:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000057', 'Loan', '2025-02-13 11:03:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000057', 'Return', '2025-02-13 10:03:00+00');

-- (d)
-- (new item; no setup inserts)

alter table EVENTS enable trigger AI_MISSING_RETURN;

-- (a)
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000035', 'Loan', '2025-02-28 10:01:00+00');
-- (b)
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000046', 'Loan', '2025-02-28 10:02:00+00');
-- (c)
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000057', 'Loan', '2025-02-28 10:03:00+00');

-- (d)
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000068', 'Loan', '2025-02-28 10:04:02+00');    
    -- Also ensures the trigger can ignore other event types
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000068', 'Loss', '2025-02-28 10:04:03+00');


alter table EVENTS disable trigger AI_MISSING_RETURN;

-- select * from Events where time_stamp > '2025-02-01' and time_stamp < '2025-03-01' order by item_id, time_stamp;

insert into Marks select '4.2', 'AI_MISSING_RETURN Basic', 1
    from Events 
    where 
        exists (select * from Events where item_id = 'UQ02000000035' and event_type = 'Return' and time_stamp = '2025-02-28 09:01:00' and patron_id = 1000)
        and exists (select * from Events where item_id = 'UQ02000000035' and event_type = 'Loan' and time_stamp = '2025-02-28 10:01:00' and patron_id = 1002)
        and 1 = (select count(*) from Events where item_id = 'UQ02000000035' and event_type = 'Return')
    limit 1;

insert into Marks select '4.2', 'AI_MISSING_RETURN Hold', 1
    from Events 
    where 
        exists (select * from Events where item_id = 'UQ02000000046' and event_type = 'Return' and time_stamp = '2025-02-28 09:02:00')
        and exists (select * from Events where item_id = 'UQ02000000046' and event_type = 'Loan' and time_stamp = '2025-02-28 10:02:00')
    limit 1;

insert into Marks select '4.2', 'AI_MISSING_RETURN Full', 1
    from Events 
    where 
        exists (select * from Events where item_id = 'UQ02000000057' and event_type = 'Return' and time_stamp = '2025-02-28 09:03:00')
        and exists (select * from Events where item_id = 'UQ02000000057' and event_type = 'Loan' and time_stamp = '2025-02-28 10:03:00')
        and 2 = (select count(*) from Events where item_id = 'UQ02000000057' and event_type = 'Return')
    limit 1;

insert into Marks select '4.2', 'AI_MISSING_RETURN Empty', 0.5
    from Events 
    where 
        not exists (select * from Events where item_id = 'UQ02000000068' and event_type = 'Return')
        and exists (select * from Events where item_id = 'UQ02000000068' and event_type = 'Loan' and time_stamp = '2025-02-28 10:04:02')
    limit 1;

insert into Marks select '4.2', 'AI_MISSING_RETURN Extra', 0.5
    from Events 
    where 
        not exists (select * from Events where item_id = 'UQ02000000068' and event_type = 'Return')
        and exists (select * from Events where item_id = 'UQ02000000068' and event_type = 'Loss' and time_stamp = '2025-02-28 10:04:03')
    limit 1;


-- Q4.3 

/*
Buckle up, because there's a lot of possible combinations of events here to consider.

The criteria [a], [b], [c] are better worded as:

[a] the item is currently on hold (defined as having any hold with expiry in the future)
[b] the item is available to borrow (returned and not lost) 
[c] the item is on loan to a _different_ patron

We require [a] AND ([b] OR [c]).

We will test conbinations of [a]/[b]/[c] which should be rejected.

[a] "Already Held" should-block checks
ActiveHold only
OtherLoan, ActiveHold

[b] not "Available" should-block checks
Lost only
Lost, ExpiredHold

[c] Self-loan should-block checks
SelfLoan only
SelfLoan, ExpiredHold

When the item is on loan to a different patron, the hold has specified expiry time +42 days from the loan event.

[+42] should-allow checks
OtherLoan only
OtherLoan, ExpiredHold

Otherwise, the hold expires +14 days from hold placement, defined by the initial (original) value of NEW.time_stamp

[+14] timing
(empty history)
Loan, Return

In all cases assume the initial value of NEW.time_stamp to be the current time.

*/

-- SETUP: 
-- Test holds by patron 1002
-- Other events by patron 1000 or 1001
-- We told people not to use NOW() but we're not completely unreasonable:
-- Where a hold is meant to test as "active" it is set in 2025-04-15 (yes, 2025)
-- Where a hold is meant to test as "expired" it is set in 2024-03-01 or 2024-04-01
-- Where a loan or loss is meant to test as "active" it is set in 2024-03-01
-- Where there's a return it's on 2024-03-02
-- All tested holds to be set for 2025-04-03 (yes, 2025 again)
-- So where there is an active loan the hold will be on 2024-04-12
-- And where there is no active loan, it will be on 2025-04-17

--    i) BI_HOLDS Active Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000079', 'Hold', '2025-04-15 10:01:00+00');

--   ii) BI_HOLDS OtherLoan Active
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000080', 'Loan', '2025-03-04 10:02:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000080', 'Hold', '2025-04-15 10:02:00+00');

--  iii) BI_HOLDS Lost Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000091', 'Loss', '2024-03-01 10:03:00+00');
    
--   iv) BI_HOLDS Lost Expired
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000103', 'Loss', '2024-03-01 10:04:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000103', 'Hold', '2024-04-01 10:04:00+00');

--    v) BI_HOLDS SelfLoan Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000114', 'Loan', '2024-03-01 10:05:00+00');

--   vi) BI_HOLDS SelfLoan ExpiredHold
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000125', 'Loan', '2024-03-01 10:06:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000125', 'Hold', '2024-04-01 10:06:00+00');

--  vii) BI_HOLDS OtherLoan Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000136', 'Loan', '2024-03-01 10:07:00+00');
    -- should be permitted 

-- viii) BI_HOLDS OtherLoan ExpiredHold
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000147', 'Loan', '2024-03-01 10:08:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1001, 'UQ02000000147', 'Hold', '2024-04-01 10:08:00+00');

--   ix) BI_HOLDS Empty
-- Do nothing for item UQ02000000158
--    x) BI_HOLDS Normal
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000169', 'Loan', '2024-03-01 10:10:00+00');
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1000, 'UQ02000000169', 'Return', '2024-03-02 10:10:00+00');



ALTER TABLE Events enable trigger BI_HOLDS;

-- The following six inserts should be blocked:
do $$ begin
begin
--    i) BI_HOLDS Active Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000079', 'Hold', '2025-04-03 10:01:00+00');
exception when raise_exception then end;
begin 
--   ii) BI_HOLDS OtherLoan Active
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000080', 'Hold', '2025-04-03 10:02:00+00');
exception when raise_exception then end;
begin 
--  iii) BI_HOLDS Lost Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000091', 'Hold', '2025-04-03 10:03:00+00');
exception when raise_exception then end;
begin 
--   iv) BI_HOLDS Lost Expired
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000103', 'Hold', '2025-04-03 10:03:00+00');
exception when raise_exception then end;
begin 
--    v) BI_HOLDS SelfLoan Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000114', 'Hold', '2025-04-03 10:05:00+00');
exception when raise_exception then end;
begin 
--   vi) BI_HOLDS SelfLoan ExpiredHold
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000125', 'Hold', '2025-04-03 10:06:00+00');
exception when raise_exception then end;
end $$ language plpgsql;
-- The following four should be allowed and have correct time stamp
--  vii) BI_HOLDS OtherLoan Basic
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000136', 'Hold', '2025-04-03 10:07:00+00');
-- viii) BI_HOLDS OtherLoan ExpiredHold
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000147', 'Hold', '2025-04-03 10:08:00+00');
--   ix) BI_HOLDS Empty
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000158', 'Hold', '2025-04-03 10:09:00+00');
--    x) BI_HOLDS Normal
insert into EVENTS (patron_id, item_id, event_type, time_stamp) values 
    (1002, 'UQ02000000169', 'Hold', '2025-04-03 10:10:00+00');

ALTER TABLE Events disable trigger BI_HOLDS;


--    i) BI_HOLDS Active Basic
insert into Marks select '4.3', 'BI_HOLDS Active Basic', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000079' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;
--   ii) BI_HOLDS OtherLoan Active
insert into Marks select '4.3', 'BI_HOLDS OtherLoan Active', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000080' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;

--  iii) BI_HOLDS Lost Basic
insert into Marks select '4.3', 'BI_HOLDS Lost Basic', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000091' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;

--   iv) BI_HOLDS Lost Expired
insert into Marks select '4.3', 'BI_HOLDS Lost Expired', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000103' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;

--    v) BI_HOLDS SelfLoan Basic
insert into Marks select '4.3', 'BI_HOLDS SelfLoan Basic', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000114' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;

--   vi) BI_HOLDS SelfLoan ExpiredHold
insert into Marks select '4.3', 'BI_HOLDS SelfLoan ExpiredHold', 0.5
    from Events 
    where not exists (select * from Events 
        where item_id = 'UQ02000000125' 
            and event_type = 'Hold' and patron_id = 1002
            )
    limit 1;

--  vii) BI_HOLDS OtherLoan Basic
insert into Marks select '4.3', 'BI_HOLDS OtherLoan Basic', 0.5
    from Events 
    where 1 = (select count(*) from Events 
        where item_id = 'UQ02000000136' 
            and event_type = 'Hold' and patron_id = 1002
            and time_stamp = '2024-04-12 10:07:00'
            )
    limit 1;


-- viii) BI_HOLDS OtherLoan ExpiredHold
insert into Marks select '4.3', 'BI_HOLDS OtherLoan ExpiredHold', 0.5
    from Events 
    where 1 = (select count(*) from Events 
        where item_id = 'UQ02000000147' 
            and event_type = 'Hold' and patron_id = 1002
            and time_stamp = '2024-04-12 10:08:00'
            )
    limit 1;


--   ix) BI_HOLDS Empty
insert into Marks select '4.3', 'BI_HOLDS Empty', 0.5
    from Events 
    where 1 = (select count(*) from Events 
        where item_id = 'UQ02000000158' 
            and event_type = 'Hold' and patron_id = 1002
            and time_stamp = '2025-04-17 10:09:00'
            )
    limit 1;

--    x) BI_HOLDS Normal
insert into Marks select '4.3', 'BI_HOLDS Normal', 0.5
    from Events 
    where 1 = (select count(*) from Events 
        where item_id = 'UQ02000000169' 
            and event_type = 'Hold' and patron_id = 1002
            and time_stamp = '2025-04-17 10:10:00'
            )
    limit 1;




--------------------------------------------------------------------------------
\echo '\n==================== Marks ====================\n'


do $$
declare
    rec record;
    ck_event_exists int;
begin
-- note: we disabled the ck_event_exists check before marking, it is retained for interest.
-- select count(*) into ck_event_exists from information_schema.table_constraints 
--      where lower(table_name) = 'events'; --
--     --  and lower(constraint_name) = 'ck_event_type'; -- allow mis-named constraint

-- if ck_event_exists <> 1 then
--     update marks set score = 0
--         where item ILIKE '%CK_EVENT_TYPE%';
--     raise notice 'CK_EVENT_TYPE not found: 0 marks';
-- end if;
-- item_id_seq is checked for by name in its marking

-- the following is more to handle when triggers are missing altogether; we rename triggers before marking if needed
for rec in 
    with t_names as (select * from (values 
        ('ai_missing_return'), ('bi_holds'), ('bi_loss_charge'), 
            ('bi_item_id'), ('bi_email_addr'), ('bi_guardian')) as t (t_name))
    SELECT '%' || t_name || '%' as tname
        from t_names left join information_schema.triggers 
        on (t_name = lower(trigger_name))
        where trigger_name is null 
loop
    update marks set score = 0
        where lower(item) ~~ rec.tname;
    -- raise notice '% not found, 0 marks', rec.tname;
end loop;

end; 
$$ language plpgsql;

select sum(score) as "Total Marks" from Marks;

\echo 'Errors, if any:\n'

with all_items as (select * from (VALUES
    ('1','CK_EVENT_TYPE block', 0.5),
    ('1','CK_EVENT_TYPE allow', 0.5),
    ('2.1','BI_GUARDIAN adult OK', 0.25),
    ('2.1','BI_GUARDIAN child OK', 0.25),
    ('2.1','BI_GUARDIAN child null', 1),
    ('2.1','BI_GUARDIAN child guardian FK', 0.5),
    ('2.2','BI_EMAIL_ADDR adult OK', 0.2),
    ('2.2','BI_EMAIL_ADDR child OK (email)', 0.2),
    ('2.2','BI_EMAIL_ADDR child OK (no email)', 0.2),
    ('2.2','BI_EMAIL_ADDR adult null email', 0.7),
    ('2.2','BI_EMAIL_ADDR adult empty email', 0.7),
    ('3.1','ITEM_ID_SEQ name', 0.25),
    ('3.1','ITEM_ID_SEQ start', 0.25),
    ('3.1','ITEM_ID_SEQ max', 0.25),
    ('3.1','ITEM_ID_SEQ incr', 0.25),
    ('3.2','BI_ITEM_ID main', 0.95),
    ('3.2','BI_ITEM_ID skip', 0.95),
    ('3.2','BI_ITEM_ID extra', 0.1),
    ('3.3','SERIAL query', 1),
    ('4.1','BI_LOSS_CHARGE Adult return', 0.5),
    ('4.1','BI_LOSS_CHARGE Child return', 0.5),
    ('4.1','BI_LOSS_CHARGE Amount OK', 1),
    ('4.2','AI_MISSING_RETURN Basic', 1),
    ('4.2','AI_MISSING_RETURN Hold', 1),
    ('4.2','AI_MISSING_RETURN Full', 1),
    ('4.2','AI_MISSING_RETURN Empty', 0.5),
    ('4.2','AI_MISSING_RETURN Extra', 0.5),
    ('4.3', 'BI_HOLDS Active Basic', 0.5),
    ('4.3', 'BI_HOLDS OtherLoan Active', 0.5),
    ('4.3', 'BI_HOLDS Lost Basic', 0.5),
    ('4.3', 'BI_HOLDS Lost Expired', 0.5),
    ('4.3', 'BI_HOLDS SelfLoan Basic', 0.5),
    ('4.3', 'BI_HOLDS SelfLoan ExpiredHold', 0.5),
    ('4.3', 'BI_HOLDS OtherLoan Basic', 0.5),
    ('4.3', 'BI_HOLDS OtherLoan ExpiredHold', 0.5),
    ('4.3', 'BI_HOLDS Empty', 0.5),
    ('4.3', 'BI_HOLDS Normal', 0.5)
    ) as t (question, item, maxscore))
select question, item, score from all_items left join Marks using (question, item) 
where score <> maxscore or score is null
order by question;

-- The following block of code relates only to administrative marking processes and is shown for interest only
do $$
declare
    rec record;
    titles varchar;
    scores varchar;
    autocomments varchar;
begin
titles = '';
scores = '';
autocomments = '';

for rec in
with all_items as (select * from (VALUES
    ( 1, '1','CK_EVENT_TYPE block', 0.5),
    ( 2, '1','CK_EVENT_TYPE allow', 0.5),
    ( 3, '2.1','BI_GUARDIAN adult OK', 0.25),
    ( 4, '2.1','BI_GUARDIAN child OK', 0.25),
    ( 5, '2.1','BI_GUARDIAN child null', 1),
    ( 6, '2.1','BI_GUARDIAN child guardian FK', 0.5),
    ( 7, '2.2','BI_EMAIL_ADDR adult OK', 0.2),
    ( 8, '2.2','BI_EMAIL_ADDR child OK (email)', 0.2),
    ( 9, '2.2','BI_EMAIL_ADDR child OK (no email)', 0.2),
    (10, '2.2','BI_EMAIL_ADDR adult null email', 0.7),
    (11, '2.2','BI_EMAIL_ADDR adult empty email', 0.7),
    (12, '3.1','ITEM_ID_SEQ name', 0.25),
    (13, '3.1','ITEM_ID_SEQ start', 0.25),
    (14, '3.1','ITEM_ID_SEQ max', 0.25),
    (15, '3.1','ITEM_ID_SEQ incr', 0.25),
    (16, '3.2','BI_ITEM_ID main', 0.95),
    (17, '3.2','BI_ITEM_ID skip', 0.95),
    (18, '3.2','BI_ITEM_ID extra', 0.1),
    (19, '3.3','SERIAL query', 1),
    (20, '4.1','BI_LOSS_CHARGE Adult return', 0.5),
    (21, '4.1','BI_LOSS_CHARGE Child return', 0.5),
    (22, '4.1','BI_LOSS_CHARGE Amount OK', 1),
    (23, '4.2','AI_MISSING_RETURN Basic', 1),
    (24, '4.2','AI_MISSING_RETURN Hold', 1),
    (25, '4.2','AI_MISSING_RETURN Full', 1),
    (26, '4.2','AI_MISSING_RETURN Empty', 0.5),
    (27, '4.2','AI_MISSING_RETURN Extra', 0.5),
    (28, '4.3', 'BI_HOLDS Active Basic', 0.5),
    (29, '4.3', 'BI_HOLDS OtherLoan Active', 0.5),
    (30, '4.3', 'BI_HOLDS Lost Basic', 0.5),
    (31, '4.3', 'BI_HOLDS Lost Expired', 0.5),
    (32, '4.3', 'BI_HOLDS SelfLoan Basic', 0.5),
    (33, '4.3', 'BI_HOLDS SelfLoan ExpiredHold', 0.5),
    (34, '4.3', 'BI_HOLDS OtherLoan Basic', 0.5),
    (35, '4.3', 'BI_HOLDS OtherLoan ExpiredHold', 0.5),
    (36, '4.3', 'BI_HOLDS Empty', 0.5),
    (37, '4.3', 'BI_HOLDS Normal', 0.5)
    ) as t (ordering, question, item, maxscore))
select * from all_items left join Marks using (question, item) 
order by ordering
LOOP
    if rec.score is null then
        rec.score := 0;
    end if;

    titles := titles || ',' || rec.item;
    scores := scores || ',' || rec.score;

    if rec.score < rec.maxscore then
        autocomments := autocomments || rec.item || ': ' || rec.score || ', ';
    end if;
        
END LOOP;

    titles := trim(titles, ',');
    scores := trim(scores, ',');
    autocomments := trim(autocomments, ', ');

    RAISE NOTICE '
You can copy and paste the second (numbers) row into Excel in the first test''s field, then "Split Text to Columns" by comma.
The third row can be pasted into the Autocomments field (without splitting it).

% 

%

%', titles, scores, autocomments;
end;
$$ language plpgsql;



-- drop table MARKS;
