-- https://www.sqlservercentral.com/articles/tempdb-growth-due-to-version-store-on-alwayson-secondary-server
-- https://sqlgeekspro.com/tempdb-growth-due-to-version-store-in-alwayson/
-- https://sqlperformance.com/2021/08/sql-performance/append-only-storage-insert-point-latch

-- 1: check versionstore usage (last column of resultset, this should be a low number, typically a few GB or less, if higher, that's an indication that versionstore is not being freed up)
use tempdb;
SELECT GETDATE() AS runtime,@@servername as 'servername',
    SUM(user_object_reserved_page_count) * 8 AS usr_obj_kb,
    SUM(internal_object_reserved_page_count) * 8 AS internal_obj_kb,
    SUM(version_store_reserved_page_count) * 8 AS version_store_kb,
    SUM(unallocated_extent_page_count) * 8 AS freespace_kb,
    SUM(mixed_extent_page_count) * 8 AS mixedextent_kb,
    (SUM(version_store_reserved_page_count))/1024/1024 * 8 AS version_store_GB
FROM sys.dm_db_file_space_usage;

-- 2: checked build-up of tempdb used space in each data file. Another indication that versionstore is building up and causing tempdb space to not be freed up.
use tempdb;
SELECT @@servername, db_name(), getdate() as 'CurrentDate',
    CAST( ( ( CAST(size AS DECIMAL)/128.0 ) - CAST(FILEPROPERTY(name, 'SpaceUsed' )AS DECIMAL)/128.0 ) / (CAST(size AS DECIMAL)/128 ) * 100 AS INT) AS PCTFREE,
    name AS 'NameOfFile',
    CAST((CAST(size AS DECIMAL)/128.0) / 1024 AS INT) AS 'TotalsizeInGB', 
    CAST((CAST(max_size AS DECIMAL)/128.0) / 1024 AS INT) AS 'MaxSizeInGB', 
    CAST((CAST(FILEPROPERTY(name, 'SpaceUsed' )AS int)/128.0) / 1024 AS INT) AS 'SpaceUsedGB',
    CAST((CAST(size AS DECIMAL)/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed' )AS int)/128.0) / 1024 AS INT) AS 'AvailableSpaceInGB', 
    physical_name, growth
FROM sys.database_files f with(nolock)
order by CAST( ( ( CAST(size AS DECIMAL)/128.0 ) - CAST(FILEPROPERTY(name, 'SpaceUsed' )AS DECIMAL)/128.0 ) / (CAST(size AS DECIMAL)/128 ) * 100 AS INT) 
GO



-- 3: run on primary to find long-running, and look at last batch to see which is oldest and sleeping. Copy the spid into the next query to see what sql stmt it's running
SELECT GETDATE() AS runtime, a.elapsed_time_seconds/60/60.0 as hours_tran_has_been_open,b.kpid  ,b.blocked  ,b.lastwaittype ,b.waitresource ,db_name(b.dbid) AS database_name,
    b.cpu,b.physical_io ,b.memusage ,b.login_time   ,b.last_batch   ,b.open_tran    ,b.STATUS   ,b.hostname ,b.program_name
    ,b.cmd  ,b.loginame ,request_id, a.*    
FROM sys.dm_tran_active_snapshot_database_transactions a
INNER JOIN sys.sysprocesses b ON a.session_id = b.spid;

-- 3b: additional join to dm_tran_active_snapshot_database_transactions
SELECT
s.elapsed_time_seconds/60/60.0 as hours_tran_has_been_open,  
s.session_id,
t.transaction_id, 
t.name,t.transaction_type, 
t.transaction_state,
s.transaction_id,
p.status, 
p.cmd, p.login_time, p.loginame, p.hostname, p.program_name, p.open_tran
FROM sys.dm_tran_active_transactions t
JOIN sys.dm_tran_active_snapshot_database_transactions s ON t.transaction_id = s.transaction_id
JOIN sys.sysprocesses p ON p.spid = s.session_id


-- 4: paste spid from above query into statement below, and pull out the sql stmt into ticket, and also take screenshots of active transaction, to give to FA/NAV/ACC team.
-- consult with escalation team or whoever before killing spid. If after hours and no one able to approve, and tempdb is filling, you'll need to kill without approval, but
-- file a retro change request. If you wait for tempdb to fill, that will bring the server down, and all the clients with it. No bueno.
exec sp_whoisactive @filter_type = 'session', @filter = '909'; -- replace 909 with the spid you captured from step #3 above.
