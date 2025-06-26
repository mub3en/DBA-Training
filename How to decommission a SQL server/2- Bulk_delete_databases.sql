USE master;
GO

-- Create the stored procedure if it doesn't exist
IF OBJECT_ID('dbo.usp_BulkDeleteDatabases', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_BulkDeleteDatabases;
GO

CREATE PROCEDURE dbo.usp_BulkDeleteDatabases
AS
BEGIN
    SET NOCOUNT ON;
	-- Drop user databases with SINGLE_USER mode
	DECLARE @sql NVARCHAR(MAX);
	DECLARE @dbName NVARCHAR(128);
	DECLARE drop_cursor CURSOR FOR
	SELECT name FROM sys.databases
	WHERE name NOT IN ('master', 'model', 'msdb', 'tempdb','ReportServer', 'ReportServerTempDB')
	AND state_desc = 'ONLINE';

	OPEN drop_cursor;
	FETCH NEXT FROM drop_cursor INTO @dbName;

	WHILE @@FETCH_STATUS = 0
	BEGIN
		BEGIN TRY
				-- Set the database to SINGLE_USER mode before deleting (force disconnection)
			SET @sql = 'ALTER DATABASE [' + @dbName + '] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;';
			EXEC sp_executesql @sql;

			-- Drop the database
			SET @sql = 'DROP DATABASE [' + @dbName + '];';
			EXEC sp_executesql @sql;

			PRINT 'Dropped database: ' + @dbName;

			-- Set the database back to MULTI_USER mode
			SET @sql = 'ALTER DATABASE [' + @dbName + '] SET MULTI_USER;';
			EXEC sp_executesql @sql;
		END TRY
		BEGIN CATCH
			PRINT 'Failed to drop database: ' + @dbName + ' - ' + ERROR_MESSAGE();
		END CATCH;

		FETCH NEXT FROM drop_cursor INTO @dbName;
	END;

	CLOSE drop_cursor;
	DEALLOCATE drop_cursor;  

    SET NOCOUNT OFF;
END;
GO
