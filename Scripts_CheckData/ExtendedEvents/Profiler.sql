SELECT pkg.name AS PkgName, 
  pkg.description as PkgDescr, 
  obj.name as EventName, 
  obj.description as EventDescr
FROM sys.dm_xe_objects obj
  inner join sys.dm_xe_packages pkg ON pkg.guid = obj.package_guid
WHERE obj.object_type='event'  -- and  obj.name like '%erro%' --obj.description like '%statement%'
  and pkg.name NOT IN ('qds', 'ucs', 'SecAudit');


USE [bodb02];

IF NOT EXISTS (SELECT 1 FROM fn_my_permissions(NULL, 'SERVER') where permission_name = 'ALTER ANY EVENT SESSION') 
   OR NOT EXISTS (SELECT 1 FROM fn_my_permissions(NULL, 'SERVER') where permission_name = 'VIEW SERVER STATE')  
BEGIN
    SELECT 'Don''t have ALTER ANY EVENT SESSION permission ' 
    RETURN
END 


IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'XXXX_Profiler') DROP EVENT SESSION XXXX_Profiler ON SERVER;


CREATE EVENT SESSION [XXXX_Profiler] ON SERVER 
ADD EVENT sqlserver.rpc_completed( SET collect_statement = 1 
    ACTION(package0.last_error,sqlserver.database_id,sqlserver.database_name,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text)
    WHERE (
               [statement] like '%70084833%' 
         )
),
ADD EVENT sqlserver.sp_statement_completed( SET collect_statement = 1 
    ACTION(package0.last_error,sqlserver.database_id,sqlserver.database_name,sqlserver.server_principal_name,sqlserver.session_id,sqlserver.sql_text)
    WHERE (
               [statement] like '%70084833%' 
         )
)
ADD TARGET package0.ring_buffer(SET max_memory=(5120))
WITH (MAX_DISPATCH_LATENCY=1 SECONDS, TRACK_CAUSALITY = ON)

GO

ALTER EVENT SESSION [XXXX_Profiler] ON SERVER STATE = START; 



WITH xe(Events) AS (
    SELECT top 2 CAST(xest.target_data as xml)
    FROM sys.dm_xe_session_targets xest  
    JOIN sys.dm_xe_sessions xes ON xes.address = xest.event_session_address  
    WHERE xest.target_name = 'ring_buffer' AND xes.name = 'XXXX_Profiler'
)
SELECT  Timestamp    = x1.evnt.value('@timestamp','datetimeoffset')
    ,   SQL_Text  = x1.evnt.value('(data[@name="statement"]/value/text())[1]','NVARCHAR(MAX)')
    ,   duration  = x1.evnt.value('(data[@name="duration"]/value/uint64)[1]','INT')
--    ,   Events
FROM xe
CROSS APPLY xe.Events.nodes('RingBufferTarget/event') x1(evnt);



ALTER EVENT SESSION [XXXX_Profiler] ON SERVER STATE = STOP; 

