/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220318@July
	Task: TVS - Update Reason to void in Chinese - [Redmine: #164562]
	DB: DBTXN-bodb02

	Note: Reason to void in Chinese: Remove the highlight characters (由于)
*/
USE bodb02
GO

/*dbo.TicketVoiding_ReasonTemplate*/

--1.Wrong Score
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'比分显示错误'
WHERE SubIssueTypeId IN (7,35,94,95,96,97,98,99)

--2.Red Card
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'主队红牌遗漏显示导致盘口有误'
WHERE SubIssueTypeId = 15 --No Indication Home RC

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'客队红牌遗漏显示导致盘口有误'
WHERE SubIssueTypeId = 16 --No Indication Away RC

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'主队红牌错误显示导致盘口有误'
WHERE SubIssueTypeId = 17 --Wrong Indication Home RC

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'客队红牌错误显示导致盘口有误'
WHERE SubIssueTypeId = 18 --Wrong Indication Away RC

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'主队于常规时段内已得红牌'
WHERE SubIssueTypeId = 19 --Home RC award under Regular Time

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'客队于常规时段内已得红牌'
WHERE SubIssueTypeId = 20 --Away RC award under Regular Time

UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'红牌球员被替换导致提供错误的赔率'
WHERE SubIssueTypeId = 21 --Replacement of Sent-Off player

--3.Abnormal Bet
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'非正常投注'
WHERE SubIssueTypeId IN (27,28,29,30,31,32,36,37,38)

--4.AB (Real Member)
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'非正常投注'
WHERE SubIssueTypeId IN (41,42,43,44,45,46,47,48,49)

--5.Early Kick Off
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'赛事时间提前开始'
WHERE SubIssueTypeId IN (12,13)

--6.Wrong Kick Off Time
UPDATE dbo.TicketVoiding_ReasonTemplate WITH(ROWLOCK,UPDLOCK)
SET	ReasonChineseSimplified = N'开赛时间显示有误'
WHERE SubIssueTypeId = 14