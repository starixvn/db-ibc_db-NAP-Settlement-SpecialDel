/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AccountWinLost_Select]
(
	@RequestId	INT = 0
)
AS
/*	
	Creator: 20231109@Max
	Task: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
	
	Revisions:
		- 20231109@Max: Create SP [Redmine:#194140]
*/
BEGIN

    SET NOCOUNT ON;
	
	SELECT acc.custid
		,c.username
		,acc.GivenCredit
		,acc.AdjustLimit AS AdjustVoidLimit
		,acc.CurrWinning AS CurrentWinning
		,acc.CurrLosing AS CurrentLosing
		,acc.EstVoidAmount AS EstimateVoidAmount
		,acc.WinlostAfterVoid AS WinLostAfterVoid
	FROM dbo.TicketVoiding_AbnormalAccountVoidAmount acc WITH (NOLOCK)
		INNER JOIN CustDB.dbo.custInfo c WITH (NOLOCK) ON c.custid = acc.custid
	WHERE acc.RequestId = @RequestId
	ORDER BY c.username
END
