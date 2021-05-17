/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210504@July
	Task: TVS - Wrong Score Issue - [Redmine: #140953]
	DB: DBTXN-bodb02
*/

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,7,N'Wrong Score',N'由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,35,N'Wrong Score',N'由于比分显示错误')