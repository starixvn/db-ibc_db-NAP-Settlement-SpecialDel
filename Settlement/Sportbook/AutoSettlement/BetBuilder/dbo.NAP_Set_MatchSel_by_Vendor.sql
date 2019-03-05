/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSel_by_Vendor]
	@FromDate			DATETIME
	,@ToDate			DATETIME
	,@Status			VARCHAR(200) 	
	,@MatchCode 		NVARCHAR(50) 	= ''
	,@LeagueID 			INT 			= 0 -- 0 for ALL Leagues
	,@VendorID			INT				= 34
	,@SportType 		TINYINT			= 1
AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		
		
	Param's Explanation:	
		@Status: All, Running, Completed
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @MatchId			INT
			,@CheckEventStatus	BIT
			,@IsRefund			BIT				= 0
			,@MinBetType		INT				= 0
			,@MaxBetType		INT				= 0
	DECLARE @tblEventStatus TABLE (EventStatus VARCHAR(20))
	DECLARE @tblBettype TABLE (Bettype INT)
	DECLARE @TempMatch TABLE (MatchId INT, IsCalculating INT)
	-------------------------------------------------------------------------------------------------
	INSERT INTO @tblEventStatus(EventStatus)
	SELECT Val 
	FROM dbo.f_SplitString(@Status, ',')
	
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
			,@LeagueID = 0
	END
	
	
	INSERT INTO @tblBettype (Bettype)
	SELECT 38
	
	
	------------------------------------------------------------------------------------------------------
	SELECT @MinBetType = MIN(Bettype)
			,@MaxBetType = MAX(Bettype)
	FROM @tblBettype
	
	
	--Get match info in queue
	;WITH SingleTicket AS (
		SELECT matchid
		FROM dbo.[match] m WITH (NOLOCK)
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate
			AND Sporttype = @SportType
			AND (@MatchCode = '' OR m.matchid = @MatchId OR m.matchcode = @MatchCode)
			AND (@LeagueID = 0 OR m.leagueid = @LeagueID)
	),
	QueueSingleMatch AS (
		SELECT matchid, MIN(IsCalculating)  IsCalculating
		FROM dbo.Single_Calculate_Queue_3rd s WITH(NOLOCK)
		WHERE Starttime > DATEADD(HH,-1,GETDATE())
			AND Sporttype = @SportType
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
				  WHERE bt.Bettype IN (SELECT BetType FROM @tblBettype t)
						AND bt.Bettype BETWEEN @MinBetType AND @MaxBetType
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
GO