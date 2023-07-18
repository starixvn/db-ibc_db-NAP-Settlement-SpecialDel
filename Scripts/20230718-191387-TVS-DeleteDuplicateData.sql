/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230718@Max
	Task: [TVS] Support delete duplicate data [Redmine: #190427]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

--TicketVoiding_VoidedTransaction
DELETE v 
FROM dbo.TicketVoiding_VoidedTransaction v 
WHERE v.TransId IN (138688612861476880	,		
				138688685875920910	,		
				138688685875920911	,		
				138688685875920916	,		
				138688685875920935	,		
				138688685875920936	,		
				138688685875920942
	)
AND v.MessageId = 1752506 
AND v.ReasonId = 104754

--TicketVoiding_Reason
DELETE r
FROM dbo.TicketVoiding_Reason r
WHERE r.ReasonId = 104754
	

