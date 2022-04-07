/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20220401@July 
	Task: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (1, 10, 'Wrong Over Under',N'大小盘显示错误' )
	  ,(1, 11, 'Wrong 1H Over Under',N'上半场大小盘显示错误' )
	   
GO
