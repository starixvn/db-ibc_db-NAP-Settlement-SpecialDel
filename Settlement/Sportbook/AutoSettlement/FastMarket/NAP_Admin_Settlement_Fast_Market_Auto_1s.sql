/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @MatchId INT
	,@Action				VARCHAR(20)
	,@Results				VARCHAR(MAX)
	,@EventCounters			VARCHAR(MAX)	= NULL

	,@IsAuto				BIT				= 0
	,@AdminId				INT				= 0
	,@Ip					VARCHAR(20)		= ''
	,@IsReSettledTickets	BIT				= 1

	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Auto/Manual settlement
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20170801@Bobby: Implement new capture balance method [Redmine:#80774]
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190404@Kathy: New keyId for Fast Market [Redmine:#106823]
		- 20190528@Kathy: Write log @IsReSettledTickets [Redmine:#113460]
		- 20190813@Helen: Remove vnteam in metadata
		- 20200727@Kathy: Prevent refund wrong match [Redmine:#136390]
		
	Param's Explanation:
		If @IsAuto = 0:
			- @Results = <r>
							<b Id="221">
								<r p="0" r="36" />
								<r p="1" r="1" />
								<r p="2" r="4" />
							</b>
						</r>
			- @EventCounters: '<r>
								<e Id="221CNT02">
									<r p="0" r="2" />
									<r p="1" r="1" />
								</e>
								<e Id="221CNT03">
									<r p="0" r="4" />
									<r p="1" r="2" />
								</e>
								...
							</r>'

		If @IsAuto = 1:
			@Results = <r>
							<b Id="221">
								<r p="0"/>
								<r p="1"/>
								<r p="2"/>
							</b>
						</r>
*/
BEGIN
	SET NOCOUNT ON
	 
	DECLARE		@Start 		DATETIME
				,@Stop 		DATETIME
				,@fth		INT
				,@fta 		INT
				,@hth 		INT
				,@hta 		INT
				,@ActionID	INT
				,@Remark	VARCHAR(MAX)
				,@LogData	NVARCHAR(300)						
				,@LogResult VARCHAR(MAX) = ''	
				,@strFMBettypes	VARCHAR(MAX)
				,@XmlData XML
				,@rowcount	INT
				,@avaiableProcess BIT
				,@sportType INT
				,@xmlEventCounter	XML
				,@LogEventCounter	VARCHAR(MAX) = ''

	
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
				
	SET @XmlData =  CONVERT(XML, @Results)
	SET @xmlEventCounter = CONVERT(XML,@EventCounters)

	SELECT	@start = CURRENT_TIMESTAMP
	SELECT	@ActionID = CASE 
							WHEN @Action = 'CAL' THEN 165 
							WHEN @Action = 'UNDO' THEN 166 
							WHEN @Action = 'REFUND' THEN 167
							ELSE 0 
						END  
	--Write Log Settle
	SELECT	 @fth = finalhomescore
			,@fta = finalawayscore
			,@hth = hthomescore
			,@hta = htawayscore
			,@sportType	= sportType
	FROM	dbo.match WITH (NOLOCK)
	WHERE	matchid = @matchid

	IF @Action LIKE 'CAL%'
	BEGIN
		EXEC DBPRO.bodb02.dbo.NAP_Set_SettlementStatusChecking
			@MatchId	= @matchid
			,@Action	= @action
			,@ErrCode	= @ErrCode	OUTPUT
			,@ErrMsg	= @ErrMsg	OUTPUT

		IF @ErrCode > 0
			RETURN
	END

	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchId AS matchid
		, 6 AS KeyID
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT
	
	--CHECK avaiable process
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
	
	CREATE TABLE #tblResultDetail (
		BetType			SMALLINT
		,ResourceId		VARCHAR(20)
		,Position		TINYINT
		,BetOption		TINYINT
	)

	CREATE TABLE #tblEventCounter (
		ResourceId	VARCHAR(20)
		,Position	TINYINT
		,Result		VARCHAR(8)
	)

	CREATE INDEX IX_ResultDetail_Bettype ON #tblResultDetail (BetType)
	
	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
		FROM @xmlData.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
	)
	INSERT INTO #tblResultDetail (
		BetType
		,ResourceId
		,Position
		,BetOption
	)
	SELECT	BetType
			,CAST(BetType * 100 + 1 AS VARCHAR(20)) AS ResourceId
			,Position
			,ISNULL(BetOption,0)
	FROM TmpData
	OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )

	;WITH TmpEventCounter AS (
		SELECT T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
				,X.C.value('@p','TINYINT') as Position
				,X.C.value('@r','TINYINT') as Result
		FROM @xmlEventCounter.nodes('/r/e') AS T(C)
				CROSS APPLY
					C.nodes('r') AS X(C)
	)
	INSERT INTO #tblEventCounter(ResourceId, Position, Result)
	SELECT	ResourceId
			,Position
			,Result
	FROM	TmpEventCounter
	OPTION ( OPTIMIZE FOR ( @xmlEventCounter = NULL ) )
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	
	INSERT INTO @BalanceWalletBefore (
		matchid
		, custid
		, balanceType
		, walletType
		, bonusId
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType		= @sportType
		, @Action 			= @Action
		, @Mode 			= 7 --@Mode fast market
		, @FMResults		= @Results
	
	SELECT @rowcount = COUNT(DISTINCT custid)
	FROM @BalanceWalletBefore
	
	BEGIN TRY
		-- update resultstatus
		EXEC DBPRO.bodb02.dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
			,@Results = @Results
			,@EventCounters = @EventCounters
			,@Action = @Action
			,@IsAuto = @IsAuto
			,@AdminId = @AdminId			
		
		IF @rowcount > 0
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'CAL-FM'
				,@mode = @Action
				,@XmlData = @Results
				,@IsReSettledTickets = @IsReSettledTickets
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		-------------------------------------------------------------
		---         CAPTURE value BALANCE after settlement        ---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, walletType
			, bonusId
			, balance
		)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
			@MatchId 			= @matchId
			, @sportType		= @sportType
			, @Action 			= @Action
			, @Mode 			= 7 --@Mode fast market
			, @FMResults		= @Results
		
		-- Compare Balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID
		
		SELECT	@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE()
		
		RETURN

	END CATCH

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------
	INSERT INTO @BalanceWalletAfter (
		matchid
		, custid
		, balanceType
		, walletType
		, bonusId
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 			= @matchId
		, @sportType 		= @sporttype
		, @Action 			= @Action
		, @Mode 			= 7 --@Mode fast market
		, @FMResults		= @Results
	
	-- Compare and update pending balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID

	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------

	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @logdata = 'NAP: Fast Market (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ '(' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.WriteLog_UserLog @UserID = @AdminId, @Doing = @logdata
	
	SET @LogResult = CONVERT(VARCHAR(MAX),(SELECT BetType '@Id'
		, STUFF((SELECT ',' + CAST(Position AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') AS 'Item/@Position'
		, CASE WHEN @Action = 'CAL' THEN STUFF((SELECT ',' + CAST(BetOption AS VARCHAR(3)) FROM #tblResultDetail WHERE BetType = r.BetType FOR XML PATH ('')),1,1,'') END AS 'Item/@Result'
	FROM #tblResultDetail r
	GROUP BY BetType
	FOR XML PATH('BetType'), ROOT ('BetTypes'), TYPE))

	INSERT INTO #tblEventCounter (ResourceId, Position, Result)
	SELECT	t.ResourceId
			,t.Position
			,0 as Result
	FROM (
		SELECT	re.ResourceId
				,p.Position
		FROM (
			SELECT	Position
			FROM	#tblEventCounter
			GROUP BY Position
		) p
			CROSS APPLY (
				SELECT ResourceId
				FROM (VALUES ('221CNT01'), ('221CNT02'), ('221CNT03'), ('221CNT04'), ('221CNT05'), ('221CNT06'), ('221CNT07'), ('221CNT08')) AS re (ResourceId)
			) re
	)t
		LEFT JOIN #tblEventCounter e
			ON	t.ResourceId = e.ResourceId
				AND t.Position = e.Position
	WHERE	e.ResourceId IS NULL

	SET @LogEventCounter = ISNULL(CONVERT(VARCHAR(MAX), (
													SELECT Position AS '@Position'
															,(SELECT	Result + '' 
																FROM	#tblEventCounter r
																WHERE	Position = t.Position 
																ORDER BY ResourceId DESC
																FOR XML PATH ('')) AS '@Result'
													FROM #tblEventCounter t
													GROUP BY Position
													ORDER BY Position
													FOR XML PATH('Item'), Root('EventCounters'), TYPE)
												) ,'')
		
	SELECT @Remark = 'NAP: IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
			+ ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + '<br/>' 
			+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + 'ms' 
			
	BEGIN TRY
		SELECT @Remark = @Remark + '|'  -- signal for web
						+ @LogResult + '|'
						+ @LogEventCounter 
	
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @userid = @AdminId
			, @matchid			= @MatchID
			, @actionid			= @ActionID
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @ip				= @ip
	END TRY

	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250) + '|' -- signal for web
							+ @LogResult + '|'
							+ @LogEventCounter 
							

		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @MatchID			= @matchid
			, @actionid			= @actionid
			, @finalhomescore	= @fth
			, @finalawayscore	= @fta
			, @hthomescore		= @hth
			, @htawayscore		= @hta
			, @GoalRecord		= ''
			, @betstatus		= ''
			, @Remark			= @Remark
			, @IP				= @ip
	END CATCH
	
	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
END
GO
