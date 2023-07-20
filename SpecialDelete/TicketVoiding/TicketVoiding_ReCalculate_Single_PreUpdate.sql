/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
(
	@MatchId		 INT,	
	@TransIds		 VARCHAR(MAX),
	@UserId          INT           = 0,
    @IP              VARCHAR(15)   = NULL,
	@IsLockMatch	 BIT				= 1,
	@ErrMsg					NVARCHAR(200) = '' OUTPUT,
	@ErrCode					INT           = 0 OUTPUT,
	@NegativeBalanceUsers		VARCHAR(MAX) = NULL OUTPUT
)
AS
/*	Created by: 20200212@Max
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]	
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220307@Max: TVS - Miss update balance when update request abnormal mix parlay [Redmine: #169600]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220808@Max: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230303@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230707@July: Remove unnecessary code [Redmine: #190859]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ThreadHold				INT = 0-- over threadhold, the parlay process will be locked in systemsetting 
			,@totalMainParlay			INT = 0
			,@MainParlay_MaxPO			VARCHAR(MAX) = NULL
			,@avaiableProcess			BIT
			,@isExistFM					BIT = 0
			,@isExistFM2				BIT = 0
			,@IsExistBB					BIT = 0
			,@isExistMatch				BIT = 0
			,@session					NVARCHAR(50)
			,@CustIds					VARCHAR(MAX)
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
	
	DECLARE @LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@xmlTransId		VARCHAR(MAX)
			,@refnos_29			VARCHAR(MAX) = '' 
			,@SiteDBGroupID		SMALLINT = 0 

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)

	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange
	
	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,Refno				BIGINT
		,balanceType		TINYINT
		,betid				BIGINT
		,sporttype			SMALLINT
		,MatchId			INT
		,OddsId				INT
		,ruben				TINYINT
	)

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	INSERT INTO @tmpInputTransId (TransId)
	SELECT	value AS TransId
	FROM STRING_SPLIT(@TransIds, ',')

	SET @LogActionId = 90503
	SET @SB_Error = 0
	SET @session = CAST(NEWID() AS NVARCHAR(50))

	INSERT INTO #tmpTransId(TransId, custid, bettype, balanceType, betid, Refno, MatchId, OddsId, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,1 AS balanceType
			, b.betid, b.refno
			, @MatchId
			, b.oddsid
			, b.ruben
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	WHERE	b.statusID <> 102
		AND b.SiteDBGroupID = @SiteDBGroupID

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
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		)


	IF EXISTS (SELECT TOP 1 1  FROM #tmpTransId)
	BEGIN
		IF @IsLockMatch = 1
		BEGIN
			IF @MatchId = 29
			BEGIN
				SET @isExistParlay = 1

				INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
				SELECT @MatchId, v.Refno
				FROM #tmpTransId v
	
				EXEC dbo.NAP_Set_GlobalSettingSel 
					 @LockName = 'ParlayRefno'
					,@ThreadHold = @ThreadHold OUTPUT

				SET @totalMainParlay = @@ROWCOUNT
			END
			ELSE
			BEGIN
				SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
						,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
						,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
						,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
						,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
						,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
						,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
						,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
						,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
						,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
						,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
						,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
				FROM	#tmpTransId v

					OUTER APPLY (
								SELECT GroupId
								FROM dbo.f_TVS_CheckingProcessGroupBettypes()
								WHERE Bettype = v.Bettype
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
			END

			--Lock Match
			IF @isExistParlay = 1
			BEGIN
				-- Apply new way to lock parlay tickets	
				IF @totalMainParlay <= @ThreadHold
				BEGIN
					-- checking Refno parlay proccess
					EXEC dbo.NAP_Admin_CheckingProcess
						@IsLockingByRefno	= 1
						,@spName			= @spName
						,@Session			= @Session
						,@avaiableProcess 	= @avaiableProcess OUTPUT
						,@ErrCode			= @ErrCode OUTPUT
						,@ErrMsg			= @ErrMsg OUTPUT

					IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
					BEGIN	
						RETURN;		
					END
	
				END
				ELSE --@totalSubParlay > 10K
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess
						@isExistParlay 			= @isExistParlay
						,@avaiableProcess 		= @avaiableProcess OUTPUT
						,@ErrCode				= @ErrCode OUTPUT
						,@ErrMsg				= @ErrMsg OUTPUT

					IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
					BEGIN	
						RETURN;		
					END
				END
			END
			ELSE
			BEGIN
				-- checking single proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @spName					= @spName
					, @avaiableProcess 			= @avaiableProcess OUTPUT
					, @ErrCode					= @ErrCode OUTPUT
					, @ErrMsg					= @ErrMsg OUTPUT
			
				IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
					BEGIN	
						RETURN;		
					END
			END
		END

		--capture balance before
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
					,t.balanceType
					,CASE 
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId t
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid
			WHERE b.SiteDBGroupID = @SiteDBGroupID
		)b
		GROUP BY b.custid
				,b.balanceType
				,b.BonusID
				,b.WalletType

		--ReCalculate
		BEGIN TRY						
			IF @MatchId = 29 
			BEGIN
				SET @refnos_29 =''
							SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
							FROM #tmpTransId  
							WHERE bettype = 29 
							GROUP BY refno, transid
							SET @refnos_29 = STUFF(@refnos_29,1,1,'')

				EXEC dbo.NAP_Admin_Calculate_MP_broker  
						@matchdate = ''  
						,@strXML = @refnos_29  
						,@mode  = '29'  
			END
			ELSE
			BEGIN
				SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
										FROM	@tmpInputTransId t
										FOR XML PATH('r'), ROOT('root')
									)

				EXEC dbo.TicketVoiding_ReCalculate_Single_Update @TransIds = @xmlTransId
			END
		END TRY
	
		BEGIN CATCH
		
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
						,t.balanceType
						,CASE 
							WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
							ELSE 0 END AS BonusID
						,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
						,b.winlost - b.actual_stake + b.playercomm AS balance
				FROM	#tmpTransId t
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid
				WHERE b.SiteDBGroupID = @SiteDBGroupID
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
			
			SELECT @ErrCode = 100
				, @ErrMsg = 'Called TicketVoiding_ReCalculate_Single_Update with error.'
		
			RETURN	
			
		END CATCH
	
		-- Capture balance before
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
					,t.balanceType
					,CASE 
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId t
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid
			WHERE b.SiteDBGroupID = @SiteDBGroupID
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
			
		IF @IsLockMatch = 1
		BEGIN
			IF @isExistParlay = 1
			BEGIN
				IF @totalMainParlay <= @ThreadHold
				BEGIN
					------ releasing Refno parlay proccess
					EXEC dbo.NAP_Admin_CheckingProcess
						@IsLockingByRefno = 1
						,@Session	= @Session
						,@IsReleased = 1	
				END
				ELSE IF @totalMainParlay > @ThreadHold
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess
						@isExistParlay 				= @isExistParlay
						, @IsReleased				= 1
				END
			END
			ELSE
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
			END
		END

		----------------Insert Max Payout Queue----------------
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 29)
		BEGIN
			--Prepare for Max Payout
			SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
										,t.ruben AS '@ruben'
										,t.transid AS '@transid'
									FROM #tmpTransId t
									GROUP BY custid, ruben, transid
									FOR XML PATH('r'), ROOT('root')
								)

			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
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
	END
	-- Write Log
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@MatchId AS '@MatchId'
							,@IP AS '@IP'
							,'TransId: ' + @TransIds 
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tmpTransId
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblMatchParlayProcess
END