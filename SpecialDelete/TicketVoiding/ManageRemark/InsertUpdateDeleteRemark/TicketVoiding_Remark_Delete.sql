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

	DECLARE @LogRemarkInfo AS TABLE (
		MatchId			 INT
	   ,IsTest			 BIT
	   ,IsCheckedVar	 BIT
	   ,MistakenBy		 NVARCHAR(200)
	   ,DecidedBy		 NVARCHAR(200)
	   ,PerformedBy		 NVARCHAR(200)
	   ,UserId			 INT
	   ,LastModifiedBy	 INT
	   ,TV_IPTV			 NVARCHAR(200)
	   ,Provider		 NVARCHAR(200)
	   ,Source			 NVARCHAR(200)
	   ,Remark			 NVARCHAR(MAX)
	   ,Message			 NVARCHAR(MAX)
	   ,Description		 NVARCHAR(MAX)
	   ,ActionId		 TINYINT
	   ,CreatedDate		 DATETIME
	   ,LastModifiedDate DATETIME
	)

	IF (EXISTS (SELECT TOP 1 1 FROM TicketVoiding_Remark WITH (NOLOCK) WHERE RemarkId = @RemarkId))
	BEGIN
		DELETE b
			OUTPUT deleted.MatchId, deleted.IsTest, deleted.IsCheckedVar, deleted.MistakenBy, deleted.DecidedBy, deleted.PerformedBy, deleted.UserId, deleted.LastModifiedBy, deleted.TV_IPTV, deleted.Provider, deleted.Source, deleted.Remark, deleted.Message, deleted.Description, deleted.ActionId, deleted.CreatedDate, deleted.LastModifiedDate
			INTO @LogRemarkInfo (MatchId, IsTest, IsCheckedVar, MistakenBy, DecidedBy, PerformedBy, UserId, LastModifiedBy, TV_IPTV, Provider, Source, Remark, Message, Description, ActionId, CreatedDate, LastModifiedDate)
		FROM TicketVoiding_Remark AS b
		WHERE b.RemarkId = @RemarkId

		DELETE o
		FROM TicketVoiding_OperatorInfo AS o
		WHERE o.RemarkId = @RemarkId
	END

	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchId AS VARCHAR(20))
							+ ', IsTest: ' + CASE WHEN l.IsTest = 1 THEN 'True' ELSE 'False' END
							+ ', IsCheckedVar: ' + CASE WHEN l.IsCheckedVar = 1 THEN 'True' ELSE 'False' END
							+ ', MistakenBy: ' + ISNULL(l.MistakenBy, '')
							+ ', DecidedBy: ' + ISNULL(l.DecidedBy, '')
							+ ', PerformedBy: ' + ISNULL(l.PerformedBy, '')
							+ ', CreatedBy: ' + CAST(l.UserId AS VARCHAR(20))
							+ ', LastModifiedBy: ' + CAST(l.LastModifiedBy AS VARCHAR(20))
							+ ', TV_IPTV: ' + ISNULL(l.TV_IPTV, '')
							+ ', Provider: ' + ISNULL(l.Provider, '')
							+ ', Source: '  + ISNULL(l.Source,'')
							+ ', Remark: ' + ISNULL(l.Remark, '')
							+ ', Message: ' + ISNULL(l.Message, '')
							+ ', Description: ' + ISNULL(l.Description, '')
							+ ', ActionId: ' + CAST(l.ActionId AS VARCHAR(20))
							+ ', CreatedDate: ' + CAST(l.CreatedDate AS VARCHAR(20))
							+ ', LastModifiedDate: ' + CAST(l.LastModifiedDate AS VARCHAR(20))
							FROM @LogRemarkInfo AS l
							

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RemarkId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms,' 
							+ @LogDataContent
						AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT


END
GO