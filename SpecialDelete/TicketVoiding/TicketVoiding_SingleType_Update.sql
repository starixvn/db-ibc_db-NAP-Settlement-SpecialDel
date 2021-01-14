/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SingleType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''

	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT

AS
/*	Created by: Kathy
	Date 20181212
	Task: void single ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190419@Kathy: Change KeyId = 6 for FastMarket and send notification in case of void all marked ticket [Redmine:#108826]
		- 20190605@Kathy: Add keyId = 5 for BetBuilder [Redmine:#106898]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200210@Helen: Hotfix - cashout - not insert 914 [Redmine:#128190]
		- 20200303@Charles: Copy 'epositiontaking' value from translog into bettrans [128921]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
	
	Param's explanation:	
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

	DECLARE @avaiableProcess BIT
			,@isExistMG BIT
			,@isExistFM BIT
			,@isExistFM2	BIT
			,@IsExistBB	BIT
			,@isExistMatch BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			,@IssueTypeId	TINYINT
			,@CustIdsCashOut VARCHAR(MAX)
			,@winlostdate				DATETIME
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistBT					BIT = 0
			,@isExistCashOut			BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@Remark					VARCHAR (500) = ''
			,@isExistLucky3				BIT = 0
			,@Lucky3TransIDs			VARCHAR(MAX)
			,@Lucky3Matches				VARCHAR(MAX) = ''
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)		
	DECLARE @tmpCustCashOut TABLE (CustId INT)
						
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)

	CREATE TABLE #Lucky3Matches
	(
		MatchID				INT PRIMARY KEY,
		Has1stPrize			BIT,
		NumberOf1stPrize	INT DEFAULT(0),
		NumberOf2ndPrize	INT DEFAULT(0),
		NumberOf3rdPrize	INT DEFAULT(0)
	)

	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0
	SET @FailedTransIds = @TransIds

	SET @session = CAST(NEWID() AS NVARCHAR(50))	

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	val AS TransId
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	INSERT INTO #tmpTransId(custid, bettype, KeyId, Refno, actual_stake, TicketType, matchid)
	SELECT	tl.custid, tl.gameID, 3, tl.translogid, tl.actual_stake, 5 -- Metric gaming
		, tl.eventID
	FROM	@tmpInputTransId t
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON t.TransId = tl.translogid
	WHERE	tl.statusID <> 102			
	
	IF @@ROWCOUNT <> 0
		SET @isExistMG = 1
		
	INSERT INTO #tmpTransId(TransId, custid, bettype, KeyId, TicketType, betdaqid, extrainfo, refcode, betid, matchid, oddsid)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN b.bettype = 38 THEN 5
				WHEN f.GroupId = 1 THEN 6 
				WHEN f.GroupId = 2 THEN 7
				ELSE 1 				
			END AS KeyId
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3			
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			,b.matchid, b.oddsid
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.bettype
			)f
	WHERE	b.statusID <> 102		

	--IF @@ROWCOUNT <> 0
	--	SET @isExistMatch = 1
		
	IF NOT EXISTS (SELECT * FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'				

		RETURN
	END

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		
		WHERE bettype NOT IN (9, 29, 2799)
			
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
			
		WHERE bettype IN (10)
	END
	
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistLucky3		= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	#tmpTransId b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f

	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, CASE 
			WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
					AND Bettype NOT BETWEEN 801 AND 899
					AND f.GroupId IS NULL
					AND Bettype NOT IN (1231,1232,1233)
				THEN 1 --SB,NG,LC
			WHEN Bettype = 10 THEN 2	-- Outright
			WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
			WHEN f.GroupId = 1 THEN 6 -- FM
			WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
			WHEN Bettype = 38 THEN 5 -- Bet Builder
			WHEN f.GroupId = 2 THEN 7 -- FM 228
			ELSE 0
		END AS KeyID
	FROM #tmpTransId b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistParlay 				= @isExistParlay
		, @isExistOutright 			= @isExistOutright
		, @isExistMG				= @isExistMG
		, @isExistFM				= @isExistFM
		, @isExistMatch				= @isExistMatch
		, @isExistNG				= @isExistNG
		, @isExistVS				= @isExistVS
		, @isExistBB				= @isExistBB
		, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
		, @isExistFM2				= @isExistFM2
		, @avaiableProcess 			= @avaiableProcess OUTPUT
		, @ErrCode					= @ErrCode OUTPUT
		, @ErrMsg					= @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		RETURN
	END

	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT	t.transid
	FROM	#tmpTransId t	
	WHERE	t.TicketType = 3

	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
		@Mode = 'Original'
		,@Action = 'Void'
		,@IsReleased = 0

	DELETE	t
	FROM	#tmpTransId t
		 INNER JOIN #tblCashOutProcess co
				 ON t.transid = co.transid					
					AND co.IsAvailable = 0

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId t)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= @isExistMatch
			,@isExistMG = @isExistMG 
			,@isExistFM = @isExistFM
			,@isExistBB = @isExistBB
			,@isExistFM2 = @isExistFM2
			,@IsReleased	= 1
			
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original' 
			  , @Action = 'Void'
			  , @IsReleased = 1				

		RETURN
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO #tmpTransId (TransId, custid, Refno, bettype, TicketType, isSubTransaction, matchid)
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, main.matchid
		FROM	#tmpTransId main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)

		-- cashout bet ticket, 912, 913
		INSERT INTO #tmpTransId(TransId,custid, Refno, bettype, TicketType, isSubTransaction, matchid)
		SELECT	sub.TransId,sub.custid, sub.Refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, sub.matchid
		FROM	#tmpTransId sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911

		INSERT INTO @tmpCustCashOut(CustId)
		SELECT	t.custid
		FROM	#tmpTransId t
		WHERE	t.TicketType = 3
				AND t.bettype = 912
		GROUP BY t.custid
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 5)
	BEGIN
		INSERT INTO [bodb02].[dbo].[bettrans]  (
				[custid]  
				,[transdate]  
				,[oddsid]  
				,[hdp1]  
				,[hdp2]  
				,[odds]  
				,[stake]  
				,[status]  
				,[winlost]  
				,[awinlost]  
				,[mwinlost]  
				,[playercomm]  
				,[comm]  
				,[acomm]  
				,[apositiontaking]  
				,[mpositiontaking]  
				,[tpositiontaking]  
				,[playerdiscount]  
				,[discount]  
				,[adiscount]  
				,[livehomescore]  
				,[liveawayscore]  
				,[liveindicator]  
				,[betteam]  
				,[creator]  
				,[refno]  
				,[comstatus]  
				,[winlostdate]  
				,[betfrom]  
				,[betcheck]  
				,[checktime]  
				,[oddsspread]  
				,[actualrate]  
				,[matchid]  
				,[recommend]  
				,[mrecommend]  
				,[ruben]  
				,[betid]  
				,[statuswinlost]  
				,[modds]  
				,[bettype]  
				,[betdaqid]  
				,[actual_stake]  
				,[currency]  
				,[ip]  
				,[transdesc]  
				,[sdiscount]  
				,[scomm]  
				,[spositiontaking]  
				,[swinlost]  
				,[srecommend]  
				,[Username]  
				,[CurrencyName]  
				,[virtualrate]  
				,[oddstype]  
				,[statusID]  
				,[currency2]  
				,[balance]  
				,[SecAcceptFlag]  
				,[transid2]  
				,[RecommDate]
				,[epositiontaking]
		)  
		SELECT	tl.[custid]  
				,tl.[transdate]  
				,0 [oddsid]  
				,0 [hdp1]  
				,0 [hdp2]  
				,tl.[odds]  
				,tl.[stake]  
				,tl.[status]  
				,0 [winlost]  
				,0 [awinlost]  
				,0 [mwinlost]  
				,0 [playercomm]  
				,0 [comm]  
				,0 [acomm]  
				,tl.[apositiontaking]  
				,tl.[mpositiontaking]  
				,tl.[tpositiontaking]  
				,tl.[playerdiscount]  
				,tl.[discount]  
				,tl.[adiscount]  
				,0 [livehomescore]  
				,0 [liveawayscore]  
				,tl.[liveindicator]  
				,SUBSTRING(tl.[transdesc],11,CHARINDEX(';BettypeTime',tl.[transdesc],0) - 11) [betteam]  
				,tl.[creator]  
				,tl.translogid [refno]  
				,tl.custom2 [comstatus]  
				,tl.[winlostdate]  
				,tl.[betfrom]  
				,tl.transdate [betcheck]  
				,NULL [checktime]  
				,0 [oddsspread]  
				,tl.[actualrate]  
				,tl.EventID  
				,tl.[recommend]  
				,tl.[mrecommend]  
				--,1 [ruben]  
				,0 [ruben] --#94603
				,CASE WHEN ISNULL(tl.custom3,'') = '' THEN NULL ELSE CAST(tl.custom3 AS BIGINT) END [betid]  
				,NULL [statuswinlost]  
				,0 [modds]  
				,tl.GameID [bettype]  
				,NULL [betdaqid]  
				--,b.[actual_stake] --#94603 
				,0 [actual_stake]
				,tl.[currency]  
				,tl.[ip]  
				,tl.[transdesc]  
				,tl.[sdiscount]  
				,0 [scomm]  
				,tl.[spositiontaking]  
				,0 [swinlost]  
				,tl.[srecommend]  
				,tl.[Username]  
				,tl.[CurrencyName]  
				,tl.[virtualrate]  
				,tl.custom1 [oddstype]  
				,tl.[statusID]  
				,NULL [currency2]  
				,tl.[balance]  
				,0 [SecAcceptFlag]  
				,0 [transid2]  
				,NULL [RecommDate]
				,tl.[epositiontaking] 				
			FROM #tmpTransId t
				INNER JOIN dbo.translog tl WITH(NOLOCK)  
					ON tl.translogid = t.Refno
			WHERE NOT EXISTS (
					SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK) 
					WHERE b.custid = tl.custid 
						AND b.refno = tl.translogid 
						AND b.matchid = tl.eventID
				)

		UPDATE  t
			SET TransId = b.transid
				,betid = ISNULL(b.BetID, rs.ResultID)
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.Refno = b.refno
					AND b.matchid = @MatchId
					AND b.bettype = t.bettype
					AND b.custid = t.custid
			OUTER APPLY (
				SELECT	rs.ResultID
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)
				WHERE	(
							(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0)
							OR b.bettype = 806
						)
						AND rs.GameID = b.bettype	
						AND rs.VendorID = 5		
						AND rs.MatchID = b.matchid	
			) rs
		WHERE	t.TicketType = 5

	END

	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid
	FROM	#tmpTransId t
	WHERE	t.refcode IS NOT NULL
	GROUP BY t.refcode, t.custid, t.bettype

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId (TransId, custid, bettype, KeyId, TicketType, refcode, matchid)
		SELECT b.TransId, b.custid, b.bettype, 1, 1, b.refcode, b.matchid
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE b.transid = TransId)
	END

	SET @FailedTransIds = NULL

	;WITH cteResult 
	AS(
		SELECT	refno AS TransId
		FROM	#tmpTransId
		WHERE	TicketType = 5
		UNION ALL
		SELECT	TransId 
		FROM	#tmpTransId
		WHERE	TicketType <> 5
	)
	SELECT	@FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(it.TransId AS VARCHAR(30)), CAST(it.TransId AS VARCHAR(30)))
	FROM	@tmpInputTransId it
	WHERE	NOT EXISTS (SELECT * FROM cteResult c WHERE c.TransId = it.TransId)

	-- backup into zzzbettrans
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
			,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
			,betteam, creator, refno, winlostdate, betfrom
			,betcheck
			,comstatus
			,checktime, matchid, bettype  
			,VoidingHistoryId
		)  
	SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
		,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
		,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
		,CASE 
			WHEN t.TicketType = 3 THEN @session -- original ticket & cashout bet ticket
			ELSE b.betcheck END AS betcheck 
		,CASE WHEN t.TicketType = 3 AND t.isSubTransaction = 1 THEN 'CO' ELSE b.comstatus END
		,b.checktime, b.matchid, b.bettype  
		,@VoidingHistoryId
	FROM	#tmpTransId AS t WITH (NOLOCK)  
		INNER JOIN dbo.bettrans b WITH (NOLOCK)  
			ON b.transid = t.TransId

	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END

	--capture balance before voiding
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
			
	SELECT @xmlTransId = (SELECT	t.TransId AS '@transid'
									,CASE WHEN t.TicketType = 5 THEN t.Refno ELSE NULL END AS '@translogid'
									,t.betid AS '@betid'
									,CASE WHEN t.TicketType = 5 THEN 1 ELSE NULL END AS '@isMG'
									,CASE WHEN t.TicketType = 5 THEN t.actual_stake ELSE NULL END AS '@actual_stake'
									,t.isSubTransaction AS '@IsCashOutMember'
							FROM	#tmpTransId t
							FOR XML PATH('r'), ROOT('root')
						)
	
	SET @IssueTypeId = (
							SELECT TOP 1 tr.IssueTypeId
							FROM TicketVoiding_Request tr WITH (NOLOCK)
							WHERE tr.RequestId = @RequestId
						)
						
	EXEC dbo.TicketVoiding_Admin_VoidingTransId 
		@TransIds = @xmlTransId
		,@UserId = @UserId
		,@IssueTypeId = @IssueTypeId

	-- PRE CAL 914
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		BEGIN TRY				
			SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(c.CustId AS VARCHAR(50))
											FROM	@tmpCustCashOut c						    
											FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')	
																					    
			EXEC dbo.NAP_Admin_Calculate_914 
					@MatchId 	= @MatchID
					,@Action 	= 'VOID'
					,@CustIds 	= @CustIdsCashOut				
		END TRY 
		BEGIN CATCH
			SELECT @ErrCode = 914
					, @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
		END CATCH
	END

	-- PRE CAL 501 Cricket - charge comm
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 501)
	BEGIN
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))		
		BEGIN TRY
			DECLARE @CustIdsCricket VARCHAR(MAX)

			SET @CustIdsCricket = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
										FROM	#tmpTransId t where t.bettype = 501
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')

			EXEC dbo.NAP_Admin_Calculate_500 
				@MatchId = @MatchId
				,@Action = 'VOID'
				,@CustIds = @CustIdsCricket
		END TRY 
		BEGIN CATCH
			SELECT	@ErrCode = 500
				,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
		END CATCH
	END

	IF (@isExistLucky3 = 1)
	BEGIN
		SELECT @Lucky3TransIDs = STUFF(
										(
											SELECT ',' + CAST(transid AS VARCHAR(MAX))
											FROM #BetDelete
											WHERE Bettype = 1600
											FOR XML PATH('')
										), 1, 1, '')
		
		INSERT INTO #Lucky3Matches(MatchID, Has1stPrize)
		SELECT	r.MatchId,
				MAX(CASE r.Prize WHEN 1 THEN 1 ELSE 0 END)
		FROM dbo.BetLucky3Result r WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #tmpTransId b WHERE b.transid = r.TransId AND b.Bettype = 1600)
			AND r.Bettype = 1601
		GROUP BY r.matchid
		
		--Delete data in betLucky3Result
		EXEC dbo.NAP_Admin_PreCalculate_s160 @MatchId = 0, @Mode = 'preCAL', @Action = 'VOID', @strVoidedTransId = @Lucky3TransIDs,
											@FirstBall = NULL, @SecondBall = NULL, @ThirdBall = NULL, @FirstPrizeMaxCount = NULL,
											@PrizeSettingId = NULL, @strCustSetting = NULL
		
		UPDATE l
		SET NumberOf1stPrize = d.NumberOf1stPrize,
			NumberOf2ndPrize = d.NumberOf2ndPrize,
			NumberOf3rdPrize = d.NumberOf3rdPrize
		FROM #Lucky3Matches l
			JOIN (
				SELECT  r.MatchId,
						SUM(CASE r.Prize WHEN 1 THEN Odds * Hits ELSE 0 END) AS NumberOf1stPrize,
						SUM(CASE r.Prize WHEN 2 THEN Odds * Hits ELSE 0 END) AS NumberOf2ndPrize,
						SUM(CASE r.Prize WHEN 3 THEN Odds * Hits ELSE 0 END) AS NumberOf3rdPrize
				FROM dbo.BetLucky3Result r WITH(NOLOCK)
				WHERE EXISTS (SELECT 1 FROM #Lucky3Matches l1 WHERE r.MatchId = l1.MatchID)
					AND r.Bettype = 1601
				GROUP BY r.MatchId
			) d ON l.MatchID = d.MatchId
		
		SELECT @Lucky3Matches = CAST((	SELECT	MatchID AS '@m',
												NumberOf1stPrize AS '@fn',
												NumberOf2ndPrize AS '@sn',
												NumberOf3rdPrize AS '@tn'
										FROM #Lucky3Matches
										FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX))
		
		--Update match prize count
		EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update_s160 @Action = NULL, @IsAuto = 0, @strMatchInfo = @Lucky3Matches
		
	END
	
	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR tmp.Bettype BETWEEN 1201 AND 1299
			OR tmp.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END

	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0	

	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
	BEGIN
		
		CREATE TABLE #balanceGameChange (
			custid 			INT
			,winlostdate 	SMALLDATETIME
			,balance 		MONEY
			,bettype		SMALLINT
			,gametypeid		SMALLINT			
			,Increased 		BIT
		)

		INSERT INTO #balanceGameChange (custid, winlostdate, balance, bettype, gametypeid, Increased)
		SELECT	b.custid
				,b.winlostdate
				,a.winlost - b.winlost
				,a.groupid
				,a.gametypeid
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
		FROM	#balanceGameBefore b
			INNER JOIN #balanceGameAfter a 
				ON	b.custid 		= a.custid
				AND b.winlostdate 	= a.winlostdate
				AND a.gametypeid = b.gametypeid
				AND a.groupid = b.groupid
		WHERE	b.winlost <> a.winlost
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,ABS(balance)
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,balance
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 1
		
		DROP TABLE #balanceGameChange
	END

	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	@BeforeUpd b
		INNER JOIN @AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	UPDATE odds  
		SET hometotal = hometotal - (CASE WHEN b.betteam = 'h' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
			   ELSE 0 END )  
		,awaytotal = awaytotal - (CASE WHEN b.betteam = 'a' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
				ELSE 0 END)  
		FROM dbo.odds o WITH (ROWLOCK,UPDLOCK)  
			INNER JOIN dbo.bettrans b WITH (NOLOCK) 
				ON o.matchid = b.matchid AND o.oddsid = b.oddsid  
			INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) 
				ON c.custid = b.custid  
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) 
				ON c.currency = e.exchangeid  
		
		WHERE	b.matchid = @MatchId
			AND EXISTS ( 
				SELECT TOP 1 1   
				FROM #tmpTransId AS t
				WHERE t.TransID  = b.transid
					AND t.Bettype IN (1,3,7,8)				
		   ) 

	-- Update BetTradeSellingCancelled information
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	#tmpTransId t
	WHERE	t.bettype = 911
	GROUP BY t.custid

	EXEC dbo.TicketVoiding_BalanceMember_Select 
		@CustIds = @CustIds
		,@CustBalance = @CustBalance OUTPUT

	INSERT INTO @tmpBalanceMember (CustId, Balance)
	SELECT	T.C.value('./@c', 'int')
			,T.C.value('./@b', 'money')
	FROM	@CustBalance.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustBalance = NULL ))

	;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' AS [Remark]
					,sub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,c.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM	#tmpTransId sub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = sub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN sub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = sub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN @tmpBalanceMember c
						 ON sub.custid = c.custid						 							
			WHERE sub.BetType = 911
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE TicketType = 5)
	BEGIN		
		INSERT INTO dbo.BettradeAPI (
					transid
					,matchid
					,[Session]
					,[action]
					,buybackNo
					,Payout
					,Remark
			)
		SELECT	b.TicketID
				,b.MatchID
				,@session
				,'VOID'
				,b.BuyBackNo
				,b.PayOut
				,'SB void ticket due to ' 
		FROM	#tmpTransId t
			INNER JOIN dbo.BetTradeSelling b WITH(NOLOCK)
				ON t.TransId = b.TicketID
		WHERE	t.TicketType = 5
			AND b.[Status] IN ('Accept', 'Confirm')
	END

	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = @isExistMatch
		,@isExistMG	= @isExistMG
		,@isExistFM = @isExistFM
		,@isExistBB = @isExistBB
		,@isExistFM2 = @isExistFM2
		,@IsReleased = 1

	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 1  	

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ' Single ticket with TransId: ' + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tblCashOutProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransId
	DROP TABLE #balanceGameAfter
	DROP TABLE #balanceGameBefore
	DROP TABLE #Lucky3Matches
	
END

GO

