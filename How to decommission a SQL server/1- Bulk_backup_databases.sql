USE master;
GO

-- Create the stored procedure
IF OBJECT_ID('dbo.usp_BulkBackupDatabasesAndLogs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_BulkBackupDatabasesAndLogs;
GO

CREATE PROCEDURE dbo.usp_BulkBackupDatabasesAndLogs
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
        BackupType NVARCHAR(50),
        ErrorMessage NVARCHAR(MAX),
        BackupTime DATETIME DEFAULT GETDATE()
    );

    -- Define backup path
    DECLARE @dbName NVARCHAR(128);
    DECLARE @FullBackupPath NVARCHAR(300) = 'C:\SQLBulkBackups\Full\';
    DECLARE @LogBackupPath NVARCHAR(300) = 'C:\SQLBulkBackups\Log\';
    
    -- Check if the Full and Log backup folders exist, if not, create them
    IF NOT EXISTS (
        SELECT 1
        FROM sys.master_files
        WHERE physical_name LIKE @FullBackupPath + '%'
    )
    BEGIN
        EXEC xp_cmdshell 'mkdir C:\SQLBulkBackups\Full\';
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.master_files
        WHERE physical_name LIKE @LogBackupPath + '%'
    )
    BEGIN
        EXEC xp_cmdshell 'mkdir C:\SQLBulkBackups\Log\';
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
            -- FULL BACKUP
            DECLARE @fullBackupFile NVARCHAR(300) = @FullBackupPath + @dbName + '_Full_' + CONVERT(NVARCHAR(20), GETDATE(), 112) + '.bak';

            BACKUP DATABASE @dbName 
            TO DISK = @fullBackupFile 
            WITH INIT, STATS = 10, CHECKSUM;

            PRINT 'Full backup successful for database: ' + @dbName;

            -- Log success for Full Backup in table
            INSERT INTO #BackupFailures (DatabaseName, BackupType, BackupTime)
            VALUES (@dbName, 'Full', GETDATE());

            -- TRANSACTION LOG BACKUP
            DECLARE @logBackupFile NVARCHAR(300) = @LogBackupPath + @dbName + '_Log_' + CONVERT(NVARCHAR(20), GETDATE(), 112) + '.trn';

            BACKUP LOG @dbName 
            TO DISK = @logBackupFile 
            WITH INIT, STATS = 10, CHECKSUM;

            PRINT 'Transaction Log backup successful for database: ' + @dbName;

            -- Log success for Log Backup in table
            INSERT INTO #BackupFailures (DatabaseName, BackupType, BackupTime)
            VALUES (@dbName, 'Transaction Log', GETDATE());
        END TRY
        BEGIN CATCH
            -- Log failure for Full Backup or Transaction Log Backup
            INSERT INTO #BackupFailures (DatabaseName, BackupType, ErrorMessage, BackupTime)
            VALUES (@dbName, CASE WHEN ERROR_MESSAGE() LIKE '%LOG%' THEN 'Transaction Log' ELSE 'Full' END, ERROR_MESSAGE(), GETDATE());

            PRINT 'Backup failed for database: ' + @dbName + ' - ' + ERROR_MESSAGE();
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
