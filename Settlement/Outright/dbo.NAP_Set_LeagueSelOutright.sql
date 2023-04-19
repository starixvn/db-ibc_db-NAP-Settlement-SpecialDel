/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_LeagueSelOutright]
	 @FromDate		SMALLDATETIME
	,@ToDate		SMALLDATETIME = NULL
AS
/**
 * Created by	: Jamie
 * Date			: 20130808
 * Task			: League Outright results 
 * DB			: DBPRO/bodb02

 * Revisions	:
	-- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
	- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
	- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
	- 20230317@Aries: Enhance Outright Settlement as User Feedback [Redmine:#185129]
	 
 * Parameters:
 *  @FromDate: From  date,
	@ToDate: To date 

 */
BEGIN 
	SET NOCOUNT ON

	;WITH CTE_Orid AS(   
		SELECT o.orid
		FROM outright AS o WITH(NOLOCK)
		WHERE  (@ToDate IS NULL AND o.eventdate >= @FromDate) 
            OR (@ToDate IS NOT NULL AND o.eventdate BETWEEN @FromDate AND @ToDate)
	) 
	, CTE_League AS (
        SELECT o.leagueid 
	    FROM outright AS o WITH(NOLOCK) 
		    INNER JOIN CTE_Orid c ON o.orid = c.orid
	    WHERE ISNULL(o.IsDeleted,0) = 0
	)
	SELECT l.leagueid, l.leaguename, l.sporttype 
    FROM League AS l WITH(NOLOCK)
	WHERE l.leagueid IN (SELECT cte.leagueid FROM CTE_League AS cte)   

END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_LeagueSelOutright] TO [bodbAdminNet]	
GO 



