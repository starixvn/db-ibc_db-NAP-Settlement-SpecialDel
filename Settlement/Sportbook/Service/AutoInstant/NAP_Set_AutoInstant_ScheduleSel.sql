/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoInstant_ScheduleSel

AS
/*
	Creator: 20180115@Benjamin
	Task: Get Match information from Suspender score for AutoInstant.
	DB: DBPRO/bodb02
	Revisions:	
		- 20180115@Benjamin: Implement for first verion [Redmine:#86964]
		- 20180806@Kathy: Get waiting time for auto instant [Redmine:#99465]
		- 20180821@Kathy: Get LeagueID to detect test league [Redmine:#99465]
		- 20181205@Vicky: Add New Undecided Option for MTD team [Redmine:#104948]
		- 20190624@Helen: Unable to run Auto Instant HT if Auto Payout HT has already completed [Redmine:#116073]
		- 20191209@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
		- 20220512@Kathy: Improve performance [Redmine:#172386]
		- 20220929@Louisa: check deployment flag [Redmine:#175251]
*/

BEGIN

    SET NOCOUNT ON

	DECLARE	@currentdate	DATETIME
			,@fromdate		DATETIME
			,@todate		DATETIME
			,@checktime		DATETIME
			,@procName		SYSNAME	= OBJECT_NAME(@@procid)
			,@IsWaiting		BIT = 0
	
	DECLARE  @returntable TABLE (MatchID INT, TypeID TINYINT, HomeValue VARCHAR(50), AwayValue VARCHAR(50), CreatedDate DATETIME, InstantKey INT, LeagueId INT, ChildMatchType TINYINT)

	EXEC dbo.NAP_Set_SPDeploymentInfo 
		@SPName = @procName
		,@IsWaiting = @IsWaiting OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		--not return data if in deployment progress
		SELECT MatchID, TypeID, HomeValue, AwayValue, CreatedDate, InstantKey, LeagueId, ChildMatchType
		FROM @returntable

		RETURN
	END

	SET @currentdate = CAST(GETDATE() AS DATE)
	SELECT	@fromdate = DATEADD(DAY,-1,@currentdate)
			,@todate = DATEADD(DAY,1,@currentdate)
			,@checktime = DATEADD(HOUR, 3, GETDATE())

	INSERT INTO @returntable (MatchID, TypeID, HomeValue, AwayValue, CreatedDate, InstantKey, LeagueId, ChildMatchType)
    SELECT m.MatchID, d.TypeID, d.HomeValue, d.AwayValue, d.CreatedDate, d.ProviderResultDetailID AS InstantKey, l.LeagueId, m.ChildMatchType    
    FROM dbo.ProviderResultDetail d WITH (NOLOCK)
	    INNER JOIN dbo.Match m WITH (NOLOCK)
		  ON d.MatchID  = m.MatchID
	    INNER JOIN dbo.League l WITH (NOLOCK)
		  ON m.LeagueID = l.LeagueID      
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = l.leagueid
					AND ss.AutoType = 2 -- Auto Instant
		)ss
		CROSS APPLY (
			SELECT	MAX(ProviderResultDetailID) AS MaxProviderResultDetailID
			FROM	dbo.ProviderResultDetail WITH (NOLOCK)
			WHERE	MatchID  = m.MatchID 
					AND TypeID   = d.TypeID 
					AND SourceID = d.SourceID
		)mx
    WHERE m.SportType	   = 1
	 AND m.EventStatus	   = 'running' 
	 AND m.eventdate BETWEEN @fromdate AND @todate
	 AND GlobalShowTime <= @checktime
	 AND m.SettlementStatus & 87 = 0 --Bit: 1: Pending, 2: Undecided, 3: UnderSettlement, 5: MTDHold, 7: Hold Key
	 AND 2 & ISNULL(m.AutoSetting, l.AutoSetting) = 2
	 AND m.matchcode IS NOT NULL --exist match
	 AND CHARINDEX('hedge', m.matchcode) = 0 -- hedge match	 
	 AND CAST(ISNULL(d.HomeValue, 0) AS INT) <= m.livehomescore
	 AND CAST(ISNULL(d.AwayValue, 0) AS INT) <= m.liveawayscore
	 AND d.ISConfirmed	   = 0
	 AND d.SourceID	   = 100					--Instant
	 AND d.TypeID IN (101, 102)					--HT/FT	 
	 AND d.CreatedDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,120), GETDATE())	 
	 AND d.ProviderResultDetailID	 = mx.MaxProviderResultDetailID
	 AND NOT EXISTS (SELECT 1
				  FROM dbo.ResultDetail r WITH(NOLOCK)
				  WHERE r.MatchId = m.MatchId
				    AND d.TypeID = 102
				    AND r.ResultStatusID IN (2,5)		--Auto settled/Manually settled
				    AND r.ResourceID = '00'			--FT Calculated
				    AND r.SettlementStatusID = 4)		--Completed			
	 --Failure/Running when compare/verify
    	 AND NOT EXISTS (SELECT 1
				  FROM dbo.AutoPayoutResult a WITH(NOLOCK)
				  WHERE a.MatchID     = d.MatchID
				    AND a.HomeValue   = d.HomeValue
				    AND a.AwayValue	  = d.AwayValue
				    AND a.StatusID > 0 
				    AND a.SourceID IN (100, 5) -- sourceID: 100 manual instant, sourceID: 5 auto cal for soccerway result
				    AND a.CalculationType BETWEEN 100 AND 199 -- Cal instant
				    AND a.ModifiedDate > d.CreatedDate)

	SELECT MatchID, TypeID, HomeValue, AwayValue, CreatedDate, InstantKey, LeagueId, ChildMatchType
	FROM @returntable
	ORDER BY CreatedDate

END
GO