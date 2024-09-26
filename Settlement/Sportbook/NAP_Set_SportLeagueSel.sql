/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
			- 20220509@Kathy: Change to use STRING_SPLIT on DBPRO [Redmine:#172461]
			- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
			- 20221021@Louisa: Not get Pingoal basketball [Redmine:#178551]
			- 20221201@Louisa: Pingoal Esports [Redmine:#180808]
			- 20231219@Louisa: RedCat88 [Redmine:#198365]
			- 20240718@Kathy: Implement AiO for Baseball - 8 new bettypes [Redmine:#208026]

	 Param explanation:
			@Page:
					0 - Query for Multisports Page   
					1 - Query for Move Ticket Page 

*/
BEGIN
	DECLARE @tmpSports TABLE (SportType SMALLINT)

	INSERT INTO @tmpSports (SportType)
	SELECT	f.value
	FROM	STRING_SPLIT(@SportTypes, ',') f

	SELECT	s.SportType, m.leagueid
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpSports s
			ON m.sporttype = s.SportType
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
		AND 1 = CASE WHEN @Page = 1 THEN CASE 
											WHEN m.sporttype = 50 AND l.LeagueGroupID = 42 THEN 0 --  Saba Virtual Cricket
											WHEN m.sporttype = 8 AND ISNULL(l.SessionTime,0) <> 1 THEN 0 -- only show Series match: SessionTime = 1
											ELSE 1
										END
					 WHEN m.sporttype = 2 AND l.LeagueGroupID = 122 THEN 0  -- Pingoal basketball
					 WHEN m.sporttype = 43 AND l.LeagueGroupID IN (151,215) THEN 0  -- Pingoal ESports, RedCat
				ELSE 1 END
		AND ISNULL(m.IsDeleted,0) = 0
	GROUP BY s.SportType, m.leagueid
END
GO

