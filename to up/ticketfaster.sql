-- Active: 1711937097451@@127.0.0.1@3306@ticketfaster
Active: 1711480276503@@127.0.0.1@3306


--CREATE DATABASE ticketfaster;

/*
INSERT INTO MyTable SELECT a.* FROM
OPENROWSET (BULK N'D:\data.csv', FORMATFILE =
    'D:\format_no_collation.txt', CODEPAGE = '65001') AS a;
    */

USE ticketfaster;


CREATE TABLE
    promoter(
        ID int,
        name varchar(50),
        parentcompany varchar(50),
        contact varchar(50),
        phone varchar(25),
        email varchar(25),
        primary key(ID)
    );

CREATE TABLE
    artist(
        ID int,
        name varchar(50),
        genre varchar(50),
        promoterid int,
        lastmodified datetime,
        primary key(ID),
        foreign key(promoterid) references promoter(ID)
    );

CREATE TABLE
    venue(
        ID int,
        name varchar(50),
        type varchar(25),
        capacity int,
        address varchar(255),
        city varchar(25),
        state varchar(25),
        zip varchar(5),
        url VARCHAR(2083),
        contact varchar(25),
        phone varchar(25),
        email varchar(25),
        lastmodified datetime,
        primary key(ID)
    );

CREATE TABLE
    events(
        ID int,
        name varchar(50),
        type varchar(25),
        venueid int,
        artistid int,
        promoterid int,
        eventdates datetime,
        ticketssold int,
        lastmodified datetime,
        primary key(ID),
        foreign key(venueid) references venue(ID),
        foreign key(artistid) references artist(ID),
        foreign key(promoterid) references promoter(ID)
    );

CREATE TABLE
    tickets(
        ID int,
        eventid int,
        venueid int,
        zone varchar(5),
        rown varchar(5),
        seat varchar(5),  
        price decimal, 
        availability bool,
        minimumlimit int,
        lastmodified datetime,
        primary key(ID),
        foreign key(eventid) references events(ID),
        foreign key(venueid) references venue(ID)
    );


CREATE TABLE customer(
    ID int,
    firstname varchar(25),
    lastname varchar(25),
    username varchar(25),
    address varchar(255),
    city varchar(25),
    state varchar(25),
    zip varchar(5),
    phone varchar(25),
    email varchar(25),
    lastmodified datetime,
    primary key(ID)
);

CREATE TABLE
    account(
        ID int,
        customerid int,
        cardname varchar(50),
        cardno varchar(16),
        expirationmonth int,
        expirationyr int,
        lastmodified datetime,
        primary key(ID),
        foreign key(customerid) references customer(ID) 
    );

CREATE TABLE
    sale(
        ID int,
        customerid int,
        ticketid int,
        price decimal,
        accountid int,
        saledate datetime,
        lastmodified datetime,
        primary key(ID),
        foreign key(customerid) references customer(ID),
        foreign key(ticketid) references tickets(ID),
        foreign key(accountid) references account(ID)   
    );


SET SQL_MODE='ALLOW_INVALID_DATES';

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/promoter.csv' INTO
TABLE
    ticketfaster.promoter FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/artists.csv' INTO
TABLE
    ticketfaster.artist FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

--ALTER TABLE venue MODIFY COLUMN email VARCHAR(50);
 LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/venue.csv' INTO
TABLE
    ticketfaster.venue FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;   

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/events.csv' INTO
TABLE
    ticketfaster.events FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

--INSERT INTO promoter VALUES (16, 'No promoter', 'NA', 'NA','NA','NA');

--INSERT INTO artist VALUES (25, 'Other','NA',16,'0000-00-00 00:00:00');

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/tickets.csv' INTO
TABLE
    ticketfaster.tickets FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/customer.csv' INTO
TABLE
    ticketfaster.customer FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/accounts.csv' INTO
TABLE
    ticketfaster.account FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;

LOAD DATA
    INFILE '/home/coder/project/Ticketfaster/data/sale.csv' INTO
TABLE
    ticketfaster.sale FIELDS TERMINATED BY ',' ENCLOSED BY '' LINES TERMINATED BY '\n' IGNORE 1 ROWS;


--Functions:
--Gives number of tickets available for an event:
CREATE FUNCTION get_available_ticket_count(eventid INT) 
RETURNS INT 
BEGIN 
	DECLARE available_tickets INT;
	DECLARE sold_tickets INT;
	-- Calculate the number of tickets sold for the event
	SELECT
	    COALESCE(SUM(ticketssold), 0) INTO sold_tickets
	FROM events
	WHERE ID = eventid;
	-- Get the capacity of the venue
	SELECT
	    capacity INTO available_tickets
	FROM venue
	WHERE ID = (
	        SELECT venueid
	        FROM events
	        WHERE ID = eventid
	    );
	-- Calculate the available tickets
	SET available_tickets = available_tickets - sold_tickets;
	RETURN available_tickets;
END; 	

--example
Select distinct name,venueid,get_available_ticket_count(4)
From events
Where id=4

--lists eventnames for a given date:
DELIMITER //
CREATE FUNCTION get_event_names_by_date(event_date DATE) 
RETURNS VARCHAR(500) 
BEGIN 
	DECLARE event_names VARCHAR(500) DEFAULT ' ';
	-- Concatenate event names
	SELECT GROUP_CONCAT(e.name SEPARATOR ',') INTO event_names
	FROM events e
	WHERE DATE(e.eventdates)=event_date;
	RETURN event_names;
END // 
DELIMITER ;

--Example
Select get_event_names_by_date('2024-05-14')
From events


--DROP FUNCTION IF EXISTS get_event_names_by_date; 
--I had to change it so rather than altering I dropped and recreated it

--creates new event:
CREATE FUNCTION create_event(event_name VARCHAR(50), event_type VARCHAR(25), venue_id INT, artist_id INT, promoter_id INT, event_date DATETIME, 
tickets_sold INT) 
RETURNS INT 
BEGIN 
	DECLARE new_event_id INT;
	-- Insert the new event into the events table
	INSERT INTO
	    events (name,  type, venueid, artistid, promoterid, eventdates, ticketssold, lastmodified)
	VALUES (event_name, event_type, venue_id, artist_id, promoter_id, event_date, tickets_sold, NOW() -- Set current system datetime as last modified
	    );
	-- Get the ID of the newly inserted event
	SET new_event_id = LAST_INSERT_ID();
	RETURN new_event_id;
END; 



--Triggers
--Automatically updates the ticketssold count in the events table when a new ticket is sold:
CREATE TRIGGER after_insert_tickets 
AFTER INSERT ON tickets 
FOR EACH ROW 
BEGIN 
-- Update the ticket count for the associated event
UPDATE events
SET ticketssold = ticketssold + 1
WHERE ID = NEW.eventid;
END;

--updates the tickets.availability to 1 when a sale happens:
CREATE TRIGGER update_ticket_availability 
AFTER INSERT ON sale 
FOR EACH ROW 
BEGIN 
-- Update the availability of the ticket to 1
UPDATE tickets
SET availability = 1
WHERE ID = NEW.ticketid;
END;

--To enforce the lastmodified column in the tables to automatically update with the system date and time whenever a row is modified:
CREATE TRIGGER update_lastmodified_account 
	BEFORE UPDATE ON account FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_artist 
	BEFORE UPDATE ON artist FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_customer 
	BEFORE UPDATE ON customer FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_events 
	BEFORE UPDATE ON events FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_sale 
	BEFORE UPDATE ON sale FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_tickets 
	BEFORE UPDATE ON tickets FOR EACH ROW SET NEW.lastmodified = NOW();

CREATE TRIGGER update_lastmodified_venue 
	BEFORE UPDATE ON venue FOR EACH ROW SET NEW.lastmodified = NOW();

--stored precedures:
--It takes event_id and outputs event details:
DELIMITER //
CREATE PROCEDURE get_event_details(IN event_id INT) 
BEGIN 
	SELECT e.name AS event_name, e.type AS event_type, v.name AS venue_name, e.eventdates AS event_date, e.ticketssold AS tickets_sold
	FROM events e INNER JOIN venue v ON e.venueid = v.ID
	WHERE e.ID = event_id; 
END // 
DELIMITER ; 

--Example
CALL get_event_details(4);

--Add new event:
DELIMITER //
CREATE PROCEDURE add_new_event(IN event_name VARCHAR(50), IN event_type VARCHAR(25), IN venue_id INT, IN artist_id INT, IN promoter_id INT, 
IN event_date DATETIME, IN tickets_sold INT) 
BEGIN 
	-- Insert the new event into the events table
	INSERT INTO
	    events (name, type, venueid, artistid, promoterid, eventdates, ticketssold, lastmodified)
	VALUES (event_name, event_type, venue_id, artist_id, promoter_id, event_date, tickets_sold, NOW());
END // 
DELIMITER ;

--Example
CALL add_new_event('BTS Concert', 'Concert',4,2,1, '2026-05-15 19:00:00',100);

--had a datetime issue, so I forced sql to accept my dates with SET SQL_MODE='ALLOW_INVALID_DATES';, and it made everything 00-00-0000... 
--so now I am fixing them here painfully:
--(STR_TO_DATE ('5/15/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('5/19/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('5/14/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('5/29/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('5/17/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('6/1/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('7/2/2024 20:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('6/6/2024 20:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('6/24/2024 19:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('9/15/2024 19:30', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('10/24/2024 19:30', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('10/10/2024 20:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('9/7/2024 18:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('9/13/2024 18:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('10/14/2024 18:00', '%m/%d/%Y %H:%i')), (STR_TO_DATE ('11/18/2024 18:00', '%m/%d/%Y %H:%i'))
UPDATE events
SET eventdates = STR_TO_DATE('5/14/2024 19:00','%m/%d/%Y %H:%i')
WHERE ID = 1;

UPDATE events
SET
    eventdates = CASE
        WHEN ID = 2 THEN STR_TO_DATE(
            '5/15/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '5/19/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '5/14/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '5/29/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '5/17/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '6/1/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '7/2/2024 20:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '6/6/2024 20:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '6/24/2024 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '9/15/2024 19:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '10/24/2024 19:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '10/10/2024 20:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '9/7/2024 18:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '9/13/2024 18:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 16 THEN STR_TO_DATE(
            '10/14/2024 18:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 17 THEN STR_TO_DATE(
            '11/18/2024 18:00',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE
    ID IN (2,3,4,5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17);

UPDATE events 
SET lastmodified = CASE
    WHEN ID = 1 THEN STR_TO_DATE(
        '3/25/2024 3:25',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 2 THEN STR_TO_DATE(
        '3/13/2024 19:13',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 3 THEN STR_TO_DATE(
        '3/11/2024 8:47',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 4 THEN STR_TO_DATE(
        '3/9/2024 10:07',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 5 THEN STR_TO_DATE(
        '3/6/2024 16:50',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 6 THEN STR_TO_DATE(
        '2/23/2024 16:30',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 7 THEN STR_TO_DATE(
        '2/18/2024 17:59',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 8 THEN STR_TO_DATE(
        '2/1/2024 20:49',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 9 THEN STR_TO_DATE(
        '1/20/2024 8:47',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 10 THEN STR_TO_DATE(
        '1/13/2024 20:08',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 11 THEN STR_TO_DATE(
        '1/10/2024 6:37',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 12 THEN STR_TO_DATE(
        '1/7/2024 15:37',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 13 THEN STR_TO_DATE(
        '1/1/2024 5:01',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 14 THEN STR_TO_DATE(
        '12/17/2023 20:33',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 15 THEN STR_TO_DATE(
        '12/13/2023 2:38',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 16 THEN STR_TO_DATE(
        '12/4/2023 8:52',
        '%m/%d/%Y %H:%i'
    )
    WHEN ID = 17 THEN STR_TO_DATE(
        '2/19/2024 17:43',
        '%m/%d/%Y %H:%i'
    )
END
WHERE ID IN (1,2,3,4,5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17);
   
UPDATE account
SET
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '4/25/2022 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '3/13/2022 19:13',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '3/11/2021 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '3/9/2020 10:07',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '3/6/2021 16:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '2/23/2020 16:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '2/18/2021 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '2/1/2021 20:49',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '1/20/2022 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '1/13/2021 20:08',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '1/10/2023 6:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '1/7/2021 15:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '1/1/2023 5:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '12/17/2021 20:33',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '12/13/2022 2:38',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 16 THEN STR_TO_DATE(
            '12/4/2021 8:52',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 17 THEN STR_TO_DATE(
            '2/19/2022 17:43',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 18 THEN STR_TO_DATE(
            '3/25/2022 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 19 THEN STR_TO_DATE(
            '3/13/2020 19:13',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 20 THEN STR_TO_DATE(
            '3/11/2022 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 21 THEN STR_TO_DATE(
            '3/9/2021 10:07',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 22 THEN STR_TO_DATE(
            '3/6/2022 16:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 23 THEN STR_TO_DATE(
            '2/23/2022 16:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 24 THEN STR_TO_DATE(
            '2/18/2023 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 25 THEN STR_TO_DATE(
            '2/1/2022 20:49',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE ID BETWEEN 1 AND 25;    

UPDATE artist
SET
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '5/14/2018 19:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '7/6/2018 12:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '10/29/2018 15:45',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '2/22/2019 10:15',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '8/9/2019 14:20',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '11/17/2019 18:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '3/4/2020 9:45',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '9/21/2020 16:00',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '12/12/2020 11:10',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '6/5/2021 13:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '10/18/2021 17:35',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '2/9/2022 14:40',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '8/1/2022 18:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '11/29/2022 10:05',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '4/15/2023 15:15',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 16 THEN STR_TO_DATE(
            '9/3/2023 12:20',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 17 THEN STR_TO_DATE(
            '12/28/2023 11:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 18 THEN STR_TO_DATE(
            '1/8/2018 10:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 19 THEN STR_TO_DATE(
            '5/17/2018 14:45',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 20 THEN STR_TO_DATE(
            '9/3/2018 9:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 21 THEN STR_TO_DATE(
            '1/22/2019 11:05',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 22 THEN STR_TO_DATE(
            '6/10/2019 12:20',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 23 THEN STR_TO_DATE(
            '10/28/2019 16:35',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 24 THEN STR_TO_DATE(
            '2/15/2020 15:40',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 25 THEN STR_TO_DATE(
            '7/4/2020 17:55',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE ID BETWEEN 1 AND 25;

UPDATE customer
SET
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '4/25/2022 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '3/13/2022 19:13',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '3/11/2021 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '3/9/2020 10:07',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '3/6/2021 16:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '2/23/2020 16:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '2/18/2021 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '2/1/2021 20:49',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '1/20/2022 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '1/13/2021 20:08',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '1/10/2023 6:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '1/7/2021 15:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '1/1/2023 5:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '12/17/2021 20:33',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '12/13/2022 2:38',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 16 THEN STR_TO_DATE(
            '12/4/2021 8:52',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 17 THEN STR_TO_DATE(
            '2/19/2022 17:43',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 18 THEN STR_TO_DATE(
            '3/25/2022 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 19 THEN STR_TO_DATE(
            '3/13/2020 19:13',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 20 THEN STR_TO_DATE(
            '3/11/2022 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 21 THEN STR_TO_DATE(
            '3/9/2021 10:07',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 22 THEN STR_TO_DATE(
            '3/6/2022 16:50',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 23 THEN STR_TO_DATE(
            '2/23/2022 16:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 24 THEN STR_TO_DATE(
            '2/18/2023 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 25 THEN STR_TO_DATE(
            '2/1/2022 20:49',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE ID BETWEEN 1 AND 25;

UPDATE sale
SET
    saledate = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '2/19/2024 17:43',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '1/20/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '1/13/2024 20:08',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '1/10/2024 6:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '1/7/2024 15:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '1/1/2024 5:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '12/17/2023 20:33',
            '%m/%d/%Y %H:%i'
        )
    END,
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '2/19/2024 17:43',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '1/20/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '1/13/2024 20:08',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '1/10/2024 6:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '1/7/2024 15:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '1/1/2024 5:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '12/17/2023 20:33',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE ID BETWEEN 1 AND 15;

UPDATE tickets
SET
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '3/25/2024 3:25',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '1/20/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '1/7/2024 15:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '1/13/2024 20:08',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '2/19/2024 17:43',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '1/1/2024 5:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 16 THEN STR_TO_DATE(
            '3/11/2024 8:47',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 17 THEN STR_TO_DATE(
            '12/17/2023 20:33',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 18 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 19 THEN STR_TO_DATE(
            '2/18/2024 17:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 20 THEN STR_TO_DATE(
            '1/10/2024 6:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 21 THEN STR_TO_DATE(
            '1/1/2024 3:30',
            '%m/%d/%Y %H:%i'
)
    END
WHERE ID BETWEEN 1 AND 21;

--ALTER TABLE tickets MODIFY COLUMN lastmodified DATETIME;

--ALTER TABLE venue MODIFY COLUMN lastmodified DATETIME;

UPDATE venue
SET
    lastmodified = CASE
        WHEN ID = 1 THEN STR_TO_DATE(
            '2/22/2020 12:06',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 2 THEN STR_TO_DATE(
            '9/6/2020 2:12',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 3 THEN STR_TO_DATE(
            '7/5/2020 2:44',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 4 THEN STR_TO_DATE(
            '1/26/2022 16:19',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 5 THEN STR_TO_DATE(
            '1/14/2019 21:01',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 6 THEN STR_TO_DATE(
            '9/19/2020 20:29',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 7 THEN STR_TO_DATE(
            '1/7/2022 11:18',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 8 THEN STR_TO_DATE(
            '1/1/2020 12:59',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 9 THEN STR_TO_DATE(
            '2/13/2018 20:49',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 10 THEN STR_TO_DATE(
            '10/16/2019 17:15',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 11 THEN STR_TO_DATE(
            '2/5/2021 3:37',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 12 THEN STR_TO_DATE(
            '5/24/2023 6:18',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 13 THEN STR_TO_DATE(
            '4/20/2020 22:09',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 14 THEN STR_TO_DATE(
            '8/1/2019 22:38',
            '%m/%d/%Y %H:%i'
        )
        WHEN ID = 15 THEN STR_TO_DATE(
            '6/19/2018 11:25',
            '%m/%d/%Y %H:%i'
        )
    END
WHERE ID BETWEEN 1 AND 15;

UPDATE account
SET
    expirationmonth = CASE
        WHEN ID = 1 THEN 8 
        WHEN ID = 2 THEN 6 
        WHEN ID = 3 THEN 10 
        WHEN ID = 4 THEN 3 
        WHEN ID = 5 THEN 3 
        WHEN ID = 6 THEN 4 
        WHEN ID = 7 THEN 10 
        WHEN ID = 8 THEN 3 
        WHEN ID = 9 THEN 8 
        WHEN ID = 10 THEN 7 
        WHEN ID = 11 THEN 7 
        WHEN ID = 12 THEN 10 
        WHEN ID = 13 THEN 9 
        WHEN ID = 14 THEN 5 
        WHEN ID = 15 THEN 8 
        WHEN ID = 16 THEN 9 
        WHEN ID = 17 THEN 7 
        WHEN ID = 18 THEN 5 
        WHEN ID = 19 THEN 2 
        WHEN ID = 20 THEN 8 
        WHEN ID = 21 THEN 2 
        WHEN ID = 22 THEN 12 
        WHEN ID = 23 THEN 9 
        WHEN ID = 24 THEN 3
        WHEN ID = 25 THEN 3  
    END
WHERE ID BETWEEN 1 AND 25;

--temp tables
CREATE TEMPORARY TABLE temp_artist_sales AS
SELECT
    a.name AS artist_name,
    COUNT(s.ID) AS total_sales,
    SUM(s.price) AS total_revenue
FROM artist a
    INNER JOIN events e ON a.ID = e.artistid
    INNER JOIN tickets t ON e.ID=t.eventid
    INNER JOIN sale s ON t.ID = s.ticketid
GROUP BY a.ID;

Select *
From temp_artist_sales;

CREATE TEMPORARY TABLE temp_high_revenue_sales AS
SELECT *
FROM sale
WHERE price >= 100;

Select *
From temp_high_revenue_sales; 

--regarding indexes:
--I already have my id columns in every table as index because they are primary and foreign keys. And because it would create complications when entering data to 
--tables, I don't want to add extra indexes. While I am a big fan of indexes, I believe ID columns should be enough.
--Still, if you want to see an example:
CREATE INDEX idx_eventdates ON events (eventdates);

--views
CREATE VIEW artist_revenue_view AS 
	SELECT
	    a.id, a.name AS artist_name,
	    e.ID AS event_id,
	    COUNT(s.ID) AS total_sales,
	    SUM(s.price) AS total_revenue
	FROM artist a
	    INNER JOIN events e ON a.ID = e.artistid
	    INNER JOIN tickets t ON e.ID = t.eventid
	    INNER JOIN sale s ON t.ID = s.ticketid
	GROUP BY a.ID, a.name, e.ID; 

CREATE VIEW revenue_per_customer AS 
Select c.id,c.firstname, c.lastname,COUNT(s.ticketid) as sale_per_customer, SUM(s.price) AS revenue_per_customer
FROM sale s inner join customer c ON s.customerid=c.ID
Group by c.id,c.firstname, c.lastname;

--tickets sold per venue, avg vs sum
CREATE VIEW tickets_sold_per_venue as
with avg_per_event as(
    Select venueid,ROUND(avg(ticketssold),2) as avg_tickets_sold
    From events
    Group by venueid
)
Select e.venueid, ROUND(sum(ticketssold),2) as sum_tickets_sold, a.avg_tickets_sold 
From events e inner join avg_per_event a ON e.venueid=a.venueid
Group by e.venueid; 

--which promoter sells the most tickets
CREATE VIEW promoter_success AS
Select e.promoterid,p.name, ROUND(sum(e.ticketssold),2) as sum_tickets_sold 
From events e inner join promoter p ON e.promoterid=p.ID
Where e.promoterid<>16
Group by e.promoterid,p.name; 

--I realized I didn't AUTO_INCREMENT my id columns, so here I am fixing those:
alter table tickets drop constraint tickets_ibfk_1;
ALTER TABLE events MODIFY ID int AUTO_INCREMENT;
alter table tickets add constraint foreign key (eventid) references events (ID);

alter table sale drop constraint sale_ibfk_3;
ALTER TABLE `account` MODIFY ID int AUTO_INCREMENT;
alter table sale add constraint foreign key (accountid) references `account` (ID);

alter table events drop constraint events_ibfk_2;
ALTER TABLE `artist` MODIFY ID int AUTO_INCREMENT;
alter table events add constraint foreign key (artistid) references `artist` (ID);

alter table `account` drop constraint account_ibfk_1;
alter table `sale` drop constraint sale_ibfk_1; 
ALTER TABLE customer MODIFY ID int AUTO_INCREMENT;
alter table `account` add constraint foreign key (customerid) references `customer` (ID);
alter table sale add constraint foreign key (customerid) references `customer` (ID);

alter table artist drop constraint artist_ibfk_1;
alter table events drop constraint events_ibfk_3;
ALTER TABLE `promoter` MODIFY ID int AUTO_INCREMENT;
alter table artist add constraint foreign key (promoterid) references promoter (ID);
alter table events add constraint foreign key (promoterid) references promoter (ID);

ALTER TABLE sale MODIFY ID int AUTO_INCREMENT;

alter table tickets drop constraint tickets_ibfk_2;
alter table events drop constraint events_ibfk_1;
ALTER TABLE venue MODIFY ID int AUTO_INCREMENT;
alter table tickets add constraint foreign key (venueid) references venue (ID);
alter table events add constraint foreign key (venueid) references venue (ID);

alter table sale drop constraint sale_ibfk_2;
ALTER TABLE tickets MODIFY ID int AUTO_INCREMENT;
alter table sale add constraint foreign key (ticketid) references tickets (ID);

--SHOW INDEXES FROM events
--on delete cascade
Select *
From ticketfaster.events;

INSERT INTO customer (firstname, lastname, username, address, city, state, zip, phone, email)
VALUES ('test1','test2','testtest','addresstest','citytest','GA','12345','111-222-3456','test@test.com');

Delete from customer where ID=26;

SELECT *
FROM
    INFORMATION_SCHEMA.COLUMNS
WHERE
    TABLE_NAME = 'customer'
    AND COLUMN_NAME = 'ID'
    AND DATA_TYPE = 'int'
    AND COLUMN_DEFAULT IS NULL
    AND IS_NULLABLE = 'NO'
    AND EXTRA like '%auto_increment%';

select max(id) from customer;

ALTER TABLE customer AUTO_INCREMENT = 26;
--repair table customer;
show customer status ;

INSERT INTO account (customerid, cardname, cardno, expirationmonth, expirationyr, lastmodified)
VALUES (32, 'Test Test', '1234567812345678',3,2028, CURRENT_TIMESTAMP);

SELECT
    e.name as event,
    e.eventdates,
    v.name as venue,
    a.name as artist
FROM events e
    INNER JOIN venue v ON e.venueid = v.id
    INNER JOIN artist a ON e.artistid = a.id;
