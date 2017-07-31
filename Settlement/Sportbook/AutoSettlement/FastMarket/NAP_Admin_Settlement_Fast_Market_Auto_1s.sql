/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,Dot_Admin" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Fast_Market_Auto_1s] @MatchId INT
	,@Action	VARCHAR(20)
	,@Results	VARCHAR(MAX)

	,@IsAuto	BIT				= 0
	,@AdminId	INT				= 0
	,@Ip		VARCHAR(20)		= ''

	,@ErrCode	INT				= 0		OUTPUT
	,@ErrMsg	VARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160427@Patrick
	Task: Fast market - Auto/Manual settlement
	DB: DBTXN.BODB02
	Original:
	
	Revisions:
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20170427@Bobby: 72789 - Implement bonus system into NAP Settlement
		
	Param's Explanation:
		If @IsAuto = 0:
			@ResultList = <r>
							<b Id="221">
								<r p="0" r="36" />
								<r p="1" r="1" />
								<r p="2" r="4" />
							</b>
						</r>
		If @IsAuto = 1:
			@ResultList = <r>
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

	
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
				
	SET @XmlData =  CONVERT(XML, @Results)

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
	FROM	dbo.match WITH (NOLOCK)
	WHERE	matchid = @matchid

	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT @matchId AS matchid
		, 1 AS KeyID
		
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
		, @Action 			= @Action
		, @Mode 			= 7 --@Mode fast market
		, @Results			= @Results
	
	SELECT @rowcount = COUNT(DISTINCT custid)
	FROM @BalanceWalletBefore
	
	BEGIN TRY
		-- update resultstatus
		EXEC DBPRO.bodb02.dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
			,@Results = @Results
			,@Action = @Action
			,@IsAuto = @IsAuto
			,@AdminId = @AdminId			
		
		IF @rowcount > 0
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
				,@action = 'CAL-FM'
				,@mode = @Action
				,@XmlData = @Results
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
			, @Action 			= @Action
			, @Mode 			= 7 --@Mode fast market
			, @Results			= @Results
		
		-- Compare Balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID
			, @IsCheckNegative		= 1
		
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
			, BonusID
			, WalletType
			, balance
	)
	SELECT matchid
		, custid
		, balanceType
		, BonusID
		, WalletType
		, balance 
	FROM dbo.f_NAP_Set_GetBalanceByWallet (
		@MatchId
		, @Action
		, 7 --@Mode fast market
	)
	
	-- Compare Balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
		, @IsCheckNegative		= 1
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
		
	SELECT @Remark = 'NAP: IsAuto:' + CAST(@IsAuto AS VARCHAR(1))
			+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + 'ms' 
			
	BEGIN TRY
		SELECT @Remark = @Remark + '|'  -- signal for web
						+ @LogResult
	
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
							+ @LogResult

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
	
	DROP TABLE #tblMatchProcess
	RETURN	
	
END
GO
