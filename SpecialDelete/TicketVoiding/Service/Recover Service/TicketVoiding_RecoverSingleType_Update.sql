/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RecoverSingleType_Update]
(
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT
	,@ResettledTransIds   VARCHAR(MAX)	= NULL	OUTPUT
)
AS
/*	
	Created by:20231227@Max
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20231227@Max: Create new SP [Redmine: #196020]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20241126@Lani: [TVS] Change join type on 'recommend' and 'custid' columns [Redmine: #213451]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON;		

	DECLARE  @isExistMatch		BIT = 1
			,@isExistFM			BIT = 0
			,@IsExistBB			BIT = 0
			,@avaiableProcess	BIT
			,@isExistFM2		BIT = 0
			,@Movebetdate		DATETIME  
			,@SiteDBGroupID     SMALLINT = 0
			,@TransInfo			VARBINARY(MAX)
			,@TransInfo3rd		VARBINARY(MAX)
			,@StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@xmlTransId			VARCHAR(MAX) = ''
			,@SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@CustIds			VARCHAR(MAX)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @AutoReSettledTransIds VARCHAR(MAX) = '' 

	CREATE TABLE #tblTransInfo (
		grouptransid	BIGINT
		,transid		BIGINT PRIMARY KEY
		,custid			INT
		,username		VARCHAR(30)
		,username2		VARCHAR(50)
		,transdate		DATETIME
		,odds			SMALLMONEY
		,oddsspread 	MONEY
		,oddstype		TINYINT
		,bettype		SMALLINT
		,winlost		MONEY
		,betteam		NVARCHAR(10)
		,betcheck		NVARCHAR(50)
		,hdp1			SMALLMONEY
		,hdp2			SMALLMONEY
		,betfrom		NVARCHAR(4)
		,stake			MONEY
		,matchid		INT
		,IsLiveIndicator	BIT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,creator		INT
		,creatorName	VARCHAR(30)
		,currencyName	NVARCHAR(50)
		,status			VARCHAR(20)
		,leagueid		INT
		,SportType		TINYINT
		,homeid			INT
		,awayid			INT
		,betid			BIGINT
		,transdesc		NVARCHAR(1000)
		,refno			BIGINT	
		,betdaqid		BIGINT
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,SecAcceptFlag	BIT
		,site			VARCHAR(10)
		,ExtraInfo		VARCHAR(1000)
		,IsCashOut		BIT DEFAULT 0
		,zzzBetcheck	NVARCHAR(50)
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT		
		,MainTransId	BIGINT
		,winlostdate	DATETIME
		,ParentID		INT
		,ChildMatchType TINYINT
		,zzzwinlost		MONEY
		,modds			SMALLMONEY
		,ActualStake	MONEY
	)

	CREATE TABLE #tbTransId (transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY, ruben TINYINT, statuswinlost TINYINT, stake MONEY
			, statusID TINYINT, creator INT, actual_stake MONEY, odds SMALLMONEY, oddsspread MONEY, transdesc NVARCHAR(2000), ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, transdate DATETIME, comstatus NVARCHAR(40)
			, bettype SMALLINT
			)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	DECLARE @tblBeforeBalance TVP_BalanceWalletChange
		  , @tblAfterBalance  TVP_BalanceWalletChange
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0

	BEGIN TRY
		INSERT INTO #tbTransId (transid)
		SELECT value 
		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		-- Normal tickets
		INSERT INTO #tblTransInfo(
				grouptransid	
				,transid		
				,custid					
				,transdate		
				,odds
				,oddsspread				
				,oddstype		
				,bettype		
				,winlost		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,betfrom		
				,stake			
				,matchid		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,creator		
				,currencyName	
				,status					
				,betid			
				,transdesc		
				,refno					
				,betdaqid
				,recommend
				,mrecommend
				,srecommend
				,SecAcceptFlag
				,ExtraInfo
				,IsCashOut
				,zzzBetcheck
				,WalletType
				,RefCode
				,BonusID
				,winlostdate
				,zzzwinlost
				,modds
				,ActualStake
		)
		SELECT	z.transid
				,z.transid
				,z.custid
				,b.transdate
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.bettype
				,z.winlost - b.actual_stake
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.betfrom
				,b.stake
				,b.matchid
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,z.creator
				,b.CurrencyName
				,z.status
				,b.betid
				,b.transdesc
				,b.refno
				,b.betdaqid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.SecAcceptFlag
				,b.ExtraInfo
				,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
				,z.betcheck AS zzzBetcheck
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,m.eventdate
				,z.winlost AS zzzwinlost
				,b.modds
				,b.actual_stake AS ActualStake
		FROM	#tbTransId t		
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
					AND z.SiteDBGroupID = b.SiteDBGroupID
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON m.matchid = b.matchid
		WHERE	(m.sporttype BETWEEN 1 AND 99 OR m.sporttype = 154)
				AND b.betfrom <> 'p'
				AND ISNULL(z.comstatus,'') <> 'CO'

		-- Outright
		INSERT INTO #tblTransInfo(
				grouptransid	
				,transid		
				,custid					
				,transdate		
				,odds	
				,oddsspread				
				,oddstype		
				,bettype		
				,winlost		
				,betteam		
				,betcheck		
				,hdp1			
				,hdp2			
				,betfrom		
				,stake			
				,matchid		
				,IsLiveIndicator
				,livehomescore	
				,liveawayscore	
				,creator		
				,currencyName	
				,status					
				,betid			
				,transdesc		
				,refno					
				,betdaqid
				,recommend
				,mrecommend
				,srecommend
				,SecAcceptFlag
				,leagueid
				,homeid
				,awayid
				,zzzBetcheck
				,WalletType
				,RefCode
				,BonusID
				,winlostdate
				,SportType
				,ActualStake
		)
		SELECT	z.transid
				,z.transid
				,z.custid
				,b.transdate
				,b.odds
				,b.oddsspread
				,b.oddstype
				,b.bettype
				,z.winlost - b.actual_stake
				,b.betteam
				,b.betcheck
				,b.hdp1
				,b.hdp2
				,b.betfrom
				,b.stake
				,b.matchid
				,b.liveindicator
				,b.livehomescore
				,b.liveawayscore
				,z.creator
				,b.CurrencyName
				,z.status
				,b.betid
				,b.transdesc
				,b.refno
				,b.betdaqid
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.SecAcceptFlag
				,o.leagueid
				,o.teamid
				,0 AS awayid
				,z.betcheck AS zzzBetcheck
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,o.eventdate
				,l.sporttype
				,b.actual_stake AS ActualStake
		FROM	#tbTransId t			
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.transid = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype			
					AND z.SiteDBGroupID = b.SiteDBGroupID
			INNER JOIN dbo.outright o WITH(NOLOCK)
				ON o.orid = b.matchid
			INNER JOIN dbo.League l WITH (NOLOCK) ON o.leagueid = l.leagueid
		WHERE	z.bettype = 10
				AND b.betfrom <> 'p'
				
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS ( SELECT TOP 1 1 FROM #tblTransInfo WHERE winlostdate <= @Movebetdate )
		BEGIN
			SELECT @ErrCode = 102, @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
			RETURN	
		END			
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = 100, @ErrMsg = 'Invalid TransIds'						
			
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
		RETURN
	END CATCH

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tblTransInfo)
	BEGIN
		SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'				
		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID 
		RETURN
	END

	;WITH CTE_matchProcess AS (
		SELECT	matchid
			, CASE 
				WHEN Bettype <> 38 AND f.GroupId IS NULL THEN 1 --SB
				WHEN f.GroupId = 1 THEN 6
				WHEN Bettype = 38 THEN 5 -- Bet Builder
				WHEN f.GroupId = 2 THEN 7 -- Fast market 228
				ELSE 0 END AS KeyId
		FROM #tblTransInfo b
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	)
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT matchid, KeyId
	FROM CTE_matchProcess
	GROUP BY matchid, KeyId
	
	SELECT @isExistMatch 	= MAX(CASE WHEN KeyId = 1 THEN 1 ELSE 0 END )
		, @isExistFM 		= MAX(CASE WHEN KeyId = 6 THEN 1 ELSE 0 END )
		, @isExistBB		= MAX(CASE WHEN KeyId = 5 THEN 1 ELSE 0 END)
		, @isExistFM2		= MAX(CASE WHEN KeyId = 7 THEN 1 ELSE 0 END)
	FROM #tblMatchProcess
	
	-- checking SD proccess
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= @isExistMatch
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		SELECT @ErrCode AS ErrorCode, @ErrMsg AS ErrorMsg, @SiteDBGroupID AS SiteDBGroupID
		RETURN
	END
	
	INSERT INTO @tblBeforeBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT b.matchid
		 , b.custid
		 , 1 AS BalanceType
		 , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		 , ISNULL(b.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM   dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransInfo t
			ON	b.transid = t.grouptransid
				AND b.transid = t.transid
				AND b.matchid = t.matchid
	WHERE b.SiteDBGroupID = @SiteDBGroupID
	GROUP BY b.matchid
		   , b.custid
		   , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END	
		   , ISNULL(b.WalletType, 2) -- normal tickets are treated as cash tickets	

	UPDATE t 
		SET	leagueid = m.leagueid
			,homeid = m.homeid
			,awayid = m.awayid
			,SportType = m.sporttype
			,ParentID = CASE WHEN m.sporttype IN (50,8) THEN ISNULL(m.ParentID,0) ELSE 0 END
			,ChildMatchType = CASE WHEN m.SportType IN (50,8) THEN ISNULL(m.ChildMatchType, 0) ELSE 0 END
	FROM	#tblTransInfo t
		INNER JOIN dbo.match m WITH(NOLOCK) ON	t.matchid = m.matchid

	---- recover : normal (NOT IN 468, 469), main bettrade, main cash-out, cash-out member bet ticket
	UPDATE main
	SET winlost = 0
	    ,ruben = 0
	    ,statuswinlost = NULL
	    ,STATUS = 'running'
	    ,statusID = 0
	    ,creator = t.creator
		,actual_stake = main.actual_stake
		,odds = CASE WHEN main.bettype = 376 THEN main.oddsspread ELSE main.odds END
		,transdesc = main.transdesc
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,FcUpdateTime  = SYSDATETIME()
	OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.winlost, inserted.ruben, inserted.statuswinlost
			, inserted.statusID, inserted.creator, inserted.actual_stake, inserted.odds, inserted.transdesc, inserted.ExtraInfo, inserted.FcUpdateTime, t.bettype
	INTO @tmpTransInfo (matchid, transid, status, winlost, ruben, statuswinlost, statusID, creator, actual_stake, odds, transdesc, ExtraInfo, FcUpdateTime, bettype)
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
	WHERE t.bettype NOT IN (468, 469)
		AND ISNULL(main.betdaqid, 0) <> -2
		AND main.SiteDBGroupID = @SiteDBGroupID
		AND main.statuswinlost IS NULL

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		INSERT INTO @tmpMatchidInfo (MatchId)
		SELECT DISTINCT MatchId FROM @tmpTransInfo

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1)m
			SET IsFinish = 1, @matchid = MatchId 
			FROM @tmpMatchidInfo m
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype NOT IN (10, 38)
			FOR JSON PATH))

			IF @TransInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
			END

			--Betbuilder
			SET @TransInfo3rd = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (38)
			FOR JSON PATH))
		
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo3rd, 's', 1
			END

			SET @TransInfo3rd = NULL
			--Outright
			SET @TransInfo3rd = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, actual_stake AS 'astake'
					, odds AS 'o'
					, transdesc AS 'tdesc'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo 
			WHERE matchid = @MatchId AND bettype IN (10)
			FOR JSON PATH))
		
			IF @TransInfo3rd IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo3rd, 's', 2
			END
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
		SET @TransInfo = NULL
		SET @TransInfo3rd = NULL
	END

	--Update CashOutSelling for new CO Model
	IF EXISTS (SELECT TOP(1) 1 FROM #tblTransInfo WHERE IsCashOut = 1)
	BEGIN
		--> re-calculate stake, re-settle for main cash-out + update cash-out bet ticket			
		;WITH CTE_main_cashoutticket AS
		(
			SELECT transid
				 , 1 AS TicketType	 
				 , modds
				 , Stake	
				 , zzzwinlost AS winlost
				 , status
				 , CASE WHEN status = 'WON' THEN '112' 
						WHEN status = 'LOSE' THEN '113' 
						WHEN status = 'DRAW' THEN '111' 
					END AS StatusId
				 , creator
				 , SportType
			FROM #tblTransInfo
			WHERE IsCashOut = 1
		)

		UPDATE	b
		SET status = TCal.status
		  , statusID = TCal.StatusId
		  , stake = TRef.stake
		  , winlost = TCal.winlost
		  , awinlost = TCal.awinlost
		  , mWinLost = TCal.mWinLost
		  , swinlost = TCal.swinlost
		  , playercomm = TCal.playercomm
		  , comm = TCal.comm
		  , acomm = TCal.acomm
		  , scomm = TCal.scomm
		  , ruben = b.ruben
		  , creator = t.creator
		  , ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',b.ExtraInfo,t.SportType, b.bettype)
		  , FcUpdateTime  = SYSDATETIME()
		OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.statusID, inserted.stake
			, inserted.winlost, inserted.awinlost, inserted.mWinLost, inserted.swinlost, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.ruben, inserted.creator,inserted.ExtraInfo, inserted.FcUpdateTime
		INTO @tmpTransInfo (matchid, transid, status, statusID, stake, winlost, awinlost, mWinLost, sWinLost
				, playercomm, Comm, aComm, sComm, ruben, creator, ExtraInfo, FcUpdateTime)
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN CTE_main_cashoutticket AS t
					ON b.transid = t.transId	    			
			OUTER APPLY (
							SELECT b.stake
								 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 0 ELSE 1 END AS CommWinRate
								 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 2 ELSE 1 END AS CommLostRate
						) AS TRef		
			OUTER APPLY (SELECT CASE WHEN b.statuswinlost = 6 THEN 103 ELSE t.StatusId END AS StatusId
							 , CASE WHEN b.statuswinlost = 6 THEN 'Refund' ELSE t.status END AS status
							 , CASE WHEN b.statuswinlost = 6 THEN b.actual_stake ELSE t.winlost END AS winlost
							 , CASE
									
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.apositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.apositiontaking
								END AS awinlost
							, CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.mpositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.mpositiontaking
								END AS mWinLost
							, CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN ABS(t.winlost - b.actual_stake) * -b.spositiontaking
									WHEN t.StatusId = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.spositiontaking
								END AS swinlost
							  , CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									ELSE TRef.CommLostRate * b.stake * b.playerdiscount
								END AS playercomm
							, CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.discount * (1-apositiontaking)
								END AS comm
							,CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
								END AS acomm
							,CASE
									WHEN b.statuswinlost = 6 THEN 0
									WHEN t.StatusId = 112 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									WHEN t.StatusId = 111 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
								END AS scomm
						) AS TCal	
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpMatchidInfo (MatchId)
			SELECT DISTINCT MatchId FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId 
				FROM @tmpMatchidInfo m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;
				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, STATUS AS 's'
						, statusID AS 'sid'
						, stake AS 'stake'
						, winlost AS 'w'
						, aWinLost AS 'aw' 
						, mWinLost AS 'mw' 
						, sWinLost AS 'sw' 
						, PlayerComm AS 'pc' 
						, Comm AS 'c'  
						, aComm AS 'ac' 
						, sComm AS 'sc' 
						, ruben AS 'r'
						, creator AS 'cr'
						, ExtraInfo AS 'ex'
						, FcUpdateTime AS 'rut'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
			END

			DELETE FROM @tmpMatchidInfo
			DELETE FROM @tmpTransInfo
			SET @TransInfo = NULL
			SET @TransInfo3rd = NULL
		END

		--Update CO Selling
		UPDATE co
		SET co.CashOutStatus = 4
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling co WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblTransInfo t ON co.transid = t.grouptransid AND co.transid = t.transid
		WHERE t.IsCashOut = 1
			AND co.CashOutStatus = 6
	END
	
	---- recover: bettype ScoreBox (468, 469)
	;WITH CTE_Betcheck_1
	AS (
		SELECT t.transid
			,ROW_NUMBER() OVER (ORDER BY transid ASC) AS id
			,b.value AS betop
		FROM #tblTransInfo AS t
			CROSS APPLY STRING_SPLIT(t.betcheck, ',') AS b
		WHERE t.bettype IN (468, 469)
		)
		,CTE_Betcheck_2
	AS (
		SELECT b.transid
			,b.id
			,ROW_NUMBER() OVER (PARTITION BY b.id ORDER BY transid ASC) AS rank -- ([1]:[2])
			,CAST(op.value AS MONEY) AS value
		FROM CTE_Betcheck_1 AS b
			CROSS APPLY STRING_SPLIT(b.betop, ':') AS op
		)
		,CTE_Betcheck_Odds
	AS (
		SELECT t.transid AS transid
			,MIN(odds.value) AS odds
		FROM CTE_Betcheck_2 AS t
			LEFT JOIN CTE_Betcheck_2 AS odds ON t.transid = odds.transid
			AND t.id = odds.id
			AND odds.rank = 2
		GROUP BY t.transid
		)
		,CTE_Betcheck_Final
	AS (
		SELECT o.transid
			,score.value AS score
			,o.odds
		FROM CTE_Betcheck_Odds AS o
			LEFT JOIN CTE_Betcheck_2 AS t ON t.transid = o.transid
			AND t.rank = 2
			AND t.value = o.odds
			LEFT JOIN CTE_Betcheck_2 AS score ON score.transid = o.transid
			AND score.id = t.id
			AND score.rank = 1
		)
	UPDATE main 
	SET winlost = 0
	    ,ruben = 0
	    ,statuswinlost = NULL
	    ,STATUS = 'running'
	    ,statusID = 0
	    ,creator = t.creator
		,odds = bc.odds
		,oddsspread = bc.score
		,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(1,'recover',main.ExtraInfo,t.SportType, main.bettype)
		,FcUpdateTime  = SYSDATETIME()
	OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.winlost, inserted.ruben, inserted.statuswinlost
			, inserted.statusID, inserted.creator, inserted.odds, inserted.oddsspread, inserted.ExtraInfo, inserted.FcUpdateTime
	INTO @tmpTransInfo (matchid, transid, status, winlost, ruben, statuswinlost, statusID, creator, odds, oddsspread, ExtraInfo, FcUpdateTime)
	FROM bettrans main WITH(ROWLOCK, UPDLOCK)
		INNER JOIN #tblTransInfo t ON main.transid = t.grouptransid AND main.transid = t.transid
		LEFT JOIN CTE_Betcheck_Final AS bc ON bc.transid = t.transid
	WHERE t.bettype IN (468, 469) 
		AND main.statuswinlost IS NULL
		AND main.SiteDBGroupID = @SiteDBGroupID

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		INSERT INTO @tmpMatchidInfo (MatchId)
		SELECT DISTINCT MatchId FROM @tmpTransInfo

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1)m
			SET IsFinish = 1, @matchid = MatchId 
			FROM @tmpMatchidInfo m
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, winlost AS 'w'
					, ruben AS 'r'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, statusID AS 'sid'
					, creator AS 'cr'
					, odds AS 'o'
					, oddsspread AS 'os'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'RecoverSingleBet', 'bettrans', 'U', @matchid, @TransInfo, 's'
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
		SET @TransInfo = NULL
		SET @TransInfo3rd = NULL
	END

	/* Re-Cal for voided Transaction already has statuswinlost*/
	SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid', t.SportType AS '@sporttype', t.creator AS '@creator'
							FROM #tblTransInfo t
								INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.TransId = t.transid
							WHERE b.statuswinlost IS NOT NULL
								AND ISNULL(b.betdaqid, 0) <> -2 
								AND b.SiteDBGroupID = @SiteDBGroupID
							FOR XML PATH('r'), ROOT('root')
						)
	IF @xmlTransId <> ''
	BEGIN
		EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
			@TransIds = @xmlTransId
	END

	--Return ResettledTransIds
	SET @ResettledTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( t.TransId AS VARCHAR(20))
								FROM #tblTransInfo t
									INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.transid
								WHERE 1 = CASE WHEN ISNULL(b.betdaqid, 0) <> -2 AND b.statusID NOT IN (0,1,102) THEN 1
											WHEN b.betdaqid = -2 AND b.statusID = 103 THEN 1
											ELSE 0 END												
								FOR XML PATH ('')
							),1,1,''))
	
	-- get data after update
	INSERT INTO @tblAfterBalance(matchid, custid, balanceType, BonusID, WalletType, balance)
	SELECT b.matchid
		 , b.custid
		 , 1 AS balanceType
		 , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		 , ISNULL(b.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		 , SUM(b.winlost - b.actual_stake + b.playercomm)	AS balance
	FROM   dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tblTransInfo t
			ON	b.transid = t.grouptransid
				AND b.transid = t.transid
				AND b.matchid = t.matchid
	WHERE b.SiteDBGroupID = @SiteDBGroupID
	GROUP BY b.matchid
		   , b.custid
		   , CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
		   , ISNULL(b.WalletType, 2) -- normal tickets are treated as cash tickets	
	
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @tblBeforeBalance
		, @BalanceWalletAfter	= @tblAfterBalance
		, @ActionId				= 0				  
	
	UPDATE t 
		SET username = c.username
			,username2 = c.username2 
			,creatorName = cr.username
			,site = c.site
	FROM	#tblTransInfo t
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON	t.custid = c.custid
		INNER JOIN CustDB.dbo.Customer cr WITH(NOLOCK)
			ON	t.creator = cr.custid
	
	------ release data of TempVariableNumBer table
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= @isExistMatch
		, @isExistFM 		= @isExistFM
		, @isExistBB		= @isExistBB
		, @isExistFM2		= @isExistFM2
		, @IsReleased		= 1						
	
	DECLARE @IsITAdmin BIT = 0
	
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL, @ParentID INT= NULL, @ChildMatchType TINYINT = NULL
	DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, ParentID INT, ChildMatchType TINYINT, IsFinish BIT)

	INSERT INTO @Match_tmp (MatchId, sporttype, ParentID, ChildMatchType)
	SELECT DISTINCT t.matchid, t.sporttype, t.ParentID, t.ChildMatchType
	FROM #tblTransInfo t
		
	WHILE (1=1)
	BEGIN
		SELECT @TransIds_MaxPO = '', @MatchId_MaxPO = NULL, @sporttype = NULL, @ParentID = NULL, @ChildMatchType = NULL
		
		UPDATE TOP(1) mt SET mt.IsFinish = 1, @MatchId_MaxPO = mt.matchid, @sporttype = mt.sporttype, @ParentID = mt.ParentID, @ChildMatchType = mt.ChildMatchType
		FROM @Match_tmp mt
		WHERE mt.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
					,CASE 
						WHEN dp.custid IS NOT NULL THEN 3 --deposit 
						WHEN s.SiteLabel = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #tblTransInfo b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype
				FOR XML PATH('r'), ROOT('root')
			)

		SET @MatchId_MaxPO = CASE WHEN @sporttype IN (50,8) AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId_MaxPO END
		
		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END	
	
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	(
		SELECT DISTINCT b.custid
		FROM @tblBeforeBalance b
			INNER JOIN @tblAfterBalance a
				ON b.custid = a.custid
					AND b.matchid = a.matchid
					AND b.balanceType = a.balanceType
					AND b.bonusId = a.bonusId
					AND b.walletType = a.walletType
		WHERE	b.balance > a.balance
	)t

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
	
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ CASE WHEN @MatchId = 29 THEN  ' Main Parlay ticket with TransId: ' ELSE ' Single ticket with TransId: '  END + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransInfo
	DROP TABLE #tbTransId

	RETURN;
END