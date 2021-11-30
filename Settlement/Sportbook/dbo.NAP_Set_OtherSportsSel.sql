/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_OtherSportsSel]
	@FromDate	DATETIME
	,@ToDate	DATETIME
	,@Page		TINYINT = 0
AS
/*
	Created by: 20200604@Kathy
	Task: Get the list other sports
	DB:DBPRO.BODB02
	
	Revisions:
		- 20200604@Kathy: Get the list other sports [Redmine:#134843]
		- 20211125@Louisa: Mark Match no ticket [Redmine:#163469]

	Param's Explanation:
		@Page:
					0 - Query for Multisports Page
					1 - Query for Move Ticket Page
					2 - Query for Miscellaneous Page >> Delete No Ticket Match
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT	DISTINCT m.sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
			AND EXISTS (SELECT TOP 1 1 
						FROM	dbo.Sports s WITH(NOLOCK) 
						WHERE	s.SportType = m.sporttype
							AND 1 =  CASE WHEN @Page IN (0,1) AND s.SportType BETWEEN 2 AND 99 THEN 1
										  WHEN @Page = 2 AND s.SportType <= 99 THEN 1
										  ELSE 0
									END
					)
END
GO


