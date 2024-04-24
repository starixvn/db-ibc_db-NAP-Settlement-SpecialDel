/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_PendingLogIns]
	@SiteDBGroupId SMALLINT
	,@SiteDBCalculationLog TVP_SiteDB_CalculationLog READONLY
AS
/*
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221101@Louisa: INsert Pending Log to central [Redmine#178694]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]

	Param's Explanation:  
		
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @TransInfo			XML
			,@TransInfoJson		VARBINARY(MAX)
			,@Action			VARCHAR(1)
			,@TableName			VARCHAR(128)
			,@MatchId			INT
			,@SettlementAction	VARCHAR(20)
			,@TicketType		VARCHAR(1)
			,@SessionId			BIGINT

			,@xmlCommand		VARCHAR(MAX)
			,@MessageType		VARCHAR(200)
			,@MessageTypeParlay	VARCHAR(200)

			,@IsExistsParallel	BIT
			,@MaxLogId			BIGINT
			,@LogId				BIGINT
			,@CurrentLogId		BIGINT
			
			,@ErrCode INT
			,@ErrMsg VARCHAR(300)
	
			--,@SiteDB_RunExecDataBySSB BIT
			,@SiteDB_ExecDataQueueSize SMALLINT
			,@SiteDB_ExecParlayDataQueueSize SMALLINT
			,@MessageTypePattern VARCHAR(200)
	
	DECLARE @SiteDBPendingLog TVP_SiteDB_CalculationLog
	INSERT INTO @SiteDBPendingLog 
	(	LogId
		,TransInfo
		,TransInfoJson
		,TableName
		,MatchId
		,Action
		,SettlementAction
		,TicketType
		,SessionId
		,IsParallel
	)
	SELECT l.LogId
		,l.TransInfo
		,l.TransInfoJson
		,l.TableName
		,l.MatchId
		,l.Action
		,l.SettlementAction
		,l.TicketType
		,l.SessionId
		,l.IsParallel
	FROM @SiteDBCalculationLog l
		LEFT JOIN dbo.SiteDB_SettlementService_CalculationLog_History h WITH(NOLOCK)
			ON l.LogId = h.LogId
				AND h.SiteDBGroupId = @SiteDBGroupId
	WHERE h.LogId IS NULL

	IF @@ROWCOUNT = 0
	RETURN

	EXEC dbo.NAP_Set_GlobalSettingSel	
			@LockName = 'SiteDB_SettlementSSB'
			--,@SiteDB_RunExecDataBySSB =  @SiteDB_RunExecDataBySSB OUTPUT
			,@SiteDB_ExecDataQueueSize = @SiteDB_ExecDataQueueSize OUTPUT
			,@SiteDB_ExecParlayDataQueueSize = @SiteDB_ExecParlayDataQueueSize OUTPUT

	SELECT	@MaxLogId = MAX(CASE WHEN ISNULL(IsParallel,0) = 1 THEN 0 ELSE LogId END)
			,@IsExistsParallel = MAX(CASE WHEN ISNULL(IsParallel,0) = 1 THEN 1 ELSE 0 END)
	FROM	@SiteDBPendingLog
	
	IF @IsExistsParallel = 1 -- run commands in parallel
	BEGIN
		SET @MessageTypePattern = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type_0'

		INSERT INTO dbo.SiteDB_SettlementProcessing(SiteDBGroupId, SessionId, MessageType, TransInfo, SettlementAction, TicketType)
		SELECT	@SiteDBGroupId
				,s.SessionId
				,@MessageTypePattern + CAST(s.LogId%@SiteDB_ExecDataQueueSize + CASE WHEN s.LogId%@SiteDB_ExecDataQueueSize = 0 THEN @SiteDB_ExecDataQueueSize ELSE 0 END AS VARCHAR)
				,s.TransInfoJson
				,s.SettlementAction
				,s.TicketType
		FROM	@SiteDBPendingLog s
		WHERE	s.IsParallel = 1
				AND s.TicketType = 's'
		ORDER BY s.LogId

		INSERT INTO  dbo.SiteDB_SettlementService_CalculationLog_History (LogId, SiteDBGroupId, LogDate)
		SELECT s.LogId, @SiteDBGroupId, SYSDATETIME()
		FROM	@SiteDBPendingLog s
		WHERE	s.IsParallel = 1
				AND s.TicketType = 's'

		-- parlay
		BEGIN -- TransInfoBetParlayResult, TransInfoBettrans, 
			INSERT INTO dbo.SiteDB_ParlaySettlementProcessing(SiteDBGroupId, SessionId, MatchId, TableName, MessageType, TransInfoBettransM, SettlementAction, TicketType, SiteDB_ParlaySettlementProcessingId)
			SELECT	@SiteDBGroupId
					,s.SessionId
					,s.MatchId
					,s.TableName
					,'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_parlaybet_settle_msg_type_0' + CAST(s.LogId%@SiteDB_ExecParlayDataQueueSize + CASE WHEN s.LogId%@SiteDB_ExecParlayDataQueueSize = 0 THEN @SiteDB_ExecParlayDataQueueSize ELSE 0 END AS VARCHAR)
					,s.TransInfoJson AS TransInfoBettransM
					,s.SettlementAction
					,s.TicketType
					,(SELECT TOP 1 T.C.value('./@pid', 'bigint') FROM TransInfo.nodes('/parlay/r') AS T(C)) AS SiteDB_ParlaySettlementProcessingId
			FROM	@SiteDBPendingLog s
			WHERE	s.IsParallel = 1
					AND s.TicketType = 'p'
					AND TableName IN ('bettransm', 'bettransm/BetParlayDetail')
			ORDER BY s.LogId

			IF @@ROWCOUNT <> 0
				INSERT INTO  dbo.SiteDB_SettlementService_CalculationLog_History (LogId, SiteDBGroupId, LogDate)
				SELECT s.LogId, @SiteDBGroupId, SYSDATETIME()
				FROM	@SiteDBPendingLog s
				WHERE	s.IsParallel = 1
						AND s.TicketType = 'p'	
						AND TableName IN ('bettransm', 'bettransm/BetParlayDetail')
				ORDER BY s.LogId

			;WITH cteSiteDBCalculationLog
			AS (
				SELECT	(SELECT TOP 1 T.C.value('./@pid', 'bigint') FROM TransInfo.nodes('/parlay/r') AS T(C)) AS SiteDB_ParlaySettlementProcessingId
						,s.TransInfoJson
						,s.TableName
						,s.SessionId
				FROM	@SiteDBPendingLog s
				WHERE	s.IsParallel = 1
					AND s.TicketType = 'p'
					AND TableName IN ('bettrans', 'BetParlayResult')
			)
			UPDATE	p
				SET TransInfoBetParlayResult = ISNULL(s.TransInfoBetParlayResult, p.TransInfoBetParlayResult)
					,TransInfoBettrans = ISNULL(s.TransInfoBettrans, p.TransInfoBettrans)
			FROM	dbo.SiteDB_ParlaySettlementProcessing p
				INNER JOIN (
					SELECT	SiteDB_ParlaySettlementProcessingId
							,SessionId
							,MAX(CASE WHEN cte.TableName = 'BetParlayResult' THEN TransInfoJson ELSE NULL END) AS TransInfoBetParlayResult
							,MAX(CASE WHEN cte.TableName = 'bettrans' THEN TransInfoJson ELSE NULL END) AS TransInfoBettrans
					FROM	cteSiteDBCalculationLog cte
					GROUP BY SiteDB_ParlaySettlementProcessingId, SessionId
				)s
				ON p.SiteDB_ParlaySettlementProcessingId = s.SiteDB_ParlaySettlementProcessingId
					AND p.SessionId = s.SessionId
					AND p.SiteDBGroupId = @SiteDBGroupId

			IF @@ROWCOUNT <> 0
				INSERT INTO  dbo.SiteDB_SettlementService_CalculationLog_History (LogId, SiteDBGroupId, LogDate)
				SELECT s.LogId, @SiteDBGroupId, SYSDATETIME()
				FROM	@SiteDBPendingLog s
				WHERE	s.IsParallel = 1
						AND s.TicketType = 'p'	
						AND TableName IN ('bettrans', 'BetParlayResult')
				ORDER BY s.LogId
		END	
	END
	
	IF @MaxLogId > 0 -- run commands in sequence
	BEGIN
		SET @LogId = 0
		SET @MessageType = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type'
		SET @MessageTypeParlay = 'sitedb' + CAST(@SiteDBGroupId AS VARCHAR) + '_bet_settle_msg_type_parlay'

		WHILE (1=1)
		BEGIN
			SELECT	TOP 1 @CurrentLogId = s.LogId
					,@TransInfo = s.TransInfo
					,@TransInfoJson = s.TransInfoJson
					,@TableName = s.TableName
					,@MatchId = s.MatchId
					,@Action = s.Action
					,@SettlementAction = s.SettlementAction
					,@TicketType = s.TicketType	
					,@SessionId = s.SessionId
			FROM	@SiteDBPendingLog s
			WHERE	s.LogId > @LogId
					AND s.IsParallel = 0
			ORDER BY s.LogId

			IF @@ROWCOUNT = 0
				BREAK

			SET @xmlCommand = CAST((
					SELECT CAST(@TransInfo AS VARCHAR(MAX)) AS '@TransInfo'	
							,@TableName AS '@TableName'
							,@MatchId AS '@MatchId'
							,@Action AS '@Action'
							,@SettlementAction AS '@SettlementAction'
							,@TicketType AS '@TicketType'
							,@SiteDBGroupId AS '@SiteDBGroupId'
							,@SessionId AS '@SessionId'
							,@SiteDB_ExecDataQueueSize AS '@TotalQueue'
							,@SiteDB_ExecParlayDataQueueSize AS '@TotalParlayQueue'
							,CONVERT(nvarchar(max), @TransInfoJson, 1) AS '@TransInfoJson'	
					FOR XML PATH ('r'), ROOT ('root'), TYPE)
				AS VARCHAR(MAX))
				
			IF @TicketType = 'p'
				EXEC dbo.SSB_Send_Message 
					@MessageContent = @xmlCommand
					,@FunctionName = 'settlement'
					,@MessageType = @MessageTypeParlay
			ELSE
				EXEC dbo.SSB_Send_Message 
					@MessageContent = @xmlCommand
					,@FunctionName = 'settlement'
					,@MessageType = @MessageType

			SET @LogId = @CurrentLogId

			INSERT INTO  dbo.SiteDB_SettlementService_CalculationLog_History (LogId, SiteDBGroupId, LogDate)
			SELECT @LogId, @SiteDBGroupId, SYSDATETIME()
		END
	END	
END
GO
