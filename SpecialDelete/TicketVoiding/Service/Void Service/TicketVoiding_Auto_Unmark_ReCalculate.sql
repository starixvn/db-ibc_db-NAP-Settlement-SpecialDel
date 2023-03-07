/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Auto_Unmark_ReCalculate]
(
	@MatchId		 INT,	
	@TransIds		 VARCHAR(MAX),
	@UserId          INT           = 0,
    @IP              VARCHAR(15)   = NULL
)
AS
/*	
	Created by: Max
	Date 20230303
	Task: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20230303@Max: Create new SP [Redmine: #180625]	

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SB_Error					BIT
			,@spName					VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ThreadHold				INT = 0-- over threadhold, the parlay process will be locked in systemsetting 
			,@totalMainParlay			INT = 0
			,@MainParlay_MaxPO			VARCHAR(MAX) = NULL
			,@avaiableProcess			BIT
			,@isExistMG					BIT = 0
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
			,@isExistLucky3				BIT = 0
			,@ErrMsg					NVARCHAR(300) = ''
			,@ErrCode					INT           = 0
			,@NegativeBalanceUsers		VARCHAR(MAX) = NULL
			,@limitsecond				INT	= 30
			,@StartTime_Retry			DATETIME
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@xmlTransId		VARCHAR(MAX)
			,@refnos_29				 VARCHAR(MAX) = '' 
			,@SiteDBGroupID SMALLINT = 0 

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

	SET @StartTime = GETDATE()
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
					,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
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
					,@isExistLucky3				= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
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

		
		--Retry lock match in 30s
		SET @StartTime_Retry= GETDATE()
		WHILE (1=1)
		BEGIN
			SELECT @ErrCode = 0
				,@ErrMsg = ''

			IF DATEDIFF(SECOND, @StartTime_Retry, GETDATE()) > @limitsecond
			BEGIN
				SELECT 100 AS ErrCode,
					'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.' AS ErrMsg

				RETURN;
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
						CONTINUE;		
					END
					ELSE
					BEGIN
						BREAK;
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
						CONTINUE;		
					END
					ELSE
					BEGIN
						BREAK;
					END
				END
			END
			ELSE
			BEGIN
				-- checking single proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
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
					CONTINUE;		
				END
				ELSE
				BEGIN
					BREAK;
				END
			END
		END
	
		--Unmark + ReCalculate
		BEGIN TRY
			--Unmark
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update 
				@TransIds			= @TransIds,
				@UserId				= @UserId,
				@IP					= @IP,
				@LogActionId		= 90511,
				@IsLockMatch		= 0

			-- ReCalculate
			EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
					@MatchId		 = @MatchId,	
					@TransIds		 = @TransIds,
					@UserId          = @UserId,
					@IP              = @IP,
					@IsLockMatch	 = 0
		END TRY
	
		BEGIN CATCH		
			SELECT ERROR_NUMBER() AS ErrCode
					,SUBSTRING(ERROR_MESSAGE(), 1, 300) AS ErrMsg

			RETURN			
		END CATCH
			
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
				, @isExistMG				= @isExistMG
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

	DROP TABLE #tmpTransId
END