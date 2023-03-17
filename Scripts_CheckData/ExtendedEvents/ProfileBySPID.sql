
IF NOT EXISTS (SELECT 1 FROM fn_my_permissions(NULL, 'SERVER') where permission_name = 'ALTER ANY EVENT SESSION') 
   OR NOT EXISTS (SELECT 1 FROM fn_my_permissions(NULL, 'SERVER') where permission_name = 'VIEW SERVER STATE')  
BEGIN
    SELECT 'Don''t have ALTER ANY EVENT SESSION permission ' 
    RETURN
END 

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'Aries_Profiler_SPID') DROP EVENT SESSION XXXX_Profiler_SPID ON SERVER;

CREATE EVENT SESSION [XXXX_Profiler_SPID] ON SERVER 
ADD EVENT sqlserver.rpc_completed(SET collect_statement = 1 WHERE (session_id = 247)),
ADD EVENT sqlserver.sp_statement_completed(  SET collect_statement = 1 WHERE (session_id = 247)), 
ADD EVENT sqlserver.sql_statement_completed(WHERE (session_id = 318)),
ADD EVENT sqlserver.sp_statement_starting(WHERE ([statement] like '%exec%'  AND session_id = 247)),
ADD EVENT sqlserver.sql_statement_starting(WHERE ([statement] like '%exec%'  AND  session_id = 247)),
ADD EVENT sqlserver.error_reported(WHERE (session_id = 247))
ADD TARGET package0.event_file(SET  filename=N'XXXX_Profiler_SPID-.xel',max_rollover_files=0)

WITH (MAX_DISPATCH_LATENCY=1 SECONDS, TRACK_CAUSALITY = ON)

GO

ALTER EVENT SESSION [XXXX_Profiler_SPID] ON SERVER STATE = START; 


WITH xe(Events) AS (
    SELECT CAST(f.event_data AS XML) 
    FROM sys.fn_xe_file_target_read_file('XXXX_Profiler_SPID-*.xel',null, null, null) AS f
)
SELECT  Timestamp    = x1.evnt.value('@timestamp','datetimeoffset')
    ,   ErrorMessage = IIF(x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)') like '%catch%','BEGIN CATCH', x1.evnt.value('(data[@name="message"]/value/text())[1]','NVARCHAR(MAX)'))
    ,   EventName    = IIF(x1.evnt.value('@name','NVARCHAR(100)') like '%completed%' , IIF( x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)') like '%exec%','Completed',''), IIF( x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)') like '%exec%','Starting',''))
    ,   ExecSP       = IIF(x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)') like '%exec%', 'ExecSP','')
    ,   LineNumber   = ISNULL(x1.evnt.value('(data[@name="line_number"]/value/text())[1]','INT'),IIF(x1.evnt.value('(data[@name="message"]/value/text())[1]','NVARCHAR(MAX)') IS NOT NULL,9999,0))
    ,   SQLText      = x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)')
    --,   Duration     = ISNULL(x1.evnt.value('(data[@name="duration"]/value/text())[1]','INT'),0)
    
    --  ,   Events
FROM xe
CROSS APPLY xe.Events.nodes('event') x1(evnt)
ORDER BY Timestamp ASC, LineNumber ASC;


ALTER EVENT SESSION [XXXX_Profiler_SPID] ON SERVER STATE = STOP; 
