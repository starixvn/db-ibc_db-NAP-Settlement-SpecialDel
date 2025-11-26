/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE NAP_Set_RefundEarly_ESport_Sel
	@Resourceids VARCHAR(MAX)
AS
/*
	Creator: 20251124@Hughie
	Task: Auto Refund- ES- Refund Main Map Result Shall Trigger Refund Early Map Result [Redmine:#238033]
	DB: DBPRO/bodb02
	Revisions:
		- 20251124@Hughie: Created  [Redmine: #238033]

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @Resource TABLE (ResourceId	VARCHAR(20), PRIMARY KEY (ResourceId))

	INSERT INTO @Resource(ResourceId)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@ResourceIds,',')
	WHERE value != ''

	;WITH cte AS (
	  SELECT DISTINCT b.BetID
	  FROM SettlementSpecialBettypeProfile AS b WITH (NOLOCK)
		INNER JOIN @Resource AS r
			ON r.ResourceId = b.ResourceID
	  WHERE b.SportType  = 43
		AND b.SettleType = 'MNL'
	)
	SELECT DISTINCT a.ResourceID
	FROM SettlementSpecialBettypeProfile AS a WITH (NOLOCK)
		INNER JOIN cte m
			ON m.BetID = a.BetID
	WHERE a.SportType  = 43
	  AND a.SettleType = 'EAR'
END