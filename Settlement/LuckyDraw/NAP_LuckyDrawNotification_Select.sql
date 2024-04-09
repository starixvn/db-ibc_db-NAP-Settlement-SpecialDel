/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_LuckyDrawNotification_Select
	@IsTest BIT = 0
AS
/*	
	Created: 20240327@Louisa
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBCTG'bodb02

	Revision: 20240327@Louisa initial [Redmine:#202309]
*/
BEGIN
	SELECT l.DrawID
			,l.MatchID
			,l.TypeID
			,m.Kickofftime
			,m.HomeID
			,m.AwayID
			,l.CustID
			,c.username
			,c.recommend
			,r.username AS AgentName
			,c.mrecommend
			,mr.username AS MasterName
			,c.srecommend
			,s.username AS SuperName
			,c.Site
			,l.Currency AS CurrencyName
			,l.Payout AS PrizeAmount
			,l.VerificationCode
			,l.ExpiredDate
			,l.LastModifiedDate
			,IsTest
	FROM dbo.LuckyDrawList l WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)	ON l.matchid = m.matchid
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON l.custid = c.custid
		LEFT JOIN Custdb.dbo.customer r WITH(NOLOCK) ON c.recommend = r.custid AND r.roleid = 2
		LEFT JOIN Custdb.dbo.customer mr WITH(NOLOCK) ON c.mrecommend = mr.custid AND mr.roleid = 3
		LEFT JOIN Custdb.dbo.customer s WITH(NOLOCK) ON c.srecommend = s.custid AND s.roleid = 4
	WHERE l.IsNotify = 0
		AND l.IsTest = @IsTest

END
GO
