/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLog_Sel
AS
/*
	Created:20220913@Louisa
    Task: Tool support delete locking [RedmineId:#177711]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20220913@Louisa: Get log in waiting/running/fail from SiteDB_SettlementService_LastLog [RedmineId:#177711]
		- 20221122@Louisa: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
	
	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @TimeChecking	INT			 = 3
			,@ServerName	VARCHAR(100) = @@SERVERNAME

	DECLARE @tmpLastLogPending TABLE 
	(	LogID			BIGINT 
		, StartTime		DATETIME2
		, SystemName	VARCHAR(50)
		, FunctionName	VARCHAR(50)
		, TableName		VARCHAR(128)
		, Action		VARCHAR(1)
		, MatchId		INT
		, TransInfo		XML
		, TransInfoJson NVARCHAR(MAX)
		, LogDate		DATETIME2
		, SettlementAction  VARCHAR(20)
		, TicketType	VARCHAR(1)
	)

	INSERT INTO @tmpLastLogPending 
	(
		LogID			 
		, StartTime		 
		, SystemName	 
		, FunctionName	 
		, TableName		 
		, Action		 
		, MatchId		 
		, TransInfo		 
		, TransInfoJson  
		, LogDate		 
		, SettlementAction   
		, TicketType	 
	)
	SELECT ll.LogId
		, ll.Starttime	 
		, l.SystemName	 
		, l.FunctionName	 
		, l.TableName		 
		, l.Action		 
		, l.MatchId		 
		, l.TransInfo
		, CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX)) TransInfoJson
		, l.LogDate		 
		, l.SettlementAction  
		, l.TicketType	
	FROM dbo.SiteDB_SettlementService_LastLog ll WITH(NOLOCK)
		INNER JOIN dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
			ON ll.LogId = l.LogId
	WHERE ll.StatusId = 1
		AND DATEDIFF( MINUTE, ll.StartTime, GETDATE()) >= @TimeChecking
	
	IF @@ROWCOUNT = 0
	BEGIN
		SELECT NULL AS ServerName
			, NULL AS LogId
			, NULL AS Starttime
			, NULL AS SystemName
			, NULL AS FunctionName
			, NULL AS TableName
			, NULL AS Action
			, NULL AS MatchId
			, NULL AS TransInfo
			, NULL AS TransInfoJson
			, NULL AS LogDate
			, NULL AS SettlementAction
			, NULL AS TicketType
		WHERE 1 = 2
	END
	ELSE
	BEGIN
		SELECT @ServerName AS ServerName
			,LogID	 
			, StartTime		 
			, SystemName	 
			, FunctionName	 
			, TableName		 
			, Action		 
			, MatchId		 
			, STUFF (    
						(	SELECT  ','+ CAST( T.C.value('./@t', 'VARCHAR(20)') AS VARCHAR(MAX) ) 
							FROM transinfo.nodes('/root/r') AS [T](C)							   
							FOR XML PATH('') 
						)
						,1,1, ''
					) AS TransInfo	
					
			, STUFF (
						( SELECT  ',' + t   
						  FROM OPENJSON (TransInfoJson ) WITH( t  VARCHAR(20) ) 
						  FOR XML PATH('') 
						)  
						, 1, 1, '' 
					)  AS TransInfoJson  

			, LogDate		 
			, SettlementAction  
			, TicketType	 
		FROM @tmpLastLogPending l

	END

END
GO
 