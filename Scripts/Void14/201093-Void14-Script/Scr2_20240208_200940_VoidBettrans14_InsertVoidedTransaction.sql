/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date: 20240208
	Task: Support to void tickets in bettrans14 - [Redmine: #201093]
	DB: DBTXN/bodb02 
	
*/ 
DECLARE @TransIds_bettrans14 VARCHAR(MAX) = '219518239527403528'
CREATE TABLE #TransIds_bettrans14 (TransId BIGINT)
INSERT INTO #TransIds_bettrans14 (TransId)
SELECT	val AS TransId
FROM	dbo.f_SplitString(@TransIds_bettrans14, ',')
OPTION (maxrecursion 0)

--Insert into TicketVoiding_VoidedTransaction for bettrans14
DECLARE @ReasonId INT = 0 
INSERT INTO dbo.TicketVoiding_Reason (ReasonEnglish, ReasonChineseSimplified)
SELECT N'Soccer - Technical Error',N'足球 - 技术有误'
	
SET @ReasonId = SCOPE_IDENTITY()

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
	, 0 AS MessageId
	,@ReasonId
	,0
	,NULL
	,NULL
	,b.CustId
FROM #TransIds_bettrans14 t
	INNER JOIN bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId
