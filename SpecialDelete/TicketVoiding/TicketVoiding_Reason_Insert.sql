/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Reason_Insert]
	@ReasonEnglish				NVARCHAR(150) = NULL
	,@ReasonChineseSimplified	NVARCHAR(150) = NULL
	,@ReasonId					INT = 0 OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: reason to void ticket [Redmine:#106655]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	INSERT INTO dbo.TicketVoiding_Reason (ReasonEnglish, ReasonChineseSimplified)
	SELECT @ReasonEnglish, @ReasonChineseSimplified
	
	SET @ReasonId = SCOPE_IDENTITY()

END
GO
