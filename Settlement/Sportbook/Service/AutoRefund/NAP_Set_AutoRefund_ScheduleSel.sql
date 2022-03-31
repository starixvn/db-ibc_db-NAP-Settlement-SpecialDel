/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_AutoRefund_ScheduleSel
AS
/*
	Creator: 20201216@Louisa
	Task: Auto refund ET & PEN match [Redmine:#145597]
	DB: DBPRO/bodb02
	Revisions:
		- 20201216@Louisa: Get ET & PEN match for Auto Refund Service [Redmine:#145597]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]

*/
BEGIN
	
	SET NOCOUNT ON

	SELECT ar.MatchId
		 , m.leagueid
		 , ar.TypeId
	FROM dbo.AutoRefundResult ar WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON m.matchid = ar.matchid
	WHERE ar.SourceId = 105
		AND ar.StatusId = 0
		AND ar.TypeId = 1

END
GO

