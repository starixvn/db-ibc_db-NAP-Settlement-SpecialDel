/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTransaction_Insert] 
	 @TicketsXML		XML
	,@MessageId			INT
	,@ReasonId			INT
	,@IssueTypeId		INT = NULL
	,@SubIssueTypeId	INT = NULL
AS
/*	Created by: 20181212@Kathy
	Task: voided transaction [Redmine:#106655]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
		- 20190802@Raymond.Le: Insert info for dectect problem account [Redmine: #116617]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20230330@July: [TVS] Send problem customer in Abnormal Account request to CTS [Redmine:#185238]

	Param's explanation:	
		 @TicketsXML : <root><r TransId="1" CustId="1"  MatchId="1" /></root>
*/
BEGIN
	SET NOCOUNT ON

	SELECT @IssueTypeId = NULLIF(@IssueTypeId, 0)
		  ,@SubIssueTypeId = NULLIF(@SubIssueTypeId, 0)

	CREATE TABLE #tblTicketInfo (
		TransId BIGINT
		,CustId INT
		,MatchId INT
		)

	INSERT INTO #tblTicketInfo (
		TransId
		,CustId
		,MatchId
		)
	SELECT t.c.value('@TransId', 'BIGINT')
		  ,t.c.value('@CustId', 'INT')
		  ,t.c.value('@MatchId', 'INT')
	FROM @TicketsXml.nodes('root/r') t(c)

	INSERT INTO dbo.TicketVoiding_VoidedTransaction (
		TransId
		,MessageId
		,ReasonId
		,MatchId
		,IssueTypeId
		,SubIssueTypeId
		,CustID
		)
	SELECT TransId
		,@MessageId
		,@ReasonId
		,MatchId
		,@IssueTypeId
		,@SubIssueTypeId
		,CustId
	FROM #tblTicketInfo

	DROP TABLE #tblTicketInfo
END
