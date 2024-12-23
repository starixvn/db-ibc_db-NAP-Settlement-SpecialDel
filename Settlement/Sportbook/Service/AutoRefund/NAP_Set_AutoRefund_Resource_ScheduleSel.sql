/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_Resource_ScheduleSel] 
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.matchid 
		, m.leagueid
		, m.sporttype
		, ar.ResourceId
		, ar.HomeValue
		, ar.AwayValue
	FROM dbo.AutoRefundResult AS ar WITH(NOLOCK) 
		INNER JOIN match AS m WITH(NOLOCK)  ON ar.matchId = m.matchId
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime, ss.[Enable]
			FROM	dbo.SettlementSetting AS ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND ss.AutoType = 7 -- Auto Refund
		) ss
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime, ss.[Enable]
			FROM	dbo.AutoPayoutSetting AS ss WITH (NOLOCK)
			WHERE	ss.matchid = m.matchid
					AND ss.AutoType = 7 -- Auto Refund
		) ms
	WHERE	ar.TypeId = 7 
			AND ar.StatusId = 0	
			AND COALESCE(ms.[Enable],ss.[Enable],0) = 1		
			AND ISNULL(m.SettlementStatus,0) & 87 = 0
			AND ar.CreateDate <= DATEADD(SECOND, - COALESCE(ms.WaitingTime,ss.WaitingTime,1), @CurrTime)
END
GO
