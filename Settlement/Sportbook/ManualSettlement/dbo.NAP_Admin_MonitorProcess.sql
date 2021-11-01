/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_MonitorProcess]
	@SessionId BIGINT
	,@MatchId INT
	,@HasError INT
	,@LogData XML = ''
	,@NeedWaiting BIT = 0 
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
			,@Remark VARCHAR(500)
			,@TicketCount INT
			,@Starttime DATETIME
			,@Endtime DATETIME

			,@FailedSettlementProcessingId INT
			,@RunningSettlementProcessingId INT

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@FailedSettlementProcessingId = 0
			,@RunningSettlementProcessingId = 0

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
				WAITFOR DELAY '00:00:00:010'
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

	-- cal 914	
	BEGIN TRY
		EXEC dbo.NAP_Admin_Calculate_914 -- CashOut Winlost Sharing
			@MatchId = @matchid
			,@Action = 'CAL'
			,@Sporttype = 1
	END TRY
	BEGIN CATCH
		SELECT	@SSBStatus = 3
				,@ErrCode = 1001017
				,@ErrMsg = ERROR_MESSAGE()  
				,@HasError = 1
	END CATCH

	EXEC dbo.NAP_Admin_Calculate_Main @mode = 'ReleaseMatch'
		,@IsSettingByProfile = 1
		,@SessionId = @SessionId
		,@MatchId = @MatchId
	
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
				,@AdminId = T.C.value('@AdminId','INT')
				,@TicketCount = T.C.value('@TicketCount','INT')
				,@Starttime = T.C.value('@Starttime','DATETIME')
				,@ErrCode = @HasError
		FROM	@LogData.nodes('/root/r') AS T(C)	

		SET @Endtime = GETDATE()
		SELECT @Remark = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10)) 
                                                        + ' score:' + CAST(ISNULL(@fth, 0) AS NVARCHAR(10)) 
                                                        + '-' + CAST(ISNULL(@fta, 0) AS NVARCHAR(10)) 
                                                        + ' HT:' + CAST(ISNULL(@hth,0) AS NVARCHAR(10)) 
                                                        + '-' + CAST(ISNULL(@hta,0) AS NVARCHAR(10)) 
                                                        + ' GoalRecord:' + ISNULL(@goalrecord, '') 
                                                        + '(Old:' + @oldgoalrecord + ') Remark(' + @betstatus + ')' 
														+' (' + CAST(DATEDIFF(millisecond, @Starttime, @Endtime) AS NVARCHAR(50)) + ' ms)'

		EXEC dbo.WriteLog_UserLog 
			@UserID = @AdminId
			,@Doing = @Remark

		SELECT @Remark ='NAP: ' 
						+ CASE 
							WHEN @SourceId = 1 THEN 'Auto Payout: SBO' + '<br/> '
							WHEN @SourceId = 101 THEN 'Auto Payout: Direct' + '<br/> '
							ELSE ''
						END
						+ CASE    WHEN ISNULL(@oldgoalrecord,'')='' THEN ''
                                    ELSE 'Old GoalRecord:' + @oldgoalrecord + '<br/> '
                                    END
						+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @Starttime, @Endtime) AS NVARCHAR(50)) + ' ms;' 
                        + ' TC:' + CAST(ISNULL(@TicketCount, 0) AS VARCHAR(20)) + ';'
						+ ' Recalc: ' + CAST (@IsReSettledTickets AS VARCHAR(1)) + ';'
                       + CASE WHEN ISNULL(@ChildMatchIds,'') = '' THEN ''
								WHEN @ChildMatchIds = '0' THEN ' RefChild:0' 
								ELSE ' RefChild:(' + @ChildMatchIds +')' 
								END
		
		BEGIN TRY
			EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
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
		END TRY
		BEGIN CATCH
			EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle 
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
		END CATCH
	END
	ELSE
	BEGIN
		SELECT	@ErrMsg = CASE WHEN @ErrMsg = '' THEN T.C.value('@ErrMsg','VARCHAR(300)') ELSE @ErrMsg END
				,@ErrCode = CASE WHEN @ErrCode = 0 THEN @HasError ELSE @ErrCode END
		FROM	@LogData.nodes('/root/r') AS T(C)	
	END

	DROP TABLE #tblMatchProcess

END
