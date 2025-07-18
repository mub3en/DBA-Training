-- query to parse out clientname from dbname, and group by that, to see how many
-- clients have more than 4 db's across CSAD (they are supposed to have 2 QA db's and 2 Dev dbs')

--drop table #temp

CREATE table #temp  (servername sysname, dbname sysname, clientname varchar(256) NULL, clientCount INT NULL)
INSERT INTO #temp
(servername, dbname, clientname, clientCount)
SELECT @@servername, db_name() as dbname, CASE
	WHEN ( LEN(d.name) - LEN(REPLACE(d.name, '_', '')) ) > 1
	THEN
	SUBSTRING (d.name, 
	(CHARINDEX('_', d.name) + 1), 
	((CHARINDEX('_', d.name, CHARINDEX('_', d.name) + 1) ) - (CHARINDEX('_', d.name ))) - 1 ) END as clientname, 
	count(*) as clientCount
from sys.databases d 
where database_id > 4 and name not in ('ssadmin')
group by CASE
	WHEN ( LEN(d.name) - LEN(REPLACE(d.name, '_', '')) ) > 1
	THEN
	SUBSTRING (d.name, 
	(CHARINDEX('_', d.name) + 1), 
	((CHARINDEX('_', d.name, CHARINDEX('_', d.name) + 1) ) - (CHARINDEX('_', d.name ))) - 1 ) END 
having count(*) > 4

select  t.clientname, t.clientCount, d.state_desc
from #temp t
join sys.databases d on d.name = t.dbname
where clientname is not null
