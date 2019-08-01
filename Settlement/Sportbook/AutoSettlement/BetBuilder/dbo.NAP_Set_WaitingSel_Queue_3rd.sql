/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingSel_Queue_3rd] 
	@LeagueId 		INT 			= 0			 -- 0 for ALL Leagues
	,@SportType 	INT 			 
	,@SettleType	VARCHAR(50)
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		
	Param's Explanation: 
		@SettleType = BBD: BetBuilder
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid INT, @StartTime DATETIME, @EndTime	DATETIME, @SqlCommand VARCHAR(MAX)
			,@MinBettype INT, @MaxBettype INT
	DECLARE @TempMatch TABLE (MatchId INT, QueueStatus INT)
	DECLARE @tblTicketStatusBySettleType TABLE (matchid INT, totalTicket INT, totalTicketRunning INT, SettleType VARCHAR(20))
	DECLARE @tblBettype TABLE (Bettype INT, SettleType VARCHAR(3))
	DECLARE @tblTicketStatus TABLE (MatchID INT, ParlayStatus VARCHAR(20))
	------------------------------------------------------------------------------	
	SELECT @LeagueId = ISNULL(@LeagueID, 0)
		   ,@SportType = ISNULL(@SportType, 0)

		   

	----------------------------------------------------------------------------
	--Get Bettype from PROFILE
	IF @SettleType IS NOT NULL
	BEGIN
		INSERT INTO @tblBettype (Bettype, SettleType)
		SELECT DISTINCT Bettype, SettleType
		FROM dbo.SettlementSpecialBettypeProfile WITH (NOLOCK)
		WHERE Sporttype = @Sporttype 
			AND SettleType IN (SELECT val FROM dbo.[f_SplitString](@SettleType, ','))
		ORDER BY Bettype
	END
	
		
	SELECT @MinBettype	= MIN(bettype)
		   ,@MaxBettype = MAX(bettype)
	FROM @tblBettype
		
	
	--Get match info in queue
	;WITH SingleTicket AS (
		SELECT matchid, MIN(IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (sporttype = @sporttype OR @sporttype = 0)
			AND (leagueid = @leagueid OR @leagueId = 0)
		GROUP BY matchid 
	),
	SingleTicketMainQueue AS (
		SELECT s.matchid, MIN(IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
			INNER JOIN dbo.VendorStatus vs WITH(NOLOCK) ON vs.MatchID = s.MatchID
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (sporttype = @sporttype OR @sporttype = 0)
			AND (leagueid = @leagueid OR @leagueId = 0)
			AND vs.Opened = 1 
			AND IsCalculating = 2
		GROUP BY s.matchid 
	)
	INSERT INTO @TempMatch(MatchId, QueueStatus)
	SELECT ISNULL(sg.MatchID, mq.MatchID) AS MatchID
		, ISNULL(sg.QueueStatus, mq.QueueStatus) AS QueueStatus
	FROM SingleTicket sg
		FULL OUTER JOIN SingleTicketMainQueue mq ON sg.matchid = mq.matchid
	
	
	--count ticket on table Bettrans
	;WITH cteTicketCount AS(
		SELECT	bt.matchid, bt.bettype
				, COUNT (*) AS totalTicket
				, SUM(CASE WHEN bt.statusID = 0 THEN 1 ELSE 0 END) totalTicketRunning
		FROM	dbo.bettrans bt WITH (NOLOCK)
		WHERE	EXISTS (SELECT TOP 1 1 FROM @TempMatch t WHERE t.matchid = bt.matchid)
				AND bt.statusID NOT BETWEEN 101 AND 102
				AND bt.bettype BETWEEN @MinBettype AND @MaxBettype
		GROUP BY bt.matchid, bt.bettype
	)
	INSERT INTO @tblTicketStatusBySettleType (matchid, SettleType, totalTicket, totalTicketRunning)
	SELECT  cte.matchid, bt.SettleType, SUM(totalTicket), SUM(totalTicketRunning)
	FROM	@tblBettype bt
		INNER JOIN cteTicketCount cte ON cte.bettype = bt.bettype
	GROUP BY cte.matchid, bt.SettleType
		
	
	
	---------------------------------------RETURN DATA--------------------------------------
	INSERT INTO @tblTicketStatus(MatchID, parlayStatus)
	SELECT MatchID
			,MAX (CASE WHEN totalTicket = 0 		THEN 'No Ticket'
					  WHEN totalTicketRunning > 0 	THEN 'Running'
					  ELSE 'Completed' END
			     ) AS parlayStatus
	FROM @tblTicketStatusBySettleType
	GROUP BY MatchID
   
	
	
	SELECT	m.matchID
			,m.SettlementStatus 
			,m.betStatus
			,m.eventStatus
			,m.finalHomeScore
			,m.finalAwayScore
			,m.htHomeScore AS halfTimeHomeScore
			,m.htAwayScore AS halfTimeAwayScore
			,m.autoSetting
			--,l.autoSetting AS autoSettingForLeague
			,ISNULL(rs.parlayStatus,'No Ticket') AS parlayStatus
			,tm.QueueStatus
	FROM	@TempMatch tm
		INNER JOIN dbo.[match] m WITH (NOLOCK) ON m.matchid = tm.matchid
		--INNER JOIN dbo.[League] l WITH (NOLOCK) ON m.leagueID = l.LeagueID
		LEFT JOIN @tblTicketStatus rs ON m.matchid = rs.matchid

	
	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 1000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingSel_Queue_3rd @LeagueId = ' + CONVERT(VARCHAR(10),@LeagueId) 
														+ ', @SportType =' + CONVERT(VARCHAR(10),@SportType)
														+ ', @SettleType =' + CONVERT(VARCHAR(50),@SettleType)
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO