ALTER PROCEDURE [dbo].[NAP_Set_OutrightSelInfoByLeagueID]
	 @LeagueID	INT 
	,@StatusID	INT = 0 
AS 
/**
 * Created by	: Jamie
 * Date			: 20130829
 * Task			: Outright results by LeagueID 
 * DB			: DBPRO/bodb02

 * Revisions	:
	- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]

 * Parameters: 
	@StatusID: 0=ALL (N/A)| 1=Running | 2=Closed (N/A) | 3=Completed (Already settled: WON/LOSE/REFUND) 
 */
BEGIN   
	SET NOCOUNT ON  

	SELECT	 o.orid
			,o.leagueid
			,o.[teamid]
			,o.matchcode
			,o.kickofftime
			,o.eventdate
			,o.IsDeadheat
			,ISNULL(o.oddsstatus, 'Running') AS oddsstatus
			,ISNULL(o.status, 'Running') AS status
			,l.sporttype
			,odds
	FROM	dbo.outright o WITH (NOLOCK)
			INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = o.leagueid
	WHERE	o.leagueID = @LeagueID 	
			AND ISNULL(o.[status],'Running') = CASE WHEN @StatusID = 1 THEN 'Running'						-- Running 
													ELSE o.[status] END 
			AND o.oddsstatus = CASE WHEN @StatusID = 0 THEN o.oddsstatus	-- ALL
									WHEN @StatusID = 3 THEN 'Completed'		--	Settled already 
									ELSE o.oddsstatus END 
			AND ISNULL(o.IsDeleted,0) = 0 
	ORDER BY o.[teamid] ASC 
END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_OutrightSelInfoByLeagueID] TO [bodbAdminNet]
GO
