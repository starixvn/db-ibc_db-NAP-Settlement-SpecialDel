/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_UserActionLog_Update]
(
	@Userid	INT = 0
	,@LogDate SMALLDATETIME = NULL
	,@FunctionName VARCHAR(500) = NULL
	,@LogContent NVARCHAR(MAX) = NULL
	,@IsActionCount BIT = 0
)
AS
/*
	Created by: 20240618@Max
	Task: [TVS] Set logs to check user behavior [Redmine:#204060]  
	DB: DBCTG.bodb02

	Revisions:
		- 20240618@Max: Create new SP - Get all site [Redmine: #204060]

	 Param's Explanation:  
	  - @IsActionCount = 1: Log count function access
					   = 0: Log user edit
*/					    
BEGIN
	SET NOCOUNT ON

	RETURN 

	SET NOCOUNT OFF
END
GO

