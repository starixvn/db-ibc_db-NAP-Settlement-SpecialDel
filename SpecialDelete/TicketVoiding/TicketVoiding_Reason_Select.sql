/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Reason_Select]
	@ReasonId	INT = 0
AS
/*	Created by: Charles
	Date 20201022
	Task: Get reason info from reasonId [Redmine:#145719]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20201204@Charles: Create new SP [Redmine: #145719]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT ReasonId, ReasonEnglish, ReasonChineseSimplified
	FROM dbo.TicketVoiding_Reason WITH(NOLOCK)
	WHERE ReasonId = @ReasonId

END
GO
