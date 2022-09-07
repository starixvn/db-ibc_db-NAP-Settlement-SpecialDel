/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverByBetId_Update]
	@TransIds		      VARCHAR(MAX), 
	@UserId			      INT,	
	@IP					  VARCHAR(50)
AS
/*
	Created: Paul
	Task: Recover by bet id
	DB: DBTXN.bodb02
	Original: 

	Revisions:
		- 20170721@Paul: Create new [RedmineID: #77175]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220825@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's Explanation:	
*/

BEGIN
	SET NOCOUNT ON;

	CREATE TABLE #TransIds (transid BIGINT PRIMARY KEY);

	CREATE TABLE #CompletedMatches (matchid INT, TransIds VARCHAR(MAX), [Action] VARCHAR(20), isFinish BIT);

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT);
	CREATE TABLE #RecoverBet (
		transid			BIGINT,
		refno			BIGINT,
		custid			INT,
		username		VARCHAR(50),
		transdate		DATETIME,
		odds			MONEY,
		stake			MONEY,
		winlost			MONEY,
		STATUS			NVARCHAR(10),
		bettype			SMALLINT,
		matchcode		NVARCHAR(50),
		OddsType		TINYINT,
		betteam			NVARCHAR(10),
		betcheck		NVARCHAR(50),
		hdp1			SMALLMONEY,
		hdp2			SMALLMONEY,
		leagueid		INT,
		IsLiveIndicator BIT,
		livehomescore	SMALLINT,
		liveawayscore	SMALLINT,
		betid			BIGINT,
		transdesc		NVARCHAR(1000),
		sporttype		SMALLINT,
		homeid			INT,
		awayid			INT,
		srecommend		INT,
		IsNeutral		BIT,
		CurrencyName	NVARCHAR(50),
		Currency		TINYINT,
		BetFrom			NVARCHAR(3),
		creator			INT,
		matchid			INT,
		EndTime			DATETIME
	);

	CREATE TABLE #TempBet (
		custid			INT,
		matchid			INT,
		bettype			SMALLINT,
		transid			BIGINT,
		username		NVARCHAR(50),
		actual_stake	MONEY,
		oddstype		TINYINT,
		srecommend		INT,
		betid			BIGINT,
		transdesc		NVARCHAR(1000),
		CurrencyName	NVARCHAR(50),
		matchcode		NVARCHAR(50),
		leagueid		INT,
		homeid			INT,
		awayid			INT,
		IsNeutral		BIT,
		sporttype		SMALLINT,
		Currency		TINYINT,
		transdate		DATETIME,
		eventdate		DATETIME,
		EndTime			DATETIME
	);

	CREATE TABLE #TempBettrans (
		custid			INT,
		matchid			INT,
		bettype			SMALLINT,
		transid			BIGINT,
		username		NVARCHAR(50),
		actual_stake	MONEY,
		oddstype		TINYINT,
		srecommend		INT,
		betid			BIGINT,
		transdesc		NVARCHAR(1000),
		CurrencyName	NVARCHAR(50),
		Currency		TINYINT,
		transdate		DATETIME
	);
	CREATE CLUSTERED INDEX ix_RecoverBet_cl ON #RecoverBet(transid);
	CREATE CLUSTERED INDEX ix_TempBet_cl ON #TempBet(custid, matchid, bettype);
	CREATE INDEX ix_TempBettrans ON #TempBettrans(matchid);

	CREATE TABLE #SupportedSports (SportType SMALLINT);

	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY, ruben TINYINT, statuswinlost MONEY, stake MONEY, statusID TINYINT, creator INT)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
	DECLARE @BeforeRecover 	TVP_BalanceChange,
			@AfterRecover 	TVP_BalanceChange;

	DECLARE @MovedBetDay	      SMALLDATETIME,
			@avaiableProcess	  BIT = 0,
			@isITAdmin			  BIT = 0,
			@ValidTransIDs		  VARCHAR(MAX),
			@ErrCode			  INT = 0,
			@ErrMsg				  NVARCHAR(MAX) = '',
			@ReCalcMatches		  VARCHAR(MAX) = '',
			@LogData			  NVARCHAR(MAX),
			@MovebetDate		  DATETIME,
			@SPName				  VARCHAR(500) = OBJECT_NAME(@@PROCID),
			@MatchId			  INT,
			@ResettleTransIds	  VARCHAR(MAX) = '',
			@Action				  VARCHAR(20),
			@TransInfo			  XML,
			@IsSiteDB			  BIT,
			@SiteDBGroupID        INT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @MovedBetDay OUTPUT
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0) --Return data for mailing

	INSERT INTO #SupportedSports(SportType)
	VALUES (175); --Bitcoin

	BEGIN TRY
		--Pare trans ID string
		INSERT INTO #TransIds (transid)		SELECT DISTINCT value 		FROM STRING_SPLIT(@TransIds, ',')
		WHERE value <> ''

		INSERT INTO #TempBettrans(
			custid,
			matchid,
			bettype,
			transid,
			username,
			actual_stake,
			oddstype,
			srecommend,
			betid,
			transdesc,
			CurrencyName,
			Currency,
			transdate
		)
		SELECT	b.custid,
				b.matchid,
				b.bettype,
				b.transid,
				b.username,
				b.actual_stake,
				b.oddstype,
				b.srecommend,
				b.betid,
				b.transdesc,
				b.CurrencyName,
				b.currency,
				b.transdate
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #TransIds t WHERE t.transid = b.transid)
			AND b.winlostdate >= @MovedBetDay AND b.SiteDBGroupID = @SiteDBGroupID
			AND b.betfrom <> 'p';

		------159948 - Support Bitcoin
		INSERT INTO #TempBet(
			custid,
			matchid,
			bettype,
			transid,
			username,
			actual_stake,
			oddstype,
			srecommend,
			betid,
			transdesc,
			CurrencyName,
			matchcode,
			leagueid,
			homeid,
			awayid,
			IsNeutral,
			sporttype,
			transdate,
			eventdate,
			EndTime
		)
		SELECT	b.custid,
				b.matchid,
				b.bettype,
				b.transid,
				b.username,
				b.actual_stake,
				b.oddstype,
				b.srecommend,
				b.betid,
				b.transdesc,
				b.CurrencyName,
				m.MatchNo AS matchcode,
				m.League3rdId AS leagueid,
				m.HomeId,
				m.AwayId,
				NULL AS IsNeutral,
				m.sporttype,
				b.transdate,
				m.eventdate,
				m.EndTime
		FROM #TempBettrans b
			INNER JOIN dbo.Match3rd m WITH(NOLOCK) ON m.Match3rdId = b.matchid
		WHERE EXISTS (SELECT 1 FROM #SupportedSports s WHERE s.SportType = m.sporttype);

		IF NOT EXISTS(SELECT TOP 1 1 FROM #TempBet)
		BEGIN
			SELECT	@ErrCode = 101,
					@ErrMsg = 'All trans ID of unsupported sports';
		END
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100,
				@ErrMsg = 'Invalid TransIds';
	END CATCH

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	IF @ErrCode = 0 AND EXISTS (SELECT TOP 1 1 FROM #TempBet WHERE EventDate <= @MovebetDate)
	BEGIN
		SELECT @ErrCode = 102
			  ,@ErrMsg = 'Could not void some tickets due to Movebet process. Please try Search again.'
	END

	IF @ErrCode = 0
	BEGIN
		--Get tickets from zzzbettrans
		INSERT INTO #RecoverBet (
			transid,
			refno,
			username,	
			transdate,	
			odds,
			stake,
			winlost,
			STATUS,
			bettype,
			matchcode,
			OddsType,					
			betteam,		
			betcheck,		
			hdp1,			
			hdp2,		
			srecommend,		
			IsLiveIndicator,
			livehomescore,	
			liveawayscore,						
			betid,
			transdesc,
			leagueid,
			sporttype,
			homeid,
			awayid,
			custid,
			IsNeutral,
			CurrencyName,
			Currency,
			BetFrom,
			creator,
			matchid,
			EndTime
		)
		SELECT	z.transid,
				z.refno,
				b.Username,		
				b.transdate,
				z.odds,
				z.stake,
				z.winlost - b.actual_stake,
				z.STATUS,
				z.bettype,
				b.matchcode,
				b.oddstype,				
				z.betteam,
				z.betcheck,
				z.hdp1,
				z.hdp2,
				b.srecommend,
				z.liveindicator,
				z.livehomescore,
				z.liveawayscore,	
				b.betid,
				b.transdesc,
				b.leagueid,
				b.sporttype,
				b.homeid,
				b.awayid,
				z.custid,
				b.IsNeutral,
				b.CurrencyName,
				b.currency,
				z.betfrom,
				z.creator,
				b.matchid,
				b.EndTime
		FROM dbo.zzzbettrans z WITH(NOLOCK)
			INNER JOIN #TempBet b 
				ON z.transid = b.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid					
					AND z.bettype = b.bettype
		WHERE z.SiteDBGroupID = @SiteDBGroupID

		--Check SD process and lock
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT	DISTINCT matchid, 8 AS KeyID --Bitcoin 
		FROM #RecoverBet;

		EXEC dbo.NAP_Admin_CheckingProcess 
			  @isExistMatch3rd = 1
			, @SPName	       = @SPName
			, @avaiableProcess = @avaiableProcess OUTPUT
			, @ErrCode		   = @ErrCode OUTPUT
			, @ErrMsg          = @ErrMsg OUTPUT;
		
		SELECT @ValidTransIDs = STUFF((SELECT ',' + CAST(transid AS VARCHAR(MAX))
									   FROM #RecoverBet
									   FOR XML PATH('')
									   ), 1, 1, '');	
		
		--Capture balance before Recover
		INSERT INTO @BeforeRecover (
			custid,
			balanceType,
			balance
		)
		SELECT	custid,
				BalanceType,
				SUM(balance) AS balance
		FROM dbo.f_GetBalanceByTransID(@ValidTransIDs)
		GROUP BY custid, BalanceType
	
		--Recover tickets
		UPDATE b 
		SET	winlost = 0,
			ruben = 0,
			statuswinlost = NULL,
			STATUS = 'running',
			statusID = 0,
			creator = r.creator
		OUTPUT deleted.matchid, deleted.TransId, inserted.winlost, inserted.ruben, '', inserted.status, inserted.statusID, inserted.creator
		INTO @tmpTransInfo (matchid, transid, winlost, ruben, statuswinlost, status, statusID, creator) 
		FROM dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #RecoverBet r ON b.transid = r.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID

		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo )
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
				SET @TransInfo = (
				SELECT	matchid AS '@mid'
						, transId AS '@t'
						, STATUS AS '@s'
						, winlost AS '@w'
						, ruben AS '@r'
						, statuswinlost AS '@statuswl'
						, statusID AS '@sid'
						, creator AS '@cr'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR XML PATH('r'),ROOT('root'), TYPE)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
				SELECT 'TVS', 'RecoverByBetID', 'bettrans', 'U', @matchid, @TransInfo 
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo
		END

		--Capture balance after Recover
		INSERT INTO @AfterRecover (
			custid,
			balanceType,
			balance
		)
		SELECT	custid,
				BalanceType,
				SUM(balance) AS balance
		FROM dbo.f_GetBalanceByTransID(@ValidTransIDs)
		GROUP BY custid, BalanceType

		--Insert balance pending
		EXEC [dbo].[NAP_Admin_BalancePendingIns] @BeforeUpd = @BeforeRecover, @AfterUpd = @AfterRecover;

		--Delete recovers tickets
		INSERT INTO @tmpTransInfo (matchid, transid)
		SELECT z.matchid, z.transid
		FROM zzzbettrans z WITH(NOLOCK)
			INNER JOIN #RecoverBet r ON z.custid = r.custid AND z.matchid = r.matchid AND z.bettype = r.bettype AND z.transid = r.transid
		WHERE z.SiteDBGroupID = @SiteDBGroupID 

		DELETE z WITH(UPDLOCK, ROWLOCK)
		FROM zzzbettrans z
			INNER JOIN @tmpTransInfo t ON z.matchid = t.matchid AND z.transid = t.transid;
		
		IF @IsSiteDB = 1 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
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
				SET @TransInfo = (
				SELECT	matchid AS '@mid'
						, transId AS '@t'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR XML PATH('r'),ROOT('root'), TYPE)

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
				SELECT 'TVS', 'RecoverByBetID', 'zzzbettrans', 'D', @matchid, @TransInfo 
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo
		END

		--Return completed matches to resettle
		INSERT INTO #CompletedMatches(matchid, [Action])
		SELECT m.Match3rdId
			  ,CASE WHEN m.BetStatus LIKE 'Refund%' THEN 'REFUND'
					WHEN m.BetStatus IS NULL THEN 'CAL' 
					END AS [Action]
		FROM dbo.Match3rd m WITH(NOLOCK)
		WHERE m.EventStatus = 'completed'
			AND EXISTS (SELECT 1 FROM #RecoverBet r WHERE r.matchid = m.Match3rdId);
		
		UPDATE m
		SET TransIds = STUFF(ts.TransIds,1,1,'')
		FROM #CompletedMatches m
		CROSS APPLY (SELECT ',' + CAST(r.TransId AS VARCHAR(MAX)) 
					 FROM #RecoverBet r
					 WHERE r.matchid = m.matchid
					 FOR XML PATH('')
					 )ts(TransIds)

		SELECT @ReCalcMatches = STUFF((SELECT ', ' + CAST(matchid AS VARCHAR(MAX))
										FROM #CompletedMatches
										FOR XML PATH('')
										), 1, 2, '');

		--> automatically re-settlement Bitcoin
		WHILE (1=1)
		BEGIN
			UPDATE TOP(1) m SET isFinish = 1, @MatchId = m.matchid, @ResettleTransIds = m.TransIds, @Action = m.[Action]
			FROM #CompletedMatches m
			WHERE isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			EXEC dbo.NAP_SpecialDelete_RecoverByBetId_ReCal_s175
			        @MatchId      = @MatchId
				   ,@TransIds	  = @ResettleTransIds
			       ,@Action       = @Action
			       ,@ErrCode      = @ErrCode OUTPUT
			       ,@ErrMsg       = @ErrMsg OUTPUT
		END

		--Check SD process and release
		EXEC dbo.NAP_Admin_CheckingProcess 
			  @isExistMatch3rd = 1
			, @IsReleased = 1;

		SELECT @LogData = 'Recovered bets having transid: ' + @ValidTransIDs + ' IP: ' + @Ip;
	
		EXEC WriteLog_UserLog @UserId = @UserId, @Doing = @LogData;

	END

	------------------------------------------------------------------------------
	--1. Table return error code/ msg
	SELECT @ErrCode AS ErrorCode
		  ,@ErrMsg AS ErrorMsg
		  ,@ReCalcMatches AS ReCalcMatches

	--2. Table get tickets
	SELECT	CASE WHEN d.custid IS NULL THEN 'Credit' ELSE 'Deposit' END AS GroupName,
			t.transid,
			t.refno,
			t.username,
			t.transdate,
			t.odds,
			t.stake,
			t.winlost,
			t.STATUS,
			t.bettype,
			t.OddsType,
			t.betteam,
			t.betcheck,
			t.hdp1,
			t.hdp2,
			t.leagueid,
			t.IsLiveIndicator,
			t.livehomescore,
			t.liveawayscore,
			t.betid,
			t.transdesc,
			t.sporttype AS SportTypeId,
			t.homeid,
			t.awayid,
			t.matchcode,
			t.IsNeutral,
			t.CurrencyName,
			CURRENT_TIMESTAMP AS [DateTime],
			t.Currency,
			@isITAdmin AS IsItSupport,
			t.BetFrom,
			t.matchid,
			t.EndTime
	FROM #RecoverBet t
		LEFT JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) ON t.srecommend = d.custid
	ORDER BY GroupName, transid;

	DROP TABLE #TransIds
	DROP TABLE #CompletedMatches
	DROP TABLE #tblMatchProcess
	DROP TABLE #RecoverBet
	DROP TABLE #TempBet
	DROP TABLE #TempBettrans
	DROP TABLE #SupportedSports
	SET NOCOUNT OFF;
END
GO