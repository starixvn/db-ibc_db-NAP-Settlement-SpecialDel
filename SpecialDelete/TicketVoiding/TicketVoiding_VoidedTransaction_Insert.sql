/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]

	Param's explanation:	
		 @TicketsXML : <root><r TransId="1" CustId="1"  MatchId="1" winlostdate="" status="" bettypeid="" stake="" winlost="" VoidingHistoryId="" SiteDBGroupID=""/></root>
*/
BEGIN
	SET NOCOUNT ON

	SELECT @IssueTypeId = NULLIF(@IssueTypeId, 0)
		  ,@SubIssueTypeId = NULLIF(@SubIssueTypeId, 0)

	CREATE TABLE #tblTicketInfo (
		TransId BIGINT
		,CustId INT
		,MatchId INT
		,winlostdate SMALLDATETIME
		,status NVARCHAR(10)
		,BetType SMALLINT
		,stake MONEY
		,winlost MONEY
		,VoidingHistoryId INT
		,SiteDBGroupID SMALLINT
		)

	INSERT INTO #tblTicketInfo (
		TransId
		,CustId
		,MatchId
		,winlostdate
		,status
		,bettype
		,stake
		,winlost
		,VoidingHistoryId
		,SiteDBGroupID
	)
	SELECT t.c.value('@TransId', 'BIGINT')
		  ,t.c.value('@CustId', 'INT')
		  ,t.c.value('@MatchId', 'INT')
		  ,t.c.value('@WinLostDate', 'SMALLDATETIME')
		  ,t.c.value('@Status', 'NVARCHAR(10)')
		  ,t.c.value('@BetTypeId', 'SMALLINT')
		  ,t.c.value('@Stake', 'MONEY')
		  ,t.c.value('@WinLost', 'MONEY')
		  ,t.c.value('@VoidingHistoryId', 'INT')
		  ,t.c.value('@SiteDbGroupId', 'SMALLINT')
	FROM @TicketsXml.nodes('root/r') t(c)

	INSERT INTO dbo.TicketVoiding_VoidedTransaction (
		TransId
		,MessageId
		,ReasonId
		,MatchId
		,IssueTypeId
		,SubIssueTypeId
		,CustID
		,winlostdate
		,status
		,bettype
		,stake
		,winlost
		,VoidingHistoryId
		,SiteDBGroupID
		)
	SELECT TransId
		,@MessageId
		,@ReasonId
		,MatchId
		,@IssueTypeId
		,@SubIssueTypeId
		,CustId
		,CASE WHEN winlostdate = '1900-01-01 00:00:00.000' THEN NULL ELSE winlostdate END
		,status
		,bettype
		,stake
		,winlost
		,VoidingHistoryId
		,SiteDBGroupID
	FROM #tblTicketInfo

	DROP TABLE #tblTicketInfo
END
