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
			,@LogActionId		 INT = 90509

	IF (EXISTS (SELECT TOP 1 1 FROM TicketVoiding_Remark WITH (NOLOCK) WHERE RemarkId = @RemarkId))
	BEGIN
		DELETE b
			
		FROM TicketVoiding_Remark AS b
		WHERE b.RemarkId = @RemarkId

		DELETE o
		FROM TicketVoiding_OperatorInfo AS o
		WHERE o.RemarkId = @RemarkId
	END

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RemarkId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms' 
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT


END
GO