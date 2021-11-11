/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_OtherSportsSel]
	@FromDate	DATETIME
	,@ToDate	DATETIME
AS
/*
	Created by: 20200604@Kathy
	Task: Get the list other sports
	DB:DBPRO.BODB02
	
	Revisions:
		- 20200604@Kathy: Get the list other sports [Redmine:#134843]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]

	Param's Explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	DISTINCT m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
			AND ISNULL(m.IsDeleted,0) = 0
			AND EXISTS (SELECT TOP 1 1 
						FROM	dbo.Sports s WITH(NOLOCK) 
						WHERE	s.SportType = m.sporttype
								AND s.SportType BETWEEN 2 AND 99
					)
END
GO


