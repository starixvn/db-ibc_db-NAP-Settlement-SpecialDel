/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingSel_Queue_3rd] 
	 @LeagueIds 	VARCHAR(MAX) 		
	,@SportTypes 	VARCHAR(MAX) 			 
	,@SettleType	VARCHAR(50)
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200803@July : Get list Sporttype and LeagueId [Redmine:#138475]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation: 
		@SettleType = BBD: BetBuilder
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @StartTime	DATETIME
			,@EndTime	DATETIME
			,@sqlCommand VARCHAR(MAX)
			,@IsCentral BIT

	DECLARE @tmpMatchInQueue TABLE (MatchId INT, QueueStatus INT )
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	--Get match info in queue
	;WITH cteSingle3rdQueue AS (
		SELECT s.matchid, MIN(s.IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
		WHERE	Starttime > DATEADD(MINUTE, -10, GETDATE())
		GROUP BY matchid
	),
	cteSingleMainQueue AS (
		SELECT s.matchid, MIN(s.IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
			INNER JOIN dbo.VendorStatus vs WITH(NOLOCK) 
				ON	vs.MatchID = s.MatchID
		WHERE	Starttime > DATEADD(MINUTE, -10, GETDATE())
				AND vs.Opened = 1 
				AND IsCalculating = 2
		GROUP BY s.matchid
	)
	INSERT INTO @tmpMatchInQueue(MatchId, QueueStatus)
	SELECT	ISNULL(s3.MatchID, mq.MatchID) AS MatchID
			, ISNULL(s3.QueueStatus, mq.QueueStatus) AS QueueStatus
	FROM cteSingle3rdQueue s3
		FULL OUTER JOIN  cteSingleMainQueue mq 
			ON	s3.matchid = mq.matchid
	
	--count ticket on table Bettrans
	;WITH cteBettrans 
	AS (
		SELECT	bt.matchid
				,COUNT (*) AS totalTicket
		FROM	@tmpMatchInQueue q
			INNER JOIN dbo.bettrans bt WITH (NOLOCK)
				ON q.MatchId = bt.matchid
		WHERE	bt.statusID NOT BETWEEN 101 AND 102
				AND bt.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bt.SiteDBGroupID END
				AND bt.bettype = 38
		GROUP BY bt.matchid
	)
	SELECT	m.matchID
			,m.SettlementStatus 
			,m.betStatus
			,m.eventStatus
			,m.autoSetting
			,ISNULL(b.totalTicket,0) AS totalTickets
			,q.QueueStatus
			,m.sporttype
	FROM	@tmpMatchInQueue q
		INNER JOIN dbo.[match] m WITH (NOLOCK) 
			ON m.matchid = q.matchid
		INNER JOIN STRING_SPLIT(@SportTypes, ',') st
			ON	m.SportType =st.value
		INNER JOIN STRING_SPLIT(@LeagueIds, ',') l    
			ON	m.LeagueID = l.value
		LEFT JOIN cteBettrans b ON m.matchid = b.matchid

	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 1000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingSel_Queue_3rd @LeagueId = ' + CONVERT(VARCHAR(MAX),@LeagueIds) 
														+ ', @SportType =' + CONVERT(VARCHAR(MAX),@SportTypes)
														+ ', @SettleType =' + CONVERT(VARCHAR(50),@SettleType)
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO