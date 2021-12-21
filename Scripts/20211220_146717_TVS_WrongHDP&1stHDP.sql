/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211220@July
	Task: TVS - Wrong Handicap/Wrong 1st HDP - [Redmine: #146717]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,8,'Wrong HDP',N'亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,22,'Wrong HDP',N'亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,23,'Wrong HDP',N'亚洲盘显示错误')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,9,'Wrong 1st HDP',N'上半场亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,24,'Wrong 1st HDP',N'上半场亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,25,'Wrong 1st HDP',N'上半场亚洲盘显示错误')
