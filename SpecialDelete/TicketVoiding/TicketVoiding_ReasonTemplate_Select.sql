/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReasonTemplate_Select]
	@Sporttype		SMALLINT
	,@SubIssueTypeId	SMALLINT

AS
/*	Created by: Kathy
	Date 20181212
	Task: get reason template [Redmine:#106655]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	Sporttype
			,ReasonEnglish
			,ReasonChineseSimplified
	FROM	dbo.TicketVoiding_ReasonTemplate WITH(NOLOCK)
	WHERE	Sporttype = @Sporttype 
			AND SubIssueTypeId = @SubIssueTypeId

END
GO

