USE master;
GO

-- Create the stored procedure
IF OBJECT_ID('dbo.usp_BulkBackupDatabases', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_BulkBackupDatabases;
GO

CREATE PROCEDURE dbo.usp_BulkBackupDatabases
AS
BEGIN
    SET NOCOUNT ON;

    -- Enabling advanced options and xp_cmdshell
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;

    EXEC sp_configure 'xp_cmdshell', 1;
    RECONFIGURE;

    -- Create a table to log backup failures
    IF OBJECT_ID('tempdb..#BackupFailures') IS NOT NULL DROP TABLE #BackupFailures;
    CREATE TABLE #BackupFailures (
        DatabaseName NVARCHAR(128),
        ErrorMessage NVARCHAR(MAX),
        BackupTime DATETIME DEFAULT GETDATE()
    );

    -- Define backup path
    DECLARE @dbName NVARCHAR(128);
    DECLARE @BackupPath NVARCHAR(300) = 'C:\SQLBulkBackups\';
    
    -- Check if the backup folder exists, if not, create it
    IF NOT EXISTS (
        SELECT 1
        FROM sys.master_files
        WHERE physical_name LIKE @BackupPath + '%'
    )
    BEGIN
        EXEC xp_cmdshell 'mkdir C:\SQLBulkBackups\';
    END

    -- Loop through all databases and perform backups
    DECLARE db_cursor CURSOR FOR
    SELECT name 
    FROM sys.databases 
    WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb', 'ReportServer', 'ReportServerTempDB') 
    AND state_desc = 'ONLINE';

    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @dbName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            DECLARE @backupFile NVARCHAR(300) = @BackupPath + @dbName + '_' + CONVERT(NVARCHAR(20), GETDATE(), 112) + '.bak';

            -- Perform backup
            BACKUP DATABASE @dbName 
            TO DISK = @backupFile 
            WITH INIT, STATS = 10, CHECKSUM;

            PRINT 'Backup successful for database: ' + @dbName;
        END TRY
        BEGIN CATCH
            INSERT INTO #BackupFailures (DatabaseName, ErrorMessage)
            VALUES (@dbName, ERROR_MESSAGE());

            PRINT 'Backup failed for database: ' + @dbName;
        END CATCH;

        FETCH NEXT FROM db_cursor INTO @dbName;
    END;

    CLOSE db_cursor;
    DEALLOCATE db_cursor;

    -- Review any failures
    SELECT * FROM #BackupFailures;

    -- Disable xp_cmdshell
    EXEC sp_configure 'xp_cmdshell', 0;
    RECONFIGURE;
    
    SET NOCOUNT OFF;
END;
GO