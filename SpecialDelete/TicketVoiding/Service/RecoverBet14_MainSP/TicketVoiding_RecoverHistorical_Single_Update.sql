/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_RecoverHistorical_Single_Update
(
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX) 
	,@UserId			INT = 0 
	,@IP				VARCHAR(15) =''
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(1000)	= ''	OUTPUT
	,@FailedTransIds    VARCHAR(MAX) = '' OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT
	,@ResettledTransIds   VARCHAR(MAX)	= NULL	OUTPUT
)
AS
/*	
	Created by: Kathy
	Date 20190823
	Task: recover single ticket [Redmine:#115376]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20190823@Kathy: recover single ticket [Redmine:#115376]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20210514@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20220808@July: Change function to STRING_SPLIT [Redmine: #175412]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

			,@avaiableProcess	BIT
			,@isExistFM			BIT
			,@isExistFM2		BIT = 0
			,@isExistMatch		BIT
			,@AffectedList		VARCHAR(MAX)
			,@SiteDBGroupID     SMALLINT = 0
			,@TransInfo			VARBINARY(MAX)
	
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	

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
	
	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY, ruben TINYINT, statuswinlost TINYINT, stake MONEY
			, statusID TINYINT, creator INT, actual_stake MONEY, odds SMALLMONEY, oddsspread MONEY, transdesc NVARCHAR(2000), ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, transdate DATETIME, comstatus NVARCHAR(40)
			, bettype SMALLINT
			)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	/*Modify the way to get move bet date*/
	DECLARE @BeingMovebetDate SMALLDATETIME 
		   ,@currentdate SMALLDATETIME = GETDATE()

	DECLARE @tblTransId_MoveBet TABLE (MatchId INT, TransId BIGINT)
		
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @BalanceInfoBeforeUpd TABLE (
		CustId			INT
		,MatchId		INT
		,WinlostDate	DATETIME
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,playerComm		MONEY
		,Comm			MONEY
		,aComm			MONEY
		,sComm			MONEY
		,stake			MONEY
		,actual_stake	MONEY

		,balance		MONEY
	)
	DECLARE @BalanceInfoAfterUpd TABLE (
		CustId			INT
		,MatchId		INT
		,WinlostDate	DATETIME
		,Winlost		MONEY
		,aWinlost		MONEY
		,mWinlost		MONEY
		,sWinlost		MONEY
		,playerComm		MONEY
		,Comm			MONEY
		,aComm			MONEY
		,sComm			MONEY
		,stake			MONEY
		,actual_stake	MONEY

		,balance		MONEY
	)

	DECLARE @tmpInputTransId TABLE(
		TransId BIGINT
		,invalid TINYINT DEFAULT(0)
	)

	CREATE TABLE #tmpTransId (
		TransId			BIGINT
		,MatchId		INT
		,CustId			INT
		,Bettype		SMALLINT
		,ExtraInfo		XML
		,IsAbnormalBet	BIT DEFAULT(0)
		,KeyId			TINYINT DEFAULT(1)
		,Invalid		TINYINT DEFAULT(0)
		,sporttype			SMALLINT
		,eventdate			DATETIME
		,oddsid				INT
		,winlostdate		SMALLDATETIME
	)
	CREATE TABLE #tblMatch (matchid INT)
	CREATE TABLE #tblMatchProcess (MatchId INT, KeyID TINYINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90200
	SET @SB_Error = 0

	SET @ErrCode = 0
	SET @ErrMsg = ''

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')

	INSERT INTO #tmpTransId (TransId, MatchId, CustId, Bettype, KeyId, invalid, oddsid, winlostdate)
	SELECT	b14.transid
			,b14.matchid
			,b14.custid
			,b14.bettype
			,CASE 
				WHEN f.GroupId = 1 THEN 6
				WHEN f.GroupID = 2 THEN 7
				ELSE 1
			END AS KeyId
			,CASE 
				WHEN b14.statuswinlost IS NULL OR b14.statuswinlost NOT BETWEEN 0 AND 6 THEN 2 -- not have 'statuswinlost' value
				ELSE 0
			END AS invalid
			,b14.oddsid
			,b14.winlostdate
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK)
			ON	t.TransId = b14.transid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b14.Bettype
			)f
	WHERE	b14.statusID = 102
			AND b14.betfrom <> 'p'
			AND b14.bettype NOT IN (10, 29)
			AND b14.bettype NOT BETWEEN 801 AND 806
			AND b14.bettype NOT BETWEEN 8101 AND 8120
			AND b14.bettype NOT BETWEEN 81 AND 120
			AND b14.bettype NOT BETWEEN 1201 AND 1299
			AND b14.bettype NOT BETWEEN 2700 AND 2899
			AND b14.SiteDBGroupID = @SiteDBGroupID
			
	
	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'

		RETURN
	END	

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET eventdate 	= m.eventdate
			,sporttype 	= m.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.match14 m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (9, 29, 2799)		
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET eventdate 	= o.eventdate
			,sporttype	= l.sporttype
		FROM	#tmpTransId b
			INNER JOIN dbo.outright14 AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid			
		WHERE bettype IN (10)
	END
		
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET eventdate	= o.eventdate
			,sporttype 	= r.sporttype	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
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

	IF EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (9,29,2799))
	BEGIN
		UPDATE #tmpTransId
		SET eventdate = winlostdate
		WHERE bettype IN (9,29,2799)	
	END

	UPDATE t 
		SET invalid = i.invalid
	FROM	@tmpInputTransId t
		LEFT JOIN #tmpTransId r
			ON t.TransId = r.TransId
		OUTER APPLY (
			SELECT CASE 
						WHEN EXISTS (SELECT TOP 1 1 FROM dbo.bettrans b WITH(NOLOCK) WHERE b.transid = t.TransId AND b.statusID = 102) THEN 3  -- data has not been moved yet
						WHEN r.transId IS NULL THEN 1 -- not pass validation rule
						WHEN r.invalid > 0 THEN r.invalid
					END AS invalid
		) AS i
			
	-- get current beingmovebetdate if movebet in-progress, paste @currentdate to get @BeingMovebetDate only
	EXEC [dbo].[NAP_Admin_VerifySettleDate] @Winlostdate = @currentdate, @BeingMovebetDate = @BeingMovebetDate OUTPUT

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE Eventdate = @BeingMovebetDate)
	BEGIN	
		DELETE 
		FROM #tmpTransId
			OUTPUT	DELETED.matchid, DELETED.TransId
			INTO  @tblTransId_MoveBet (Matchid, TransId)
		WHERE eventdate = @BeingMovebetDate

		SET @ErrCode = 99 
		SET @MoveBetMatchIds = CAST((SELECT DISTINCT t.MatchId "@MatchId"
									  , CASE WHEN t.MatchId IN (9,29,2799) THEN  STUFF(ts.TransIds,1,1,'') ELSE NULL END "@TransIds"
								FROM @tblTransId_MoveBet t
									OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
													FROM @tblTransId_MoveBet s
													WHERE s.MatchId = t.MatchId AND t.MatchId IN (9,29,2799)
													FOR XML PATH('')
												)ts	 (TransIds)
								FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
	END
	
	-- gather match Ids
	INSERT INTO #tblMatch (matchid)
	SELECT	matchid
	FROM	#tmpTransId
	GROUP BY matchid
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpInputTransId WHERE invalid > 0)
	BEGIN
		DECLARE @Msg VARCHAR(MAX) = ''

		SET @ErrCode = 100
		SET @ErrMsg = ''

		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 1

		IF @@rowcount > 0
			SELECT	@ErrCode = 100
			SET @ErrMsg = 'Invalid transid: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''		
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 2

		IF @@rowcount > 0
			SELECT	@ErrCode = 101
			SET @ErrMsg = @ErrMsg + 'Existing data but do not have statuswinlost value: ' + STUFF(@Msg, 1, 1, '') + '. '

		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 3

		IF @@rowcount > 0
			SELECT	@ErrCode = 102
			SET @ErrMsg = @ErrMsg + 'Existing but data has not been moved yet: ' + STUFF(@Msg, 1, 1, '') + '. '
		
		SET @Msg = ''
		SELECT	@Msg = @Msg + ',' + CAST(TransId AS VARCHAR)
		FROM	@tmpInputTransId
		WHERE	invalid = 4

		IF @@rowcount > 0
			SET	@ErrCode = 99
			SET @ErrMsg = @ErrMsg + 'Could not recover some tickets due to Movebet process. Please try Search again: ' + STUFF(@Msg, 1, 1, '') + '. '
			
		RETURN
				
	END
	
	IF @IP IS NULL OR @UserId IS NULL
	BEGIN
		SET @ErrCode = 100
		SET @ErrMsg = @ErrMsg + 'IP and UserID must be inputted.'
		
		RETURN
	END
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	MatchId, KeyId
	FROM	#tmpTransId
	GROUP BY MatchId, KeyId
	
	SELECT	@isExistFM = CASE WHEN KeyID = 6 THEN 1 ELSE 0 END
			,@isExistMatch = CASE WHEN KeyID = 1 THEN 1 ELSE 0 END
			, @isExistFM2 = CASE WHEN KeyID = 7 THEN 1 ELSE 0 END
	FROM	#tblMatchProcess

	EXEC dbo.NAP_Admin_CheckingProcess
		 @isExistFM = @isExistFM
		, @isExistMatch	= @isExistMatch
		, @isExistFM2 = @isExistFM2
		, @avaiableProcess = @avaiableProcess OUTPUT
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		RETURN
	END

	INSERT INTO @BalanceInfoBeforeUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.awinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)

			,SUM(b14.winlost - b14.actual_stake + b14.playercomm) 
	FROM	dbo.bettrans14 b14 WITH(NOLOCK)
		INNER JOIN #tmpTransId t
			ON t.TransId = b14.transid
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate

	INSERT INTO @BeforeUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 AS BonusID
			,2 AS WalletType -- normal tickets are treated as cash tickets
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoBeforeUpd b14
	GROUP BY b14.custid
			,b14.matchid

	BEGIN TRY
		EXEC dbo.NAP_Admin_Calculate_Bet14 
			@TransIds = @TransIds
			,@MatchId = @MatchId
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = 100
				,@ErrMsg = ERROR_MESSAGE()
	END CATCH

	--Update CashOutSelling for new CO Model
	IF EXISTS (SELECT TOP(1) 1 FROM @tmpInputTransId t
						INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
				WHERE b.betdaqid = -2)
	BEGIN
		BEGIN TRY
			INSERT INTO #tblTransInfo (transid, modds, stake, zzzwinlost, status, creator, matchid)
			SELECT t.TransId, b.modds, b.stake, z.winlost, z.status, z.creator, b.matchid
			FROM @tmpInputTransId t
				INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	b.transid = z.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid
						AND z.bettype = b.bettype
						AND z.SiteDBGroupID = b.SiteDBGroupID
			WHERE b.betdaqid = -2
				AND ISNULL(z.comstatus,'') <> 'CO'

			UPDATE t SET t.SportType = m.sporttype
			FROM #tblTransInfo t
				CROSS APPLY (
					SELECT Sporttype
					FROM dbo.match14 WITH (NOLOCK)
					WHERE matchid = t.matchid
					UNION
					SELECT Sporttype
					FROM dbo.match WITH (NOLOCK)
					WHERE matchid = t.matchid
				)m

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
			OUTPUT deleted.matchid, deleted.transid, inserted.STATUS, inserted.statusID, inserted.stake
				, inserted.winlost, inserted.awinlost, inserted.mWinLost, inserted.swinlost, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
				, inserted.ruben, inserted.creator,inserted.ExtraInfo
			INTO @tmpTransInfo (matchid, transid, status, statusID, stake, winlost, awinlost, mWinLost, sWinLost
					, playercomm, Comm, aComm, sComm, ruben, creator, ExtraInfo)
			FROM dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
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
					FROM	@tmpTransInfo WHERE matchid = @MatchId 
					FOR JSON PATH))

					INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
					SELECT 'TVS', 'RecoverSingleBet', 'bettrans14', 'U', @matchid, @TransInfo, 's'
				END

				DELETE FROM @tmpMatchidInfo
				DELETE FROM @tmpTransInfo
				SET @TransInfo = NULL
			END

			--Update CO Selling
			UPDATE co
			SET co.CashOutStatus = 4
			   ,ChangeDate = GETDATE()
			FROM dbo.CashOutSelling co WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #tblTransInfo t ON co.transid = t.transid
			WHERE co.CashOutStatus = 6
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 100
					,@ErrMsg = ERROR_MESSAGE()
		END CATCH
	END

	INSERT INTO @BalanceInfoAfterUpd (CustId, MatchId, WinlostDate, Winlost, aWinlost, mWinlost, sWinlost, playerComm, Comm, aComm, sComm, stake, actual_stake, balance)
	SELECT	b14.custid
			,b14.matchid
			,b14.winlostdate
			,SUM(b14.winlost)
			,SUM(b14.awinlost)
			,SUM(b14.mwinlost)
			,SUM(b14.swinlost)
			,SUM(b14.playercomm)
			,SUM(b14.comm)
			,SUM(b14.acomm)
			,SUM(b14.scomm)
			,SUM(b14.stake)
			,SUM(b14.actual_stake)

			,SUM(b14.winlost - b14.actual_stake + b14.playercomm)
	FROM	dbo.bettrans14 b14 WITH(NOLOCK)
		INNER JOIN #tmpTransId t
			ON t.TransId = b14.transid
	GROUP BY b14.custid
			,b14.matchid
			,b14.winlostdate

	INSERT INTO @AfterUpd (matchid, custid, balanceType, bonusId, walletType, balance)
	SELECT	b14.matchid
			,b14.custid
			,1 AS BalanceType
			,0 BonusID
			,2 AS WalletType -- normal tickets are treated as cash tickets
			,SUM(b14.balance) AS balance
	FROM	@BalanceInfoAfterUpd b14
	GROUP BY b14.custid
			,b14.matchid

	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		  @BalanceWalletBefore	= @BeforeUpd
		, @BalanceWalletAfter	= @AfterUpd
		, @ActionId				= 0

	--Return ResettledTransIds
	SET @ResettledTransIds = (STUFF((SELECT DISTINCT  ',' + CAST( t.TransId AS VARCHAR(20))
								FROM @tmpInputTransId t
									INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
								WHERE 1 = CASE WHEN ISNULL(b.betdaqid, 0) <> -2 AND b.statusID NOT IN (0,1,102) THEN 1
											WHEN b.betdaqid = -2 AND b.statusID = 103 THEN 1
											ELSE 0 END												
								FOR XML PATH ('')
							),1,1,''))
	
	SET @AffectedList = CAST((
		SELECT	CustId AS '@c'
				,WinlostDate AS '@w'
				,SUM(stake) AS '@st'
				,SUM(actual_stake) AS '@ast'
				,SUM(Winlost) AS '@w_dif'
				,SUM(aWinlost) AS '@aw_dif'
				,SUM(mWinlost) AS '@mw_dif'
				,SUM(sWinlost) AS '@sw_dif'
				,SUM(playerComm) AS '@pc_dif'
				,SUM(Comm) AS '@c_dif'
				,SUM(aComm) AS '@ac_dif'
				,SUM(sComm) AS '@sc_dif'
		FROM	@BalanceInfoAfterUpd 
		GROUP BY CustId
				,WinlostDate
		FOR XML PATH('r'), ROOT('root'), TYPE
	) AS VARCHAR(MAX))

	IF @ErrCode <> 0
	BEGIN
		------ release data of TempVariableNumBer table
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @isExistFM 		= @isExistFM
			, @isExistFM2		= @isExistFM2
			, @IsReleased		= 1	
	END
	ELSE
	BEGIN
		-- release data of TempVariableNumBer table
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= @isExistMatch
			, @isExistFM 		= @isExistFM
			, @isExistFM2		= @isExistFM2
			, @IsReleased		= 1	

		BEGIN TRY
			-- update summary ticket
			EXEC dbo.TicketVoiding_Admin_Bet14_19999 
				@AffectedList = @AffectedList
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 100
					,@ErrMsg = ERROR_PROCEDURE () + ERROR_MESSAGE()
		END CATCH
	END

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'TransId: ' + @TransIds 
								+ ' AffectedList: ' + ISNULL(@AffectedList,'')
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tblMatch
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransId
	DROP TABLE #tblTransInfo
END
GO
