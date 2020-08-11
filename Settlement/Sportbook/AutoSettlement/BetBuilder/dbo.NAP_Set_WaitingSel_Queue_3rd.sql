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
		
	Param's Explanation: 
		@SettleType = BBD: BetBuilder
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid INT, @StartTime DATETIME, @EndTime	DATETIME, @SqlCommand VARCHAR(MAX)
			,@MinBettype INT, @MaxBettype INT
			,@strMatchIds		VARCHAR(MAX)
			,@remoteQuery		NVARCHAR(MAX)
			,@strResourceIds	VARCHAR(MAX)
	DECLARE @TempMatch TABLE (MatchId INT, QueueStatus INT)
	DECLARE @tblTicketStatusBySettleType TABLE (matchid INT, totalTicket INT, totalTicketRunning INT, SettleType VARCHAR(20))
	DECLARE @tblBettype TABLE (Bettype INT, SettleType VARCHAR(3))
	DECLARE @tblTicketStatus TABLE (MatchID INT, ParlayStatus VARCHAR(20))
	DECLARE @tmpSporttypes TABLE ( Sporttype SMALLINT)
	DECLARE @tmpLeagueIds TABLE ( LeagueId INT)
	DECLARE @tmpResultDetail TABLE (
		MatchId				INT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusId		TINYINT
		,SettlementStatusId TINYINT
	)
	------------------------------------------------------------------------------	
	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT Val 
	FROM dbo.f_SplitString(@SportTypes, ',')
	option (maxrecursion 0)

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT Val 
	FROM dbo.f_SplitString(@LeagueIds, ',')
	option (maxrecursion 0)
    	
	----------------------------------------------------------------------------
	--Get Bettype from PROFILE
	IF @SettleType IS NOT NULL
	BEGIN
		INSERT INTO @tblBettype (Bettype, SettleType)
		SELECT DISTINCT ss.Bettype, ss.SettleType
		FROM dbo.SettlementSpecialBettypeProfile ss WITH (NOLOCK)
			INNER JOIN @tmpSporttypes st ON ss.Sporttype = st.Sporttype 
		WHERE ss.SettleType IN (SELECT val FROM dbo.[f_SplitString](@SettleType, ','))
		ORDER BY Bettype
	END
	
		
	SELECT @MinBettype	= MIN(bettype)
		   ,@MaxBettype = MAX(bettype)
	FROM @tblBettype
		
	
	--Get match info in queue
	;WITH SingleTicket AS (
		SELECT matchid, MIN(IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
			INNER JOIN @tmpSporttypes st ON s.SportType =st.Sporttype
			INNER JOIN @tmpLeagueIds l   ON s.LeagueID = l.LeagueId
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
		GROUP BY matchid 
	),
	SingleTicketMainQueue AS (
		SELECT s.matchid, MIN(IsCalculating) AS QueueStatus
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
			INNER JOIN dbo.VendorStatus vs WITH(NOLOCK) ON vs.MatchID = s.MatchID
			INNER JOIN @tmpSporttypes st ON s.SportType =st.Sporttype
			INNER JOIN @tmpLeagueIds l   ON s.LeagueID = l.LeagueId
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND vs.Opened = 1 
			AND IsCalculating = 2
		GROUP BY s.matchid 
	)
	INSERT INTO @TempMatch(MatchId, QueueStatus)
	SELECT ISNULL(sg.MatchID, mq.MatchID) AS MatchID
		, ISNULL(sg.QueueStatus, mq.QueueStatus) AS QueueStatus
	FROM SingleTicket sg
		FULL OUTER JOIN SingleTicketMainQueue mq ON sg.matchid = mq.matchid
	----------------------------------------------------------------------------------------
	IF EXISTS ( SELECT TOP 1 1 FROM @tmpSporttypes WHERE Sporttype IN (1,2))
	BEGIN
		SELECT @strMatchIds = ''
			   ,@remoteQuery = ''
			   ,@strResourceIds = ''

		SELECT @strMatchIds = @strMatchIds + CAST(tempM.MatchId AS VARCHAR(20)) + ','
		FROM @TempMatch tempM
			INNER JOIN dbo.match m WITH (NOLOCK) ON tempM.MatchID = m.MatchID
		WHERE m.sporttype IN (1,2)
		
		SELECT @strResourceIds = @strResourceIds + '''' + f.ResourceID + '''' + ','
		FROM (
			SELECT DISTINCT f.ResourceID
			FROM @TempMatch tempM
				INNER JOIN dbo.match m WITH (NOLOCK) ON tempM.MatchID = m.MatchID 
				CROSS APPLY dbo.f_Set_MajorRound (m.sporttype) f
			WHERE m.sporttype IN (1,2)
		)f
		SELECT @strMatchIds		= CASE WHEN @strMatchIds ='' THEN @strMatchIds ELSE LEFT(@strMatchIds,LEN(@strMatchIds)-1) END
			   ,@strResourceIds = CASE WHEN @strResourceIds = '' THEN @strResourceIds ELSE LEFT(@strResourceIds, LEN(@strResourceIds) - 1) END 

		IF @strMatchIds ='' 
			SET @remoteQuery =''
		ELSE 
			SET @remoteQuery = 'SELECT	MatchId,ResourceId,HomeValue,AwayValue,ResultStatusID,SettlementStatusID
								FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK) 
								WHERE	r.MatchId IN ('+ @strMatchIds+ ')
										' + CASE WHEN @strResourceIds <> '' THEN 
										' AND r.ResourceId IN ('+ @strResourceIds +')' ELSE '' END

			INSERT INTO @tmpResultDetail (MatchId, ResourceId, HomeValue, AwayValue, ResultStatusId, SettlementStatusId)
			EXECUTE sys.sp_executesql @remoteQuery
	END
	----------------------------------------------------------------------------------------
	
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
			,m.autoSetting
			--,l.autoSetting AS autoSettingForLeague
			,ISNULL(rs.parlayStatus,'No Ticket') AS parlayStatus
			,tm.QueueStatus
	FROM	@TempMatch tm
		INNER JOIN dbo.[match] m WITH (NOLOCK) ON m.matchid = tm.matchid
		--INNER JOIN dbo.[League] l WITH (NOLOCK) ON m.leagueID = l.LeagueID
		LEFT JOIN @tblTicketStatus rs ON m.matchid = rs.matchid

	SELECT	MatchId
			,ResourceId
			,HomeValue
			,AwayValue
			,ResultStatusId
			,SettlementStatusId
			,CASE ResourceId	WHEN 'Q1' THEN 1
								WHEN 'Q2' THEN 2
								WHEN 'Q3' THEN 3
								WHEN 'Q4' THEN 4
								WHEN 'OT' THEN 5
								WHEN '01' THEN 6
								WHEN '00' THEN 7					
			END AS OrderNo
	FROM	@tmpResultDetail
	ORDER BY OrderNo	
	
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