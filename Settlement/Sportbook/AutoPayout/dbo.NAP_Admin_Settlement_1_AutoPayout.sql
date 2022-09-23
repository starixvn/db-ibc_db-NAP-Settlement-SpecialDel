/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_1_AutoPayout]  
	@creator 			INT
	, @matchid			INT
	, @fth				SMALLINT		= NULL
	, @fta				SMALLINT		= NULL
	, @hth				SMALLINT
	, @hta				SMALLINT
	, @action			VARCHAR(10)		= 'CAL'
	, @IP				VARCHAR(50)		= ''
	, @IsReSettledTickets	BIT			= 1
	, @GoalRecord		VARCHAR(50)		= ''
	, @BetStatus		NVARCHAR(50)	= ''
	, @ResourceResult	VARCHAR(MAX)	= NULL
	, @SourceId			TINYINT			= 5 -- default SoccerWay
	, @RefResult		VARCHAR(500)	= NULL
	, @BroadcastSessionId VARCHAR(50)	= NULL
	, @KeyId			INT				= 0
	, @ErrCode			INT				= 0		OUTPUT
	, @ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20160303@Patrick
	Task: main SP for soccer auto settlement
	DB: DBTXN/BODB02
	Original: Admin_Settlement_1
			- NAP_Admin_Settlement_1
	
	Revisions:
		- 20160713@Patrick: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20170313@Kathy: Remove @betstatus, @goalrecord [Redmine:#73218]
		- 20170316@Bobby: Integrate CashOut bettypes [Redmine:#73404]
		- 20170424@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190620@Kathy: Remove corner betradar bettypes [Redmine:#109584]
		- 20190919@Sol: Incorporate PHAIO 4b - 27 Corners Bet Types - Corect @HTDone value [Redmine:#115232]
		- 20200306@Sol:	Don't change Event Status to Completed When Calculate HT - [Redmine:#129884]
		- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20201216@Louisa: Auto Refund ET & PEN match [Redmine:#145597]
		- 20210201@Louisa: Add NOLOCK [Redmine:#149787]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20210326@Louisa: Negative balance [Redmine:#152345]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393] 
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220613@Louisa: Auto Payout for matches TOTAL CORNER & TOTAL GOAL [Redmine:#171261]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @start						DATETIME
		, @stop							DATETIME
		, @LogData						NVARCHAR(300)
		, @eventstatus					NVARCHAR(50)
		, @TicketCount					INT	
		, @Remark						VARCHAR(500)
		, @ActionID						INT
		, @TotalAccount					INT
		, @TotalAccount_BalanceUpdate	INT
		, @HTDone						BIT
		, @FTDone						BIT
		, @strHTBettypes				VARCHAR(MAX)
		, @strFTBettypes				VARCHAR(MAX)
		, @avaiableProcess				BIT
		, @sporttype                    SMALLINT
		, @matchcode					NVARCHAR(50)
		, @SessionId					BIGINT
		, @RunBySSBProcess				BIT
		, @LogDataSoccer				XML
		, @CommandMonitor				NVARCHAR(MAX)
		, @goalrecord_old               VARCHAR(50)
		, @SSBStatus					TINYINT
		, @TypeId						TINYINT
		, @AutoSetting					TINYINT
		, @IsCentral					BIT
		
	--START Balance tables	
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		, @BalanceWalletAfter			TVP_BalanceWalletChange
	--END Balance tables

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
		
	SELECT @start					= CURRENT_TIMESTAMP
		, @TicketCount				= 0
		, @ActionID					= CASE  @Action
										WHEN 'CAL-FT'	THEN 158
										WHEN 'CAL-HT'	THEN 157
										WHEN 'CAL'		THEN 100
										END
		,@RunBySSBProcess			= 0
		,@TypeId = CASE @Action 
					WHEN 'CAL-HT' THEN 1
					WHEN 'CAL-FT' THEN 2
					WHEN 'CAL'		THEN 2
					ELSE -1	END --not supported

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
	@MatchId	= @Matchid
	,@ErrCode	= @ErrCode OUTPUT
	,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	@ErrCode = @ErrCode
				,@ErrMsg = 'Cannot execute auto-settle process due to match is on hold.'
	    
	    RETURN
	END
	
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
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT @eventstatus = m.eventstatus
		, @matchcode = m.matchcode
		, @sporttype = m.sporttype
		, @goalrecord_old = m.GoalRecord
		, @AutoSetting = ISNULL(m.AutoSetting,l.AutoSetting)
	FROM DBPRO.BODB02.dbo.Match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.matchid = @matchid
 
	IF @sporttype = 1
	BEGIN
		INSERT INTO dbo.Settlement_SettledSession (MatchId)
		SELECT @matchid
		SET @SessionId = SCOPE_IDENTITY()

		SET @RunBySSBProcess = 1

		BEGIN TRY
			EXEC dbo.NAP_Admin_Settlement_3_profile
				@matchId	= @matchid
				,@hth = @hth
				,@hta = @hta
				,@fth = @fth 
				,@fta = @fta
				,@goalrecord = @goalrecord
				,@action	= @action
				,@ActionID	= @ActionID
				,@IsReSettledTickets = @IsReSettledTickets
				,@ResourceResult = @ResourceResult
				,@SessionId = @SessionId
				,@BroadcastSessionId = @BroadcastSessionId
				,@TicketCount = @TicketCount OUTPUT
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 1001017
					,@ErrMsg = ERROR_MESSAGE()
		END CATCH
			
		IF @IsCentral = 1
			EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd @MatchId = @matchid, @TypeId = @TypeId, @StatusId = 2, @IsIncludedUpdateMatch = 1 --Completed
																		, @SourceId = @SourceId

		IF @Action = 'CAL-FT' AND ISNULL(@fta,0) <> ISNULL(@fth,0)
		BEGIN
			DECLARE @LeagueGroupID	SMALLINT
					, @ChildMatchIds	VARCHAR(500)

			SELECT	@LeagueGroupID = ISNULL(l.LeagueGroupID,0)
			FROM dbo.Match m WITH(NOLOCK)
				INNER JOIN dbo.League l WITH(NOLOCK)
					ON m.leagueid = l.leagueid
			WHERE m.MatchId = @matchid

			IF (@sporttype = 1 AND @LeagueGroupID IN (42,74,108) )
			BEGIN
				SELECT @ChildMatchIds = STUFF( COALESCE(@ChildMatchIds + ',' + CAST(m.matchid AS VARCHAR), CAST(m.matchid AS VARCHAR)) , 1, 0, '' ) 
				FROM dbo.match m WITH(NOLOCK)
				WHERE ParentID = @matchid
					AND m.ChildMatchType IN ( 201,202,203 )
					AND ISNULL(m.IsDeleted,0) = 0

				SELECT @ChildMatchIds = ISNULL( @ChildMatchIds, '0')
			END
		END
 
		SELECT @LogDataSoccer = (					
					SELECT	@goalrecord_old AS '@oldGoalRecord'
							,@goalrecord AS '@goalrecord'
							,@betstatus AS '@betstatus'
							,@IsReSettledTickets AS '@IsReSettledTickets'
							,@ChildMatchIds AS '@ChildMatchIds'
							,@ActionID AS '@ActionID'
							,@action AS '@Action'
							,@fth AS '@fth'
							,@fta AS '@fta'
							,@hth AS '@hth'
							,@hta AS '@hta'
							,@creator AS '@AdminId'
							,@IP AS '@IP'
							,@TicketCount AS '@TicketCount'
							,@SourceId AS '@SourceId'
							,@RefResult AS '@RefResult'
							,CASE WHEN @AutoSetting & 2 > 0 AND @action = 'CAL-HT' THEN 1 ELSE NULL END AS '@DeterminedFTStatus'
							,@start AS '@Starttime'
							,@ErrMsg AS '@ErrMsg'
					FOR XML PATH('r'), ROOT('root'), TYPE)
		
		SET @CommandMonitor = 'EXEC dbo.NAP_Admin_MonitorProcess @SessionId = ' + CAST(@SessionId AS VARCHAR(50))
							+ ', @MatchId = ' + CAST(@MatchId AS VARCHAR)		
							+ ', @HasError = ' + CAST(@ErrCode AS VARCHAR)
							+ ', @LogData = ' + '''' + CAST(@LogDataSoccer AS VARCHAR(MAX)) + ''''
							+ ', @IsCentral = ' + CAST(@IsCentral AS VARCHAR)
							+ CASE WHEN @BroadcastSessionId IS NOT NULL 
												THEN ', @BroadcastSessionId = ''' + @BroadcastSessionId + ''''
												ELSE '' END
							+ ', @ErrCode = @ErrCode OUTPUT' 
                            + ', @ErrMsg = @ErrMsg OUTPUT'
							+ ', @SSBStatus = @SSBStatus OUTPUT'

		UPDATE dbo.Single_Calculate_Queue 
			SET SSBCommand = @CommandMonitor
		WHERE	keyid = @KeyId

		IF @@ROWCOUNT = 0
		BEGIN
			SET @CommandMonitor = @CommandMonitor + ', @NeedWaiting = 1' 

			EXEC sys.sp_executesql @CommandMonitor
				, N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT, @SSBStatus TINYINT OUTPUT'
				, @ErrMsg	= @ErrMsg	OUTPUT
				, @ErrCode	= @ErrCode	OUTPUT
				, @SSBStatus = @SSBStatus OUTPUT
		END

		RETURN
	END

	SELECT @strHTBettypes = COALESCE(@strHTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM dbo.f_Set_GetGroupBettypes() f 
	WHERE f.GroupId IN (1, 3) -- inclued FGLG bettype -- #106901
 
	SELECT @strFTBettypes = COALESCE(@strFTBettypes + ',' + CAST(bettype AS NVARCHAR), CAST(bettype AS NVARCHAR))
	FROM dbo.f_Set_GetGroupBettypes() f 
	WHERE f.GroupId IN (2, 4) -- inclued FGLG bettype -- #106901
	
	IF @Action IN ('CAL-HT', 'CAL')
	BEGIN
		SELECT @TicketCount = COUNT(1)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.matchid = @matchid
			AND 1 = CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strHTBettypes + ',') > 0 THEN 1
						ELSE 0	END
	END
	IF @Action IN ('CAL-FT', 'CAL')
	BEGIN
		SELECT @TicketCount = @TicketCount + COUNT(1)
		FROM dbo.bettrans b WITH(NOLOCK)
		WHERE b.matchid = @matchid
			AND 1 = CASE WHEN CHARINDEX(',' + CAST(b.bettype AS VARCHAR) + ',', ',' + @strFTBettypes + ',') > 0 THEN 1
						ELSE 0	END
	END
	-------------------------------------------------------------
	---        CAPTURE value BALANCE before settlement        ---
	---------------------------VVVV------------------------------
	
	INSERT INTO @BalanceWalletBefore (
		matchid
		, custid
		, balanceType
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 		= @matchId
		, @sportType 	= @sporttype
		, @Action		= @Action
		, @Mode 		= 2
		, @IsCentral	= @IsCentral
		
	SELECT @TotalAccount = COUNT(DISTINCT custid)
	FROM @BalanceWalletBefore
 
	BEGIN TRY
		EXEC dbo.NAP_Admin_Settlement_3
			@matchid            = @matchid
			,@mode                = @action    
			,@IsReSettledTickets = @IsReSettledTickets
			,@creator = @creator

		IF @IsCentral = 1
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Set_AutoPayoutResultUpd @MatchId = @matchid, @TypeId = @TypeId, @StatusId = 2, @IsIncludedUpdateMatch = 1 --Completed
																		, @SourceId = @SourceId
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		INSERT INTO @BalanceWalletAfter (
			matchid
			, custid
			, balanceType
			, WalletType
			, BonusID
			, balance
		)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
			@MatchId 		= @matchId
			, @sportType 	= @sporttype
			, @Action		= @Action
			, @Mode 		= 2
			, @IsCentral	= @IsCentral
		
		-- Compare Balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @BalanceWalletBefore
			, @BalanceWalletAfter	= @BalanceWalletAfter
			, @ActionId				= @ActionID
 
		--SET total affected accounts
		SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT b.custid)
		FROM @BalanceWalletBefore b
			INNER JOIN @BalanceWalletAfter a 
			ON b.custid = a.custid
		WHERE b.balance <> a.balance

		SELECT @ErrCode = 1001017
			, @ErrMsg = ERROR_MESSAGE()
		
	END CATCH
	
	IF @ErrCode <> 0
		RETURN

	-------------------------------------------------------------
	---         CAPTURE value BALANCE after settlement        ---
	---------------------------VVVV------------------------------

	INSERT INTO @BalanceWalletAfter (
		matchid
		, custid
		, balanceType
		, WalletType
		, BonusID
		, balance
	)
	EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
		@MatchId 		= @matchId
		, @sportType 	= @sporttype
		, @Action		= @Action
		, @Mode 		= 2
		, @IsCentral	= @IsCentral
 
	-------------------------------------------------------------
	---                   compare BALANCE                     ---
	---------------------------VVVV------------------------------
 
	---INSERT data into pending balance table   
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BalanceWalletBefore
		, @BalanceWalletAfter	= @BalanceWalletAfter
		, @ActionId				= @ActionID
	
	--SET total affected accounts
	SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT b.custid)
	FROM @BalanceWalletBefore b
		INNER JOIN @BalanceWalletAfter a 
		ON b.custid = a.custid
	WHERE b.balance <> a.balance
	
	-------------------------------------------------------------
	---                      WRITE LOG                        ---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP

	SELECT @LogData = 'NAP: Auto Payout Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
		+ ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
		+ ' HT:' + CAST(@hth AS NVARCHAR(10)) + '-' + CAST(@hta AS NVARCHAR(10)) 
		+ ' GoalRecord:' + ISNULL(@goalrecord, '')
		+ ' Remark(' + @betstatus + ')' 
		+ ' (' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'

	EXEC dbo.Logfile_V2 
		@UserID = @creator
		,@Doing = @LogData
		,@extend = @MatchId
		
	IF @IsCentral = 1
	BEGIN
		SELECT @Remark ='NAP: ' 
								+ CASE 
										WHEN @SourceId = 1 THEN 'Auto Payout: SBO' + '<br/> '
										WHEN @SourceId = 101 THEN 'Auto Payout: Direct ' + ISNULL(@RefResult,'') + '<br/> ' 
										ELSE ''
									END
								+ CASE WHEN @sporttype = 1 THEN  'GoalRecord:' + ISNULL(@goalrecord,'') + '<br/> ' ELSE '' END
								+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms;' 
								+ ' TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
								+ ' Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) 
															+ '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
								+ CASE WHEN ISNULL(@ChildMatchIds,'') = '' THEN ''
										WHEN @ChildMatchIds = '0' THEN ' RefChild:0' 
										ELSE ' RefChild:(' + @ChildMatchIds +')' 
										END
	
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				, @Matchid			= @matchid
				, @ActionID			= @ActionID
				, @finalhomescore	= @fth
				, @finalawayscore	= @fta
				, @hthomescore		= @hth
				, @htawayscore		= @hta
				, @GoalRecord		= @goalrecord
				, @betstatus		= @betstatus
				, @Remark			= @Remark
				, @IP				= @IP
		END TRY
 
		BEGIN CATCH
			SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)
 
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @creator
				, @Matchid			= @matchid
				, @ActionID			= @ActionID
				, @finalhomescore	= @fth
				, @finalawayscore	= @fta
				, @hthomescore		= @hth
				, @htawayscore		= @hta
				, @GoalRecord		= @goalrecord
				, @betstatus		= @betstatus
				, @Remark			= @Remark
				, @IP				= @IP
		END CATCH
	END

	------ releasing Settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
	@isExistMatch		= 1
	, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
	RETURN	
END
