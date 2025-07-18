-- Correct declaration and assignment of variable
DECLARE @dbname VARCHAR(50); 
SET @dbname = '$DBNAME$'; 

-- Query 1: Logical files and size information
SELECT 
    db.name AS DatabaseName,
    mf.name AS LogicalFileName,
    mf.type_desc AS FileType, 
    CAST(mf.size AS BIGINT) * 8 / 1024 AS SizeInMB, -- Size in MB
    CAST(mf.max_size AS BIGINT) * 8 / 1024 AS MaxSizeInMB -- Max size in MB
FROM sys.master_files mf
INNER JOIN sys.databases db ON db.database_id = mf.database_id
WHERE db.name LIKE @dbname
ORDER BY DatabaseName, FileType;

-- Query 2: Total size in MB and GB
SELECT 
    db.name AS DatabaseName,
    SUM(CAST(mf.size AS BIGINT) * 8 / 1024) AS TotalSizeInMB, -- Total size in MB
    SUM(CAST(mf.size AS BIGINT) * 8 / 1024 / 1024) AS TotalSizeInGB -- Total size in GB
FROM sys.master_files mf
INNER JOIN sys.databases db ON db.database_id = mf.database_id
WHERE db.name LIKE @dbname
GROUP BY db.name
ORDER BY db.name;
