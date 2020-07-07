/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SportLeagueSel
	@SportTypes VARCHAR(MAX) 
	,@FromDate DATETIME
	,@ToDate DATETIME
AS
/*  
	 Created by: Kathy
	 Date: 20200528
	 Task: Get league belong to sport [Redmine:#134843] 
	 DB: DBPRO/bodb02
	 
	 Revisions:  
			- 20200528@Kathy: Get league belong to sport [Redmine:#134843] 
      
	 Param explanation:  

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
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
	GROUP BY s.SportType, m.leagueid
END
GO

