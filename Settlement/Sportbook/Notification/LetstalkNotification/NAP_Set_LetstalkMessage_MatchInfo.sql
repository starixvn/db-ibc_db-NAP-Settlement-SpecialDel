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
		20211008@Louisa: Return SP [Redmine:#158331]

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
			, @MessageGroupId TINYINT


	SET @MessageGroupId  = 2

	IF OBJECT_ID('tempdb..#CheckInfo') IS NOT NULL
	DROP TABLE #CheckInfo

	IF OBJECT_ID('tempdb..#MatchInfo') IS NOT NULL
	DROP TABLE #MatchInfo
	 
	CREATE TABLE #CheckInfo (MatchId INT, ActionType TINYINT )

	CREATE TABLE #MatchInfo (
		MatchId				INT
		,eventstatus		NVARCHAR(100)
		,leagueid			INT
		,sporttype			SMALLINT
		,SettlementStatus	TINYINT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusID		TINYINT
		,ConfirmedTime		DATETIME
		,settletime			DATETIME
		,IsRunningEarlyTicket BIT DEFAULT(0)
		,ActionType			TINYINT  DEFAULT(0)
	)

	-- 20211008@Louisa: Stop using
	BEGIN
		SELECT m.MatchId
			   ,m.eventstatus
			   ,m.leagueid	
			   ,m.SettlementStatus	
			   ,m.ResourceId			
			   ,m.HomeValue			
			   ,m.AwayValue			
			   ,m.ResultStatusID		
			   ,m.ConfirmedTime		
			   ,m.settletime			
			   ,m.IsRunningEarlyTicket
		FROM #MatchInfo	m

		RETURN
	END
	--/end



	SELECT @SqlQuery = 
	'SELECT * FROM
	 OPENQUERY(DBPRO, ''
		SELECT DISTINCT m.matchid
				, m.eventstatus
				, m.leagueid
				, m.sporttype
				, m.SettlementStatus
				, r.ResourceId
				, r.HomeValue
				, r.AwayValue
				, r.ResultStatusID
				, r.LastModifyDate AS ConfirmedTime
				, m.settletime
				, CASE r.ResultStatusID WHEN 3 THEN CASE r.ResourceId WHEN ''''01'''' THEN 1
																	  ELSE 2 END
										WHEN 5 THEN 3
										ELSE 0 END AS ActionType
		FROM bodb02.dbo.Match m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.ResultDetail r WITH(NOLOCK)
				ON m.matchid = r.matchid
		WHERE m.sporttype = 1
			AND ( CASE  WHEN r.ResourceId IN (''''00'''', ''''01'''') 
							AND r.ResultStatusID = 3 
							AND DATEDIFF( SECOND ,r.LastModifyDate, GETDATE() ) BETWEEN 120 AND 7200 THEN 1
						WHEN r.ResourceId = ''''00'''' AND r.ResultStatusID = 5
							AND m.eventstatus = ''''completed''''
							AND DATEDIFF( SECOND ,r.LastModifyDate, GETDATE() ) BETWEEN 180 AND 7200 THEN 1 
						ELSE 0 END )	> 0 '')'
	
	INSERT INTO #MatchInfo (
	MatchId
	,eventstatus
	,leagueid
	,sporttype		
	,SettlementStatus	
	,ResourceId			
	,HomeValue			
	,AwayValue			
	,ResultStatusID		
	,ConfirmedTime		
	,settletime
	,ActionType
	)
	EXEC (@SqlQuery)

	IF EXISTS (SELECT TOP 1 1 FROM #MatchInfo WHERE ResultStatusID = 5)
	BEGIN
		UPDATE m
		SET IsRunningEarlyTicket = 1
		FROM #MatchInfo m
		WHERE m.MatchId IN (
							SELECT TOP 1 b.matchid 
							FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
								CROSS APPLY (	
												SELECT TOP 1 b.matchid
												FROM dbo.bettrans b WITH(NOLOCK)
												WHERE b.matchid = m.MatchId
													AND b.statusID = 0
													AND b.bettype = sp.bettype
												UNION ALL
												SELECT TOP 1 bm.matchid
												FROM dbo.bettransm bm WITH(NOLOCK)
												WHERE bm.matchid = m.MatchId
													AND bm.statusID = 0
													AND bm.bettype = sp.bettype
											) b
							WHERE sp.sporttype = m.sporttype
								AND sp.SettleType ='EAR'
								AND m.ResultStatusID = 5
					)
	END

	INSERT INTO #CheckInfo (MatchId, ActionType)
	SELECT l.MatchId, 
			CASE l.MessageGroupId WHEN 2 THEN CASE  WHEN ActionName = 'HT Score confirmed'	THEN 1 --Confirmed HT
													WHEN ActionName = 'FT Score confirmed'	THEN 2 --Confirmed FT
													ELSE 3								--Exists running Early Ticket
													END
									ELSE 0 
									END AS ActionType
	FROM dbo.Settlement_LetstalkMessage l WITH(NOLOCK)
		INNER JOIN #MatchInfo m ON l.MatchId = m.MatchId
	WHERE l.MessageGroupId = @MessageGroupId

	DELETE m
	FROM #MatchInfo m
	WHERE m.MatchId IN (SELECT c.MatchId FROM #CheckInfo c WHERE c.ActionType = m.ActionType ) --- Already exists in Settlement_LetstalkMessage
		OR (m.ResultStatusID = 5 AND m.IsRunningEarlyTicket = 0) --- Do not exists running Early Ticket
	
		
	SELECT m.MatchId
			,eventstatus
		   ,m.leagueid	
		   ,m.SettlementStatus	
		   ,m.ResourceId			
		   ,m.HomeValue			
		   ,m.AwayValue			
		   ,m.ResultStatusID		
		   ,m.ConfirmedTime		
		   ,m.settletime			
		   ,m.IsRunningEarlyTicket
	FROM #MatchInfo	m
END
GO