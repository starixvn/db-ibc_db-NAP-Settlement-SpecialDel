/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created by: Max
	Date 20210105
	Task: Support to void tickets in bettrans14 - [Redmine: 148257]
	DB: DBTXN/bodb02
*/
DECLARE @TransIds_bettrans14 VARCHAR(MAX) = '110736616844,110738987386,110739062865,110738911218,110738922612,110738947325,110738950873,110738962484,110739054694'

CREATE TABLE #TransIds_bettrans14 (TransId BIGINT)
INSERT INTO #TransIds_bettrans14 (TransId)
SELECT	val AS TransId
FROM	dbo.f_SplitString(@TransIds_bettrans14, ',')
OPTION (maxrecursion 0)

--Insert into TicketVoiding_VoidedTransaction for bettrans14
DECLARE @ReasonId INT = 0 
INSERT INTO dbo.TicketVoiding_Reason (ReasonEnglish, ReasonChineseSimplified)
SELECT 'Technical Issue',N'技术问题'
	
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
