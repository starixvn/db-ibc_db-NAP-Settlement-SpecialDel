/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SportLeagueSel
	@SportTypes VARCHAR(MAX) 
	,@FromDate	DATETIME
	,@ToDate	DATETIME
	,@Page		TINYINT = 0
AS
/*  
	 Created by: Kathy
	 Date: 20200528
	 Task: Get league belong to sport [Redmine:#134843] 
	 DB: DBPRO/bodb02
	 
	 Revisions:  
			- 20200528@Kathy: Get league belong to sport [Redmine:#134843]
			- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
			- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
      
	 Param explanation:
			@Page:
					0 - Query for Multisports Page
					1 - Query for Move Ticket Page 

*/
BEGIN
	DECLARE @tmpSports TABLE (SportType SMALLINT)

	INSERT INTO @tmpSports (SportType)
	SELECT	f.val
	FROM	dbo.f_SplitString(@SportTypes, ',') f
	OPTION (MAXRECURSION 0)

	SELECT	s.SportType, m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpSports s
			ON m.sporttype = s.SportType
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
		AND 1 = CASE WHEN @Page = 1 AND m.sporttype = 50 AND l.LeagueGroupID = 42 THEN 0 --  Saba Virtual Cricket
				ELSE 1 END
		AND ISNULL(m.IsDeleted,0) = 0
		AND ISNULL(l.IsDeleted,0) = 0
	GROUP BY s.SportType, m.leagueid
END
GO

