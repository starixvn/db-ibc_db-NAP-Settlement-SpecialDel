/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_by_Vendor]
	@FromDate			DATETIME
	,@ToDate			DATETIME
	,@Status			VARCHAR(200) 	
	,@MatchCode 		NVARCHAR(50) 	= ''
	,@LeagueIds 		VARCHAR(MAX) 
	,@VendorID			INT				= 34
	,@SportTypes 		VARCHAR(MAX)
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200731@July : Edit get list SportType and LeagueID [Redmine:#138475]
		
	Param's Explanation:	
		@Status: All, Running, Completed
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId			INT
			,@CheckEventStatus	BIT
			
	DECLARE @tblEventStatus TABLE (EventStatus VARCHAR(20))
	DECLARE @TempMatch TABLE (MatchId INT, IsCalculating INT)
	DECLARE @tmpSporttypes TABLE ( Sporttype SMALLINT)
	DECLARE @tmpLeagueIds TABLE ( LeagueId INT)
	-------------------------------------------------------------------------------------------------
	INSERT INTO @tblEventStatus(EventStatus)
	SELECT Val 
	FROM dbo.f_SplitString(@Status, ',')
	option (maxrecursion 0)

	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT Val 
	FROM dbo.f_SplitString(@SportTypes, ',')
	option (maxrecursion 0)

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT Val 
	FROM dbo.f_SplitString(@LeagueIds, ',')
	option (maxrecursion 0)

	IF EXISTS(SELECT 1 FROM @tblEventStatus HAVING COUNT(*) > 1)
		SET @CheckEventStatus = 0
	ELSE
		SET @CheckEventStatus = 1
		
		
	SET @MatchCode = ISNULL(@MatchCode,'')
	
	IF @MatchCode <> ''
	BEGIN 
		BEGIN TRY 
			SET @MatchId = CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@MatchCode AS INT) ELSE NULL END
		END TRY  
		BEGIN CATCH
			SET @MatchId = NULL
		END CATCH
		
		SELECT @CheckEventStatus = 0
	END
	
	--Get match info in queue
	;WITH SingleTicket AS (
		SELECT matchid
		FROM dbo.[match] m WITH (NOLOCK)
			INNER JOIN @tmpSporttypes st ON m.sporttype=st.Sporttype 
			INNER JOIN @tmpLeagueIds l ON m.leagueid=l.LeagueId      
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate
			AND (@MatchCode = '' OR m.matchid = @MatchId OR m.matchcode = @MatchCode)
	),
	QueueSingleMatch AS (
		SELECT matchid, MIN(IsCalculating)  IsCalculating
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
			INNER JOIN @tmpSporttypes st ON s.sporttype=st.Sporttype
		WHERE Starttime > DATEADD(MINUTE,-10,GETDATE())
			AND s.IsCalculating IN (0,1)
		GROUP BY matchid 
	)	
	INSERT INTO @TempMatch(MatchId, IsCalculating)
	SELECT sg.matchid, q.IsCalculating
	FROM SingleTicket sg
		INNER LOOP JOIN dbo.VendorStatus v WITH (NOLOCK) ON sg.matchID = v.matchID
		LEFT JOIN QueueSingleMatch q ON q.matchID = sg.matchID
	WHERE v.vendorId = @VendorID 
			AND v.Opened = 1 
	
	;WITH cteBettrans AS(
		SELECT matchID
				,CASE	WHEN totalTicket = 0 			THEN 'No Ticket'
						WHEN totalTicketRunning > 0 	THEN 'Running'
						ELSE 'Completed' END AS parlayStatus
		FROM  (
				  SELECT m.matchID
						 ,COUNT (*) AS totalTicket
						 ,SUM (CASE WHEN statusID = 0 THEN 1 ELSE 0 END) AS totalTicketRunning
				  FROM @TempMatch m
				  		INNER JOIN dbo.Bettrans bt WITH (NOLOCK) ON m.MatchID = bt.MatchID
				  WHERE bt.Bettype  = 38
						AND bt.statusID NOT IN (101, 102)
				  GROUP BY m.matchID
			  ) AS tbtTicketCount
	)
	SELECT	m.matchID
			,m.matchCode
			,m.leagueID
			,m.kickOffTime
			,m.SettlementStatus 
			,m.betStatus
			,m.eventStatus
			,m.finalHomeScore
			,m.finalAwayScore
			,m.homeID
			,m.awayID
			,m.htHomeScore AS halfTimeHomeScore
			,m.htAwayScore AS halfTimeAwayScore
			,ISNULL(m.autoSetting, l.autoSetting) AS autoSetting
			,l.autoSetting AS autoSettingForLeague
			,ISNULL(cteBt.parlayStatus, 'No Ticket') AS parlayStatus
			,ISNULL(tempM.IsCalculating, 2) AS QueueStatus
			,m.sporttype
	FROM @TempMatch	tempM
		INNER JOIN dbo.match m WITH (NOLOCK) ON tempM.MatchID = m.MatchID
		INNER JOIN dbo.League l WITH (NOLOCK) ON m.leagueID = l.LeagueID
		LEFT JOIN cteBettrans cteBt ON cteBt.MatchID = tempM.MatchID
	WHERE	(@CheckEventStatus = 0 OR cteBt.parlayStatus = @Status)
	ORDER BY CASE m.eventstatus WHEN 'completed' THEN 1 WHEN 'refund' THEN 1 ELSE 0 END
		, m.eventdate
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchid
		, m.betstatus
		, m.matchcode
END
