/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_MonitorProcess]
	@SessionId BIGINT
	,@MatchId INT
	,@HasError INT
	,@LogData XML = ''
	,@NeedWaiting BIT = 0 
	,@IsCentral	BIT = 0 
	,@BroadcastSessionId VARCHAR(50)	= NULL
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
	,@SSBStatus TINYINT = 0 OUTPUT
AS
/*
	Created by: 20210809@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		  - 20210809@Kathy: Settle by custid [Redmine:159486]
		  - 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		  - 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		  - 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		  - 20220613@Louisa: Auto Payout for matches TOTAL CORNER & TOTAL GOAL [Redmine:#171261]
		  - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		  - 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]
		  - 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		  - 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		  - 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		  - 20230731@Aries: Uncal Full Time does not update ticket status in DBOST [Redmine:#191963]
		  - 20230616@Aries: Support Direct Payout for Soccer Fantasy Matches [Redmine:#189493]
		  - 20230921@Kathy: change the way to write log for single ticket [Redmine:#193125]
		  - 20241023@Aries: Exclude LiveScore comparation between Traders and Soccerway for Instant Settlement [Redmine:#212500]

	Param's Explanation:  
	
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @oldgoalrecord VARCHAR(50)
			,@goalrecord VARCHAR(50)
			,@betstatus NVARCHAR(50)
			,@IsReSettledTickets BIT 
			,@ChildMatchIds VARCHAR(500)
			,@ActionID INT
			,@Action VARCHAR(20)
			,@fth SMALLINT
			,@fta SMALLINT
			,@hth SMALLINT
			,@hta SMALLINT
			,@AdminId INT
			,@IP VARCHAR(50)
			,@SourceId TINYINT
			,@RefResult VARCHAR(500)
			,@Remark VARCHAR(500)
			,@TicketCount INT
			,@SDTRecord TINYINT
			,@IsAuto BIT
			,@Starttime DATETIME
			
			,@FailedSettlementProcessingId INT
			,@RunningSettlementProcessingId INT

			,@sqlCommand NVARCHAR(MAX)

			,@SPName	SYSNAME
			,@matchcode NVARCHAR(50)
			,@leagueId INT
			,@KeyId INT
			,@DeterminedFTStatus TINYINT = 0
			,@BroadcastSessionIdInstant VARCHAR(50) = @BroadcastSessionId + '_instant'
			,@SiteDBGroupId					TINYINT

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@FailedSettlementProcessingId = 0
			,@RunningSettlementProcessingId = 0
			,@SPName = OBJECT_NAME(@@procid)

	WHILE (1=1)
	BEGIN
		SELECT	@FailedSettlementProcessingId = SUM(CASE WHEN statusId = 3 THEN 1 ELSE 0 END)
				,@RunningSettlementProcessingId = SUM(CASE WHEN StatusId <> 3 THEN 1 ELSE 0 END)
		FROM	dbo.SettlementProcessing
		WHERE	SessionId = @SessionId

		SELECT @FailedSettlementProcessingId = ISNULL(@FailedSettlementProcessingId,0)
				,@RunningSettlementProcessingId = ISNULL(@RunningSettlementProcessingId,0)
			
		IF @RunningSettlementProcessingId > 0
		BEGIN
			IF @NeedWaiting = 1 
				WAITFOR DELAY '00:00:00:010' -- wait for calculating ticket in table SettlementProcessing
			ELSE 
			BEGIN
				SET @SSBStatus = 1

				RETURN
			END
		END
		ELSE IF @FailedSettlementProcessingId > 0
		BEGIN
			SELECT	@SSBStatus = 3
					,@ErrCode = 1001066
					,@ErrMsg = 'Some tickets cannot be calculated due to fail SSB. Please contact Starix IT for further support.'
					,@HasError = 1
			BREAK
		END
		ELSE
		BEGIN
			SET @SSBStatus = 2

			BREAK
		END
	END

	DELETE
	FROM	dbo.SettlementBettypeResult WITH(ROWLOCK, UPDLOCK)
	WHERE	matchid = @MatchId
			AND SessionId = @SessionId

	IF @IsCentral = 0 AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
	BEGIN
		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
			@SystemName		= 'Settlement'
			,@FunctionName	= 'CalculateSoccer'
			,@TableName		= 'SiteDB_SettlementLock'
			,@Action		= 'D'
			,@MatchId		= @matchid
			,@SessionId		= @SessionId
	END

	SELECT @ActionID = T.C.value('@ActionID','INT')
	FROM	@LogData.nodes('/root/r') AS T(C)	

	EXEC dbo.NAP_Admin_Calculate_Main @mode = 'ReleaseMatch'
		,@IsSettingByProfile = 1
		,@SessionId = @SessionId
		,@MatchId = @MatchId
		,@ActionID = @ActionID
	
	IF @HasError = 0
	BEGIN
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT	@matchid AS matchid
				,1 AS KeyId

		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch		= 1
			, @IsReleased		= 1
			
		SELECT	@oldgoalrecord = T.C.value('@oldGoalRecord', 'VARCHAR(50)') 
				,@goalrecord = T.C.value('@goalrecord','VARCHAR(50)')
				,@betstatus = T.C.value('@betstatus','NVARCHAR(50)')
				,@IsReSettledTickets = T.C.value('@IsReSettledTickets','BIT')
				,@ChildMatchIds = T.C.value('@ChildMatchIds','VARCHAR(500)')
				,@fth = T.C.value('@fth','SMALLINT')
				,@fta = T.C.value('@fta','SMALLINT') 
				,@hth = T.C.value('@hth','SMALLINT')
				,@hta = T.C.value('@hta','SMALLINT')
				,@ActionID = T.C.value('@ActionID','INT')
				,@Action = T.C.value('@Action','VARCHAR(20)')
				,@IP = T.C.value('@IP','VARCHAR(50)')
				,@SourceId = T.C.value('@SourceId','TINYINT')
				,@RefResult = T.C.value('@RefResult','VARCHAR(500)')
				,@AdminId = T.C.value('@AdminId','INT')
				,@TicketCount = T.C.value('@TicketCount','INT')
				,@SDTRecord = T.C.value('@SDTRecord','TINYINT')
				,@IsAuto = T.C.value('@IsAuto','BIT')
				,@DeterminedFTStatus = ISNULL(T.C.value('@DeterminedFTStatus','TINYINT'),0)
				,@Starttime = T.C.value('@Starttime','DATETIME')
				,@ErrMsg = T.C.value('@ErrMsg','VARCHAR(300)')
				,@ErrCode = T.C.value('@ErrCode','INT')
		FROM	@LogData.nodes('/root/r') AS T(C)	

		-- write log
		BEGIN
			SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())	
			SELECT @Remark = '<distinct>'
									+ CASE 
										WHEN @Action LIKE '%INST%' THEN '' 
										WHEN @Action LIKE 'CAL%' THEN 
											CASE 
												WHEN @SourceId = 1 THEN '<r n="Auto Payout" v="SBO"/>'
												WHEN @SourceId = 101 THEN '<r n="Auto Payout" v="Direct ' + ISNULL(@RefResult,'') + '"/>' 
												ELSE ''
											END 
											+ CASE WHEN @DeterminedFTStatus = 2 THEN '<r n="SDT-FT" v="1"/>' ELSE '' END
											+ CASE    
												WHEN ISNULL(@oldgoalrecord,'')='' THEN ''
												ELSE '<r n="Old GoalRecord" v="' + @oldgoalrecord + '"/>' 
											END
											+ '<r n="Recalc" v="' + CAST(ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) + '"/>'
											+ CASE 
												WHEN ISNULL(@ChildMatchIds,'') = '' THEN '' 
												WHEN @ChildMatchIds = '0' THEN '<r n="RefChild" v="0"/>'
												ELSE '<r n="RefChild" v="(' + @ChildMatchIds + ')"/>'
											END
										WHEN @Action LIKE 'REFUND%' THEN
											CASE WHEN @IsAuto IS NOT NULL THEN '<r n="IsAutoRefund" v="' + CAST(@IsAuto AS CHAR(1)) + '"/>' ELSE '' END
											+ '<r n="SDTRecord" v="' + CAST(ISNULL(@SDTRecord,0) AS VARCHAR(3)) + '"/>' 										
										ELSE ''
										END
							+ '</distinct>'
							+ '<root>'
									+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
									+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @starttime, 120)  + '"/>'			
									+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'	
									+ CASE WHEN @TicketCount IS NOT NULL THEN '<r t="s" n="TC" v="' + CAST(@TicketCount AS VARCHAR(20))  + '"/>' ELSE '' END
							+ '</root>'			

			SELECT @betstatus = CASE WHEN @SDTRecord & 4 > 0 THEN 'Abandoned 1H' ELSE 'Refund' END
			WHERE	@Action = 'REFUND'

			EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
				@UserID                = @AdminId
				,@Matchid            = @matchid
				,@ActionID            = @ActionID
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@GoalRecord        = @goalrecord
				,@betstatus            = @betstatus
				,@Remark            = @Remark
				,@IP                = @IP
				,@BroadcastSessionId = @BroadcastSessionId
		END

		IF @DeterminedFTStatus = 1 -- determinable FT ticket
		BEGIN
			SET @sqlCommand = 'EXEC [dbo].[NAP_Admin_Settlement_1_Instant] @matchid = ' + CONVERT(NVARCHAR(50), @MatchId) 
									+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 
									+ ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @hth), 'NULL') 
									+ ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @hta), 'NULL') 
									+ ', @action = ''' + CONVERT(NVARCHAR(50), @Action) + ''''   
									+ ', @IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' 
									+ CASE WHEN @BroadcastSessionId IS NOT NULL 
												THEN ', @BroadcastSessionId = ''' + @BroadcastSessionIdInstant + ''''
												ELSE '' END
									+ ', @ErrCode = @ErrCode OUTPUT' 
									+ ', @ErrMsg = @ErrMsg OUTPUT'
			
			IF (@SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT_') -- UAT1 -->UAT9
			BEGIN
				BEGIN TRY
					EXEC sys.sp_executesql @sqlCommand
						,N'@ErrMsg VARCHAR(400) OUTPUT, @ErrCode int OUTPUT'
						,@ErrMsg		= @ErrMsg OUTPUT
						,@ErrCode		= @ErrCode OUTPUT
				END TRY

				BEGIN CATCH
					SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
							,@ErrCode = @@error

					RETURN
				END CATCH

				RETURN
			END
			SELECT	@matchcode = m.matchcode
					,@leagueId = m.leagueid
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.matchid = @MatchId

			INSERT INTO Single_Calculate_Queue (matchid, matchcode, IsCalculating, LeagueID, SportType, AdminId, IP, Action, sqlCommand)
			SELECT	@MatchId
					,@matchcode
					,99
					,@leagueid
					,1
					,@AdminId
					,@IP
					,'SDT-FT'
					,@sqlCommand

			SET @KeyId = SCOPE_IDENTITY()
		
			UPDATE Single_Calculate_Queue 
				SET sqlCommand = @sqlCommand + ', @KeyId = ' + CAST(@KeyId AS VARCHAR)
					,IsCalculating = 0
			WHERE	keyid = @KeyId
		
		END
	END
	ELSE
	BEGIN
		SELECT	@ErrMsg = CASE WHEN @ErrMsg = '' THEN T.C.value('@ErrMsg','VARCHAR(300)') ELSE @ErrMsg END
				,@ErrCode = CASE WHEN @ErrCode = 0 THEN @HasError ELSE @ErrCode END
		FROM	@LogData.nodes('/root/r') AS T(C)	
	END

	DROP TABLE #tblMatchProcess

END
