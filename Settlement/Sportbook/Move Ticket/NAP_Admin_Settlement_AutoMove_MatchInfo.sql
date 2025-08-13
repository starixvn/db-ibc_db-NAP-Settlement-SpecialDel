/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_AutoMove_MatchInfo
	@EventDate DATE
/*	
	Created: 20250721@Louisa
	Task: Auto move ticket of Cricket [Redmine:#227191]
	DB: DBPRO/bodb02
	
	Revisions:
		- 20250721@Louisa: Created [Redmine:#227191] 
*/
AS
BEGIN
	SET NOCOUNT ON 

	DECLARE @MainMatchInfo TABLE ( MatchId INT, sporttype SMALLINT, SettlementStatus TINYINT, eventdate DATETIME )

	INSERT INTO @MainMatchInfo ( MatchId, sporttype, SettlementStatus, eventdate )
	SELECT m.matchid, m.sporttype, m.SettlementStatus, m.eventdate 
	FROM dbo.Match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.sporttype IN (50, 8)
		AND ( 
				(l.sporttype = 50 AND l.GameSession IN (1,8) ) OR (l.sporttype = 8 AND l.GameSession = 1) 
			)
		AND ISNULL(m.ParentID, 0) = 0
		AND m.eventstatus <> 'completed'
		AND m.eventdate = @EventDate
		AND m.kickofftime < GETDATE()
		AND m.IsDeleted = 0

	SELECT m.MatchId, m.sporttype, m.SettlementStatus, c.MatchId AS ChildMatchId, ResourceID
	FROM @MainMatchInfo m
		INNER JOIN dbo.ResultDetailOS r WITH(NOLOCK)
			ON	m.matchid = r.MatchId
				AND r.ResultStatusID IN ( 2, 5 )
		OUTER APPLY (	SELECT TOP 1 c.matchid
						FROM match c WITH(NOLOCK)
						WHERE ISNULL(ParentID,0) = m.MatchId
							AND ISNULL(c.ChildMatchType,0) = 200
							AND c.IsDeleted = 0
							AND c.eventdate = m.eventdate
					) c 
 
END
GO
