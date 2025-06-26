USE master;
GO

IF OBJECT_ID('dbo.usp_DeleteSQLLogins', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_DeleteSQLLogins;
GO

CREATE PROCEDURE dbo.usp_DeleteSQLLogins
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @login NVARCHAR(128);
    DECLARE login_cursor CURSOR FOR
    SELECT name FROM sys.server_principals 
    WHERE type_desc IN ('SQL_LOGIN', 'WINDOWS_LOGIN', 'WINDOWS_GROUP') 
    AND name NOT IN (
		'sa', 'NT AUTHORITY\SYSTEM', 
        'NT SERVICE\SQLSERVERAGENT', 
        'NT SERVICE\MSSQLSERVER',
		'NT SERVICE\Winmgmt',
		'NT SERVICE\SQLWriter',
		'NT SERVICE\SQLTELEMETRY',
		'NT SERVICE\SQLServerReportingServices',
		'NT AUTHORITY\SYSTEM'
	);

    OPEN login_cursor;
    FETCH NEXT FROM login_cursor INTO @login;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC sp_droplogin @login;
            PRINT 'Dropped login: ' + @login;
        END TRY
        BEGIN CATCH
            PRINT 'Failed to drop login: ' + @login + ' - ' + ERROR_MESSAGE();
        END CATCH;

        FETCH NEXT FROM login_cursor INTO @login;
    END;

    CLOSE login_cursor;
    DEALLOCATE login_cursor;

    SET NOCOUNT OFF;
END;
GO


