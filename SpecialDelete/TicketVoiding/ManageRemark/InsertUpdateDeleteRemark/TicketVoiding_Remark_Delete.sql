/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Remark_Delete]
	@RemarkId				INT
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL	
AS
/*	
	Created by: 20251120@Lani
	Task: Manage Remark - New function [Redmine: #234937]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20251120@Lani: Create new SP [Redmine: #234937]
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)
			,@LogActionId		 INT = 90509
			,@MatchId			 INT = 0
			,@ActionId			 INT = 0

	IF (EXISTS (SELECT TOP 1 1 FROM TicketVoiding_Remark WITH (NOLOCK) WHERE RemarkId = @RemarkId))
	BEGIN
		SELECT @MatchId = MatchId, @ActionId = ActionId
		FROM TicketVoiding_Remark WITH (NOLOCK)
		WHERE RemarkId = @RemarkId

		DELETE b
		FROM TicketVoiding_Remark AS b WITH (NOLOCK)
		WHERE b.RemarkId = @RemarkId
	END

	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
							+ ', ActionId: ' + CAST(@ActionId AS VARCHAR(20))
							

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RemarkId AS '@RemarkId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
							+ @LogDataContent
						AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT


END
GO