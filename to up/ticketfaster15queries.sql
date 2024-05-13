-- Active: 1711937097451@@127.0.0.1@3306@ticketfaster

--account: ID, customerid, cardname, cardno,expirationmonth, expirationyr,lastmodified 
--customer: ID, firstname,lastname, username, address, city,state, zip, phone, email,lastmodified
--events: ID, name,type,venueid,artistid,promoterid,eventdates,ticketssold,lastmodified
--venue: ID,name, type, capacity, address, city, state, zip, url,contact, phone, email, lastmodified 
--artist: ID,name,genre,promoterid,lastmodified 
--promoter: ID,name,parentcompany,contact,phone,email 
--tickets: ID, eventid, venueid,zone,rown,seat,price,availability,minimumlimit, lastmodified 
--sale: ID,customerid,ticketid,price,accountid,saledate,lastmodified 
 -----
--1) assign a rank to each event 's total ticket sales per each promoter:
SELECT case when p.ID=16 then 'others' else e.name end AS event_name, p.name AS promoter_name, e.type AS event_type, 
SUM(e.ticketssold) AS total_ticket_sales, 
RANK() OVER (PARTITION BY p.ID ORDER BY SUM(e.ticketssold) DESC) AS ticket_sales_rank
FROM events e
    JOIN promoter p ON e.promoterid = p.ID
GROUP BY event_name, p.name, e.type, p.ID;

--2) to find the average ticket price for different event types: 
SELECT event_type, AVG(ticket_price) AS avg_ticket_price
FROM (SELECT e.type AS event_type, s.price AS ticket_price
        FROM events e
            JOIN tickets t ON e.ID = t.eventid
            JOIN sale s ON t.ID = s.ticketid
    ) AS event_ticket_prices
GROUP BY event_type;

--3) to get information about venues and their upcoming events in the next 2 months: 
SELECT v.name as venue_name, e.name as event_name, e.eventdates
FROM venue v JOIN events e ON v.ID = e.venueid
WHERE e.eventdates between CURRENT_DATE() and DATE_ADD(CURRENT_DATE(),INTERVAL 60 DAY);

--4)number of available, sold, and total tickets for each event per suite and nonsuite seats 
SELECT e.ID as eventid,e.name as eventname, COUNT(*) as totaltickets,
COUNT(CASE WHEN t.minimumlimit=0 AND t.availability = 0 THEN 1 END) as unsoldtickets,
COUNT(CASE WHEN t.minimumlimit=0 AND t.availability = 1 THEN 1 END) as soldtickets,
COUNT(CASE WHEN t.minimumlimit > 0 AND t.availability = 0 THEN 1 END) as unsoldsuitetickets,
COUNT(CASE WHEN t.minimumlimit > 0 AND t.availability = 1 THEN 1 END) as soldsuitetickets
FROM events e JOIN tickets t ON e.ID = t.eventid
GROUP BY e.ID, e.name;

--5)moving average of ticket prices for each ticket, based on the ticket immediately before and after it
SELECT ID, price, lastmodified, AVG(price) OVER (ORDER BY lastmodified ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) AS moving_average
FROM tickets
ORDER BY lastmodified;

--6)running total of tickets sold per event ordered by the event date
SELECT name, eventdates, ticketssold, SUM(ticketssold) OVER (PARTITION BY name ORDER BY eventdates ROWS UNBOUNDED PRECEDING) AS running_total
FROM events
ORDER BY name, eventdates;

--7)running total of tickets sold per artist ordered by the event date for concerts
SELECT a.name as artistname,e.name as eventname,e.eventdates,e.ticketssold, 
SUM(e.ticketssold) OVER (PARTITION BY e.name ORDER BY eventdates ROWS UNBOUNDED PRECEDING) AS running_total
FROM events e inner join artist a ON e.artistid=a.ID
Where a.ID<>25
ORDER BY a.name,e.name, eventdates;

--8) running sum of price (revenue) per event
SELECT e.name AS eventname,s.saledate,s.price, SUM(s.price) OVER (ORDER BY s.saledate ROWS UNBOUNDED PRECEDING) AS running_total
FROM tickets t
    JOIN sale s ON t.ID = s.ticketid
    JOIN events e ON t.eventid = e.ID
ORDER BY s.saledate;

--9)ranking customers based on the number of tickets they've bought to maybe send future promotion emails
SELECT c.firstname, c.lastname, c.email, COUNT(s.ticketid) AS ticketsbought, DENSE_RANK() OVER (ORDER BY COUNT(s.ticketid) DESC) AS customerrank,
    ROUND(PERCENT_RANK() OVER (ORDER BY COUNT(s.ticketid) DESC),2)*100 AS customerpercentrank
FROM customer c JOIN sale s ON c.ID = s.customerid
GROUP BY c.ID, c.firstname, c.lastname, c.email
ORDER BY ticketsbought DESC;

--10) analyzing ticket prices accumulating across seat locations 
SELECT e.name AS EventName, t.zone, t.rown, t.seat, t.price,
    CUME_DIST() OVER (PARTITION BY e.ID, t.zone ORDER BY t.price) AS pricecumedist
FROM tickets t JOIN events e ON t.eventid = e.ID
ORDER BY e.ID, t.zone, t.price;

--11) categorizing ticket prices within each event into quartiles 
SELECT e.name AS EventName,t.price, NTILE(4) OVER (PARTITION BY e.ID ORDER BY t.price) AS pricequartile
FROM tickets t JOIN events e ON t.eventid = e.ID
ORDER BY e.ID, t.price;

--12) 3 day moving average of ticket sales per artist 
WITH salesbyartist AS (
        SELECT a.name AS artistname, e.eventdates AS eventdate, SUM(e.ticketssold) AS ticketssold 
        FROM events e JOIN artist a ON e.artistid = a.ID
        GROUP BY a.name, e.eventdates
    )
SELECT artistname, eventdate, ticketssold, 
AVG(ticketssold) OVER (PARTITION BY artistname ORDER BY eventdate RANGE BETWEEN INTERVAL '2' DAY PRECEDING AND CURRENT ROW ) AS threedaymovingavg
FROM salesbyartist 
ORDER BY artistname, eventdate;

--13) tracking the price of the tickets customers buy and compare each purchase with their next purchase
SELECT c.firstname, c.lastname, s.saledate, 
t.price AS firstticketprice, LEAD(t.price, 1) OVER (PARTITION BY s.customerid ORDER BY s.saledate) AS nextticketprice,
LEAD(s.saledate, 1) OVER (PARTITION BY s.customerid ORDER BY s.saledate) AS nextpurchasedate
FROM sale s JOIN tickets t ON s.ticketid = t.ID
    JOIN customer c ON s.customerid = c.ID
ORDER BY c.lastname, c.firstname, s.saledate;

--14) analyzing customer's purchase history by ticket prices  
--(of course my database is small so normally I would include a filter to eliminate the same event)
SELECT c.firstname, c.lastname, s.saledate, e.name AS eventname, t.price AS firstticketprice,
LAG(t.price, 1) OVER (PARTITION BY s.customerid ORDER BY s.saledate) AS previousticketprice,
t.price - LAG(t.price, 1) OVER (PARTITION BY s.customerid ORDER BY s.saledate) AS pricechange
FROM sale s JOIN tickets t ON s.ticketid = t.ID
    JOIN events e ON t.eventid = e.ID
    JOIN customer c ON s.customerid = c.ID
ORDER BY c.lastname, c.firstname, s.saledate;

--15) Analyzing event performance per venue and date
SELECT v.name AS venuename, e.name AS eventname, e.eventdates, e.ticketssold, 
RANK() OVER (PARTITION BY v.name ORDER BY e.ticketssold DESC) AS ticketssoldrank,
LAG(e.ticketssold, 1) OVER (PARTITION BY v.name ORDER BY e.eventdates) AS previouseventtickets,
e.ticketssold - LAG(e.ticketssold, 1) OVER (PARTITION BY v.name ORDER BY e.eventdates) AS changefrompreviousevent
FROM events e JOIN venue v ON e.venueid = v.ID
ORDER BY v.name, e.eventdates;
/*
SELECT group_concat(COLUMN_NAME)
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'ticketfaster'
AND TABLE_NAME = 'sale';
*/

Select *
From customer;

SELECT
    e.name as event,
    e.eventdates,
    v.name as venue,
    a.name as artist
FROM events e
    inner join venue v ON e.venueid = v.id
    inner join artist a ON e.artistid = a.id
ORDER BY eventdates ASC


