/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTransaction_Insert] @TransIds VARCHAR(MAX)
	,@MessageId INT
	,@ReasonId INT
	,@MatchId INT = NULL
	,@IssueTypeId INT = NULL
	,@SubIssueTypeId INT = NULL
	,@XmlCustInfo XML
AS
/*	Created by: Kathy
	Date 20181212
	Task: voided transaction [Redmine:#106655]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
		- 20190802@Raymond.Le: Insert info for dectect problem account [Redmine: #116617]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpTransId TABLE (TransId BIGINT)

	CREATE TABLE #tblCustInfo (
		TransId BIGINT
		,CustId INT
		)

	--
	SELECT @IssueTypeId = NULLIF(@IssueTypeId, 0)
		,@SubIssueTypeId = NULLIF(@SubIssueTypeId, 0)

	INSERT INTO @tmpTransId (TransId)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')

	INSERT INTO #tblCustInfo (
		TransId
		,CustId
		)
	SELECT Info.Item.value('@TransId', 'bigint')
		,Info.Item.value('@CustId', 'int')
	FROM @XmlCustInfo.nodes('/CustInfo/Item') AS Info(Item)

	INSERT INTO dbo.TicketVoiding_VoidedTransaction (
		TransId
		,MessageId
		,ReasonId
		,MatchId
		,IssueTypeId
		,SubIssueTypeId
		,CustID
		)
	SELECT t.TransId
		,@MessageId
		,@ReasonId
		,@MatchId
		,@IssueTypeId
		,@SubIssueTypeId
		,c.CustId
	FROM @tmpTransId AS t
		LEFT JOIN #tblCustInfo AS c ON t.TransId = c.TransId

	DROP TABLE #tblCustInfo
END
