/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_MonitorParlayProcess]
	@SessionId BIGINT
	,@Session VARCHAR(50)
	,@MatchId INT
	,@HasError INT
	,@LogData XML = ''
	,@NeedWaiting BIT = 0 
	,@IsCentral	BIT = 0 
	,@LockedByRefno BIT = 0
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(300) = '' OUTPUT
	,@SSBStatus TINYINT = 0 OUTPUT
AS
/*
	Created by: @Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		 - 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
		 - 20240718@Kathy: Implement AiO for Baseball [Redmine:#206154]

	Param's Explanation:  
	
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @FailedParlaySettlementProcessingId INT
			,@RunningParlaySettlementProcessingId INT

	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	WHILE (1=1)
	BEGIN
		SELECT	@FailedParlaySettlementProcessingId = SUM(CASE WHEN statusId IN (3,13, 23) THEN 1 ELSE 0 END)
				,@RunningParlaySettlementProcessingId = SUM(CASE WHEN StatusId NOT IN (3,13, 23) THEN 1 ELSE 0 END)
		FROM	dbo.ParlaySettlementProcessing WITH(ROWLOCK)
		WHERE	SessionId = @SessionId

		SELECT @FailedParlaySettlementProcessingId = ISNULL(@FailedParlaySettlementProcessingId,0)
				,@RunningParlaySettlementProcessingId = ISNULL(@RunningParlaySettlementProcessingId,0)
			
		IF @RunningParlaySettlementProcessingId > 0
		BEGIN
			IF @NeedWaiting = 1 
				WAITFOR DELAY '00:00:00:010' -- wait for calculating ticket in table ParlaySettlementProcessing
			ELSE 
			BEGIN
				SET @SSBStatus = 1

				RETURN
			END
		END
		ELSE IF @FailedParlaySettlementProcessingId > 0
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
	
	IF @IsCentral = 0 AND OBJECT_ID('SiteDB_NAP_SettlementService_CalculationLogIns','P') IS NOT NULL 
	BEGIN
		EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogIns
			@SystemName		= 'Settlement'
			,@FunctionName	= 'CalculateParlay'
			,@TableName		= 'SiteDB_ParlaySettlementLock'
			,@Action		= 'D'
			,@MatchId		= @matchid
			,@SessionId		= @SessionId
			,@TicketType 	= 'p'
	END
	
	EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchid
		,@mode = 'ParlayReleaseMatch'
		,@SessionId = @SessionId
	
	IF @LockedByRefno = 1
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP (2000) pl
			FROM dbo.ParlayLocking pl
			WHERE pl.session = @session

			IF @@ROWCOUNT < 2000
				BREAK
		END	
	END

	EXEC dbo.NAP_Admin_CheckingProcess
		@IsExistParlay = 1
		,@IsReleased = 1


	IF @HasError = 0
	BEGIN
		DECLARE @sporttype SMALLINT
				,@Action VARCHAR(20)
				,@IsAuto BIT
				,@StartTime DATETIME
				,@ResourceRefund VARCHAR(MAX)
				,@SelectedResources VARCHAR(MAX)
				,@fth INT
				,@fta INT
				,@DeterminedType INT		= 0
				,@ParentMatchId		INT
				,@RemarkSDT			VARCHAR(500) = ''
				,@Remark VARCHAR(MAX)
				,@IsAutoRefund BIT = 0
				,@SiteDBGroupId SMALLINT
				,@ResultRemarkLog VARCHAR(MAX)
				,@IsReSettledTickets	BIT			= 1
				,@totalSubParlay INT = 0
				,@matchLog INT
				,@creator INT
				,@ActionID INT
				,@hth					INT			= 0
				,@hta					INT			= 0
				,@IP	 				VARCHAR(50)		= ''
				,@BroadcastSessionId	VARCHAR(50)	= NULL

		SELECT	@sporttype = T.C.value('@sporttype', 'SMALLINT') 
				,@IsAuto = T.C.value('@IsAuto','BIT')
				,@IsAutoRefund = T.C.value('@IsAutoRefund','BIT')
				,@Starttime = T.C.value('@StartTime','DATETIME')
				,@ResourceRefund = T.C.value('@ResourceRefund','VARCHAR(MAX)')
				,@SelectedResources = T.C.value('@SelectedResources','VARCHAR(MAX)')
				,@fth = T.C.value('@fth','INT')
				,@fta = T.C.value('@fta','INT')
				,@DeterminedType = T.C.value('@DeterminedType','INT')
				,@ParentMatchId = T.C.value('@ParentMatchId','INT')
				,@RemarkSDT = T.C.value('@RemarkSDT','VARCHAR(MAX)')
				,@ResultRemarkLog = T.C.value('@ResultRemarkLog','VARCHAR(MAX)')
				,@totalSubParlay = T.C.value('@totalSubParlay','INT')
				,@matchLog = T.C.value('@matchLog','INT')
				,@creator = T.C.value('@creator','INT')
				,@ActionId = T.C.value('@ActionID','INT')
				,@hth = T.C.value('@hth','INT')
				,@hta = T.C.value('@hta','INT')
				,@IP = T.C.value('@IP','VARCHAR(50)')
				,@BroadcastSessionId = T.C.value('@BroadcastSessionId','VARCHAR(50)')

				,@ErrMsg = T.C.value('@ErrMsg','VARCHAR(300)')
				,@ErrCode = T.C.value('@ErrCode','INT')
		FROM	@LogData.nodes('/root/r') AS T(C)
		
		IF @IsAuto = 1 AND @Action = 'REFUND' AND @sporttype <> 1
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultUpd
				@MatchId = @matchid
				,@StatusId = 2
				,@ResourceIds  = @ResourceRefund
		END

		--Auto refund Badminton after calculate parlay by Auto Service
		IF @IsAutoRefund = 1
		BEGIN
			EXEC dbo.NAP_Set_GetRefundResult
					@MatchId		= @MatchID
					,@Sporttype		= @sportType
					,@CalculateResources= @SelectedResources
					,@ResourceRefund = @ResourceRefund OUTPUT

			IF ISNULL(@ResourceRefund, '')  <> ''
			BEGIN
				EXEC DBPRO.bodb02.dbo.NAP_Set_AutoRefundOS_ResultIns
					@MatchId		 = @MatchID
					,@ResourceIds	 = @ResourceRefund
			END
		END 

		-- write log
		BEGIN
			SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())
			SELECT @Remark =
				'<distinct>'
								+ CASE WHEN @ParentMatchId IS NOT NULL THEN '<r n="Child" v="' + CAST(@matchid AS VARCHAR) + '"/>' ELSE '' END
								+ CASE 
									WHEN @sporttype <> 1 AND @DeterminedType = 0 
										THEN CASE 
												WHEN @Action LIKE 'CAL%' THEN '<r n="Result" v="' + ISNULL(@ResultRemarkLog,'') + '"/>' 
												ELSE '<r n="Selected" v="' +  ISNULL(@ResultRemarkLog,'') + '"/>' 
												END
									WHEN @sportType <> 1 AND @DeterminedType > 0 THEN '<r n="Selected" v="' +  ISNULL(@RemarkSDT,'') + '"/>'
									ELSE ''
								END
								+ CASE 
									WHEN @DeterminedType = 2 THEN '<r n="SDT-FT" v="1"/>' 
									WHEN @DeterminedType = 1 THEN '<r n="Instant HT" v="1"/>'
									WHEN @DeterminedType = 4 THEN '<r n="Instant FT" v="1"/>'
									ELSE '' END
								+ CASE WHEN @Action LIKE 'CAL%' THEN '<r n="Recalc" v="' + CAST (ISNULL(@IsReSettledTickets,0) AS VARCHAR(1)) + '"/>' ELSE '' END
							+ '</distinct>'
							+ '<root>'
								+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
								+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @StartTime, 120)  + '"/>'			
								+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'	
								+ '<r t="s" n="TC" v="' + CAST(ISNULL(@totalSubParlay, 0) AS VARCHAR(20))  + '"/>'							
							+ '</root>'			
					,@BroadcastSessionId = CASE WHEN @sporttype = 50 AND @matchLog IS NOT NULL THEN @BroadcastSessionId + 'child' ELSE @BroadcastSessionId END -- for child match

			EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle @UserID = @creator
				,@Matchid = @matchLog
				,@ActionID = @ActionID	
				,@finalhomescore    = @fth
				,@finalawayscore    = @fta
				,@hthomescore        = @hth
				,@htawayscore        = @hta
				,@Remark = @Remark
				,@IP = @IP
				,@BroadcastSessionId = @BroadcastSessionId
		END
	END
	ELSE
	BEGIN
		SELECT	@ErrMsg = CASE WHEN @ErrMsg = '' THEN T.C.value('@ErrMsg','VARCHAR(300)') ELSE @ErrMsg END
				,@ErrCode = CASE WHEN @ErrCode = 0 THEN @HasError ELSE @ErrCode END
		FROM	@LogData.nodes('/root/r') AS T(C)	
	END

END
