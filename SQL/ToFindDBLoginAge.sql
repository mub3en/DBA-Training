
-- Find databases that haven't been logged into for 6 months or more,
IF OBJECT_ID('TempDB..#Temp', 'U') > 0 DROP TABLE #Temp
CREATE TABLE #Temp (DBName VARCHAR(255), AppServer VARCHAR(500), firstname VARCHAR(500), lastname VARCHAR(500), email VARCHAR(500), contactID INT, username VARCHAR(500), LastLoginDate DATETIME, IPAddress VARCHAR(500) )
INSERT INTO #Temp
EXEC sys.sp_MSforeachdb 
'IF ''?''  NOT IN (''tempDB'',''model'',''msdb'', ''master'')
USE ?
IF EXISTS (SELECT 1 FROM sys.objects WHERE name = ''UserAccess'') 
SELECT TOP 1 db_name() as ''dbname'',    
		 (SELECT Value FROM [Client].[ClientSetting] WHERE Name = ''MasterServer'') AS AppServer,
		 c.[FirstName],
         c.[LastName],
		 c.[Email],
         u.[ContactID],
         u.[UserName],
         ua.[LastLoginDate],
         ua.[IpAddress]
FROM [Audit].[UserAccess] ua
JOIN [Security].[User]    u ON u.[ContactID] = ua.[UserID]
JOIN [Client].[Contact]   c ON c.ID = u.[ContactID]
WHERE NOT EXISTS 
	(SELECT ua.[UserID]
	FROM [Audit].[UserAccess] ua
	JOIN [Security].[User]    u ON u.[ContactID] = ua.[UserID]
	JOIN [Client].[Contact]   c ON c.ID = u.[ContactID]
	WHERE ua.[LastLoginDate]  > DATEADD(mm, -6, getdate()) 
	)
ORDER BY ua.[LastLoginDate] DESC;'
--select * from #Temp;
--drop table #Temp

SELECT D.create_date as db_create_date, T.LastLoginDate, T.* 
FROM #Temp T
JOIN sys.databases D on D.name = T.dbname
where d.create_date < DATEADD(mm, -6, getdate()) 
order by t.LastLoginDate desc;

