USE master;
GO

-- Drop the procedure if it already exists
IF OBJECT_ID('dbo.usp_BulkRestoreDatabases', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_BulkRestoreDatabases;
GO

CREATE PROCEDURE dbo.usp_BulkRestoreDatabases
    @BackupFolder NVARCHAR(260) -- Path to the folder containing the backup (.bak) files
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @backupFile NVARCHAR(260);
    DECLARE @restoreCommand NVARCHAR(MAX);

    -- Temporary table to hold the list of backup files
    CREATE TABLE #BackupFiles (
        BackupFile NVARCHAR(260)
    );

    -- Find backup files in the folder using xp_cmdshell and insert them into #BackupFiles table
    -- Make sure xp_cmdshell is enabled
    INSERT INTO #BackupFiles (BackupFile)
    EXEC xp_cmdshell 'dir /b /a-d "' + @BackupFolder + '\*.bak"';

    -- Filter out any NULL rows created by xp_cmdshell
    DELETE FROM #BackupFiles WHERE BackupFile IS NULL;

    -- Cursor to iterate through each backup file in the directory
    DECLARE restore_cursor CURSOR FOR
    SELECT BackupFile FROM #BackupFiles;

    OPEN restore_cursor;
    FETCH NEXT FROM restore_cursor INTO @backupFile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Dynamically build the restore command
            -- Assuming the database name is the same as the backup file name (without the ".bak" extension)
            DECLARE @databaseName NVARCHAR(128);
            SET @databaseName = REPLACE(@backupFile, '.bak', '');

            -- Restore the database
            SET @restoreCommand = '
                RESTORE DATABASE [' + @databaseName + '] 
                FROM DISK = ''' + @BackupFolder + '\' + @backupFile + ''' 
                WITH 
                    NORECOVERY, -- Use WITH NORECOVERY if restoring differential or logs afterward; otherwise use RECOVERY
                    REPLACE, -- Overwrite existing database if it exists
                    MOVE ''' + @databaseName + '_Data'' TO ''C:\Databases\' + @databaseName + '_Data.mdf'', 
                    MOVE ''' + @databaseName + '_Log'' TO ''C:\Databases\' + @databaseName + '_Log.ldf''';
            
            -- Execute the restore command
            EXEC sp_executesql @restoreCommand;

            PRINT 'Successfully restored database: ' + @databaseName;
        END TRY
        BEGIN CATCH
            PRINT 'Failed to restore database from file: ' + @backupFile + ' - ' + ERROR_MESSAGE();
        END CATCH;

        FETCH NEXT FROM restore_cursor INTO @backupFile;
    END;

    CLOSE restore_cursor;
    DEALLOCATE restore_cursor;

    -- Cleanup temporary table
    DROP TABLE #BackupFiles;

    SET NOCOUNT OFF;
END;
GO
