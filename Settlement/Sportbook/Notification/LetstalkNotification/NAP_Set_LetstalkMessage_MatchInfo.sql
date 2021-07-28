/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_MatchInfo
AS
/*
	Created by: Louisa
	Date: 20210727
	Task: Letstalk message [Redmine:#158331]
	DB: DBTXN/bodb02

	Revisions:
		20210727@Louisa: Letstalk message: Confirmed HT/FT, Completed with early running tickets [Redmine:#158331]	

	Param explanation:
		@MessageGroupId 
					2: Settlement notification
		@MessageType
					Reminder
		@ActionName: 
					 HT Score confirmed
					 FT Score confirmed
					 Completed match with 'Running' tickets		
*/
BEGIN

	SET NOCOUNT ON;

	DECLARE  @SqlQuery VARCHAR(4000) = ''

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
	DROP TABLE #MatchInfo

	CREATE TABLE #MatchInfo (
		MatchId				INT
		,eventstatus		NVARCHAR(100)
		,SettlementStatus	TINYINT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusID		TINYINT
		,ConfirmedTime		DATETIME
		,settletime			DATETIME
		,IsRunningEarlyTicket BIT DEFAULT(0)
	)

	SELECT @SqlQuery = 
	'SELECT * FROM
	 OPENQUERY(DBPRO, ''
		SELECT DISTINCT m.matchid
				, m.eventstatus
				, m.SettlementStatus
				, r.ResourceId
				, r.HomeValue
				, r.AwayValue
				, r.ResultStatusID
				, r.LastModifyDate AS ConfirmedTime
				, m.settletime
		FROM bodb02.dbo.Match m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.ResultDetail r WITH(NOLOCK)
				ON m.matchid = r.matchid
		WHERE m.sporttype = 1
			AND ( CASE  WHEN r.ResourceId IN (''''00'''', ''''01'''') 
							AND r.ResultStatusID = 3 
							AND DATEDIFF( SECOND ,r.LastModifyDate, GETDATE() ) >= 120 THEN 1
						WHEN r.ResourceId = ''''00'''' AND r.ResultStatusID = 5
							AND DATEDIFF( SECOND ,m.settletime, GETDATE() ) >= 180 THEN 1 
						ELSE 0 END )	> 0 '')'
	
	INSERT INTO #MatchInfo (
	MatchId
	,eventstatus		
	,SettlementStatus	
	,ResourceId			
	,HomeValue			
	,AwayValue			
	,ResultStatusID		
	,ConfirmedTime		
	,settletime
	)
	EXEC (@SqlQuery)

	UPDATE m
	SET IsRunningEarlyTicket = 1
	FROM #MatchInfo m
	WHERE m.MatchId IN (
			SELECT TOP 1 1 FROM dbo.f_Set_GetEarlyBettypes() f
			CROSS APPLY (	SELECT TOP 1 b.transid
							FROM dbo.bettrans b WITH(NOLOCK)
							WHERE b.matchid = MatchId
								AND b.statusID = 0
								AND b.bettype = f.bettype
							UNION ALL
							SELECT TOP 1 bm.transid
							FROM dbo.bettransm bm WITH(NOLOCK)
							WHERE bm.matchid = MatchId
								AND bm.statusID = 0
								AND bm.bettype = f.bettype
						) b
					)
	
	SELECT m.MatchId
			,eventstatus	
		   ,m.SettlementStatus	
		   ,m.ResourceId			
		   ,m.HomeValue			
		   ,m.AwayValue			
		   ,m.ResultStatusID		
		   ,m.ConfirmedTime		
		   ,m.settletime			
		   ,m.IsRunningEarlyTicket
	FROM #MatchInfo	m
	WHERE m.ResultStatusID = 3
		OR m.IsRunningEarlyTicket = 1
	
END
GO