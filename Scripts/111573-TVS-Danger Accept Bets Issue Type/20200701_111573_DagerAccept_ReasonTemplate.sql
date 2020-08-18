/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20200701@Max 
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 1, 'Danger Accept In Goal',N'有进球的危险时段中误被接受' )
	,(0, 2, 'Danger Accept In Corner',N'在有角球的危险时段中误被接受' )
	,(0, 3, 'Danger Accept In Booking',N'有罚牌的危险时段中误被接受' )
	,(0, 4, 'Danger Accept In Home Red Card',N'主隊紅牌危險時段中誤被接受' )
	,(0, 5, 'Danger Accept In Away Red Card',N'客队红牌危险时段中误被接受' )
	,(0, 26, 'Danger Accept In Corner',N'在有角球的危险时段中误被接受' )

GO


