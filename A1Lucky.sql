-- Q1: CHECK Constraint
ALTER TABLE Events
ADD CONSTRAINT CK_EVENT_TYPE
CHECK (event_type IN ('Loan', 'Return', 'Hold', 'Loss'));
ENABLE CONSTRAINT CK_EVENT_TYPE



-- Q2.1: Constraints with Trigger and Function Checking Guardian Check for age < 18
CREATE OR REPLACE FUNCTION UDF_BI_GUARDIAN()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.dob > CURRENT_DATE - INTERVAL '18 years' THEN
        IF NEW.guardian IS NULL THEN
            RAISE EXCEPTION 'Child must have a guardian';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER BI_GUARDIAN
BEFORE INSERT ON Patrons
FOR EACH ROW
EXECUTE FUNCTION UDF_BI_GUARDIAN();



-- Q2.2: Constraint with Trigger and Function Checking Email Address for age >= 18
CREATE OR REPLACE FUNCTION UDF_BI_EMAIL_ADDR()
RETURNS TRIGGER AS $$
DECLARE
    is_adult BOOLEAN; -- Create a variable for readability
BEGIN
    is_adult := NEW.dob <= CURRENT_DATE - INTERVAL '18 years';
    IF is_adult AND (NEW.email_address IS NULL OR LENGTH(TRIM(NEW.email_address)) = 0) THEN
        RAISE EXCEPTION 'Adult must have an email address';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER BI_EMAIL_ADDR
BEFORE INSERT ON Patrons
FOR EACH ROW
EXECUTE FUNCTION UDF_BI_EMAIL_ADDR();



-- Q3.1: Integer Sequence Creation for Items Table
CREATE SEQUENCE ITEM_ID_SEQ
MINVALUE 1000000000
MAXVALUE 9999999999
INCREMENT BY 1;



-- Q3.2: Sequence, Trigger and Function Generating Unique item_id for New Items
CREATE OR REPLACE FUNCTION UDF_BI_ITEM_ID()
RETURNS TRIGGER AS $$
DECLARE
    seq_id BIGINT;
    original_seq_id BIGINT;
    checksum_value INT;
    sum_digits INT := 0;
    barcode TEXT;
BEGIN
    -- Get the next sequence value
    seq_id := nextval('ITEM_ID_SEQ');
    original_seq_id := seq_id;
    
    -- Calculate the sum of each digit in the sequence
    WHILE seq_id > 0 LOOP
        sum_digits := sum_digits + MOD(seq_id,10);  -- Add the last digit
        seq_id := seq_id / 10;  -- Remove the last digit
    END LOOP;

    -- Calculate checksum as mod 10 of the sum of digits
    checksum_value := MOD(sum_digits,10);
    
    -- Generate the item_id
    barcode := 'UQ' || original_seq_id || checksum_value;

    -- Ensure the generated item_id is unique, and retry if necessary
    IF EXISTS(SELECT 1 FROM Items WHERE item_id = barcode) THEN
        RAISE EXCEPTION 'Generated item_id % already exists', barcode;
    END IF;

    -- Assign the generated item_id to the new record
    NEW.item_id := barcode;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER BI_ITEM_ID
BEFORE INSERT ON Items
FOR EACH ROW
EXECUTE FUNCTION UDF_BI_ITEM_ID();



-- Q3.3: Sequence Identification Query to List Postgres-internal Sequences
SELECT
  c.relname AS table_name,
  a.attname AS column_name,
  s.relname AS sequence_name
FROM
  pg_class s,
  pg_depend d,
  pg_class c,
  pg_attribute a
WHERE
  s.relkind = 'S'
  AND s.oid = d.objid
  AND d.refobjid = c.oid
  AND d.refobjid = a.attrelid
  AND d.refobjsubid = a.attnum
  AND c.relname IN ('Patrons', 'Events');



-- Q4.1: Losses
CREATE OR REPLACE FUNCTION UDF_BI_LOSS_CHARGE()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if the event type is 'Loss'
    IF NEW.event_type = 'Loss' THEN
        -- Retrieve the isbn from the Items table using item_id
        NEW.charge := (SELECT cost FROM Works WHERE isbn = (SELECT isbn FROM Items WHERE item_id = NEW.item_id));

        -- Check if the cost was successfully retrieved
        IF NEW.charge IS NULL THEN
            RAISE EXCEPTION 'Cost for ISBN % is NULL or ISBN not found in Works table', (SELECT isbn FROM Items WHERE item_id = NEW.item_id);
        END IF;
    END IF;
    
    -- Return the NEW record
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to execute the UDF_BI_LOSS_CHARGE function before inserting into the Events table
CREATE TRIGGER BI_LOSS_CHARGE
BEFORE INSERT ON Events
FOR EACH ROW
EXECUTE FUNCTION UDF_BI_LOSS_CHARGE();



-- Q4.2: Missing Returns
CREATE OR REPLACE FUNCTION UDF_AI_MISSING_RETURN()
RETURNS TRIGGER AS $$
DECLARE
    last_patron INT;
    last_event TIMESTAMP;
BEGIN
    -- Find the last loan before the new event
    SELECT patron_id, time_stamp INTO last_patron, last_event
    FROM Events
    WHERE item_id = NEW.item_id
      AND event_type = 'Loan'
      AND time_stamp < NEW.time_stamp
    ORDER BY time_stamp DESC
    LIMIT 1;

    -- Check if the last patron didn’t return or is different from current patron
    IF last_patron IS NOT NULL AND last_patron <> NEW.patron_id THEN
        -- Check if there is already a return recorded
        IF NOT EXISTS (
            SELECT 1 FROM Events
            WHERE item_id = NEW.item_id
              AND event_type = 'Return'
              AND patron_id = last_patron
              AND time_stamp > last_event
        ) THEN
            -- Insert missing return record
            INSERT INTO Events(event_type, patron_id, item_id, time_stamp)
            VALUES ('Return', last_patron, NEW.item_id, NEW.time_stamp - INTERVAL '1 hour');
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER AI_MISSING_RETURN
AFTER INSERT ON Events
FOR EACH ROW
WHEN (NEW.event_type = 'Loan')
EXECUTE FUNCTION UDF_AI_MISSING_RETURN();



-- Q4.3: Trigger and Function for Holds
CREATE OR REPLACE FUNCTION UDF_BI_HOLDS()
RETURNS TRIGGER AS $$
DECLARE
    current_loan TIMESTAMP;
    current_holder INT;
    existing_hold BOOLEAN;
    is_lost BOOLEAN;
BEGIN
    -- Check if item is already lost
    SELECT EXISTS (
        SELECT 1 FROM Events
        WHERE item_id = NEW.item_id
        AND event_type = 'Loss'
    ) INTO is_lost;

    IF is_lost THEN
        RAISE EXCEPTION 'Cannot place a hold on a lost item.';
    END IF;
    -- Check if item is already held by another patron
    SELECT EXISTS (
        SELECT 1 FROM Events
        WHERE item_id = NEW.item_id
        AND event_type = 'Hold'
        AND patron_id <> NEW.patron_id
    ) INTO existing_hold;

    IF existing_hold THEN
        RAISE EXCEPTION 'This item is already held by another patron.';
    END IF;

    -- Check if item is on loan and get the most recent loan timestamp
    SELECT time_stamp INTO current_loan
    FROM Events
    WHERE item_id = NEW.item_id
    AND event_type = 'Loan'
    ORDER BY time_stamp DESC
    LIMIT 1;

    -- If the item is on loan to a different patron, allow hold with expiry in 42 days
    IF current_loan IS NOT NULL THEN
        NEW.time_stamp := current_loan + INTERVAL '42 days';
    ELSE
        -- If the item is not on loan (i.e., available for lending), set hold expiry to 14 days
        NEW.time_stamp := NEW.time_stamp + INTERVAL '14 days';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER BI_HOLDS
BEFORE INSERT ON Events
FOR EACH ROW
WHEN (NEW.event_type = 'Hold')
EXECUTE FUNCTION UDF_BI_HOLDS();

