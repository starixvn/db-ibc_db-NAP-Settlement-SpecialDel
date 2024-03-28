/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReasonTemplate_Select]
	@Sporttype		SMALLINT
	,@SubIssueTypeId	SMALLINT

AS
/*	Created by: Kathy
	Date 20181212
	Task: get reason template [Redmine:#106655]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	
	IF EXISTS (SELECT TOP 1 1
				FROM dbo.TicketVoiding_ReasonTemplate WITH(NOLOCK)
				WHERE	Sporttype = @Sporttype 
						AND SubIssueTypeId = @SubIssueTypeId
		)
	BEGIN
		SELECT	Sporttype
				,ReasonEnglish
				,ReasonChineseSimplified
		FROM	dbo.TicketVoiding_ReasonTemplate WITH(NOLOCK)
		WHERE	Sporttype = @Sporttype 
				AND SubIssueTypeId = @SubIssueTypeId	
	END
	ELSE
	BEGIN
		SELECT	Sporttype
				,ReasonEnglish
				,ReasonChineseSimplified
		FROM	dbo.TicketVoiding_ReasonTemplate WITH(NOLOCK)
		WHERE	Sporttype = 0 
				AND SubIssueTypeId = @SubIssueTypeId
	END
END
GO

