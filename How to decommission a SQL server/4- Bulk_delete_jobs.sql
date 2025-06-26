USE msdb;
GO

IF OBJECT_ID('dbo.usp_DeleteSQLJobs', 'P') IS NOT NULL
    DROP PROCEDURE dbo.usp_DeleteSQLJobs;
GO

CREATE PROCEDURE dbo.usp_DeleteSQLJobs
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @job_id UNIQUEIDENTIFIER;
    DECLARE job_cursor CURSOR FOR
    SELECT job_id FROM msdb.dbo.sysjobs
    WHERE name NOT LIKE 'syspolicy%' 
    AND name NOT LIKE 'DatabaseMail%'
    -- Add more exclusions here if needed

    OPEN job_cursor;
    FETCH NEXT FROM job_cursor INTO @job_id;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC msdb.dbo.sp_delete_job @job_id = @job_id;
            PRINT 'Deleted job ID: ' + CAST(@job_id AS NVARCHAR(100));
        END TRY
        BEGIN CATCH
            PRINT 'Failed to delete job ID: ' + CAST(@job_id AS NVARCHAR(100)) + ' - ' + ERROR_MESSAGE();
        END CATCH;

        FETCH NEXT FROM job_cursor INTO @job_id;
    END;

    CLOSE job_cursor;
    DEALLOCATE job_cursor;

    SET NOCOUNT OFF;
END;
GO
