/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
	- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]
	- 20230109@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]

 * Parameters: 
	@StatusID: 0=ALL (N/A)| 1=Running | 2=Running AND Completed | 3=Completed (Already settled: WON/LOSE/REFUND) | 4 =Completed AND WON
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
	FROM	dbo.outright AS o WITH (NOLOCK)
			INNER JOIN dbo.League AS l WITH (NOLOCK) ON l.leagueid = o.leagueid
	WHERE	o.leagueID = @LeagueID 	
			AND 1 = CASE WHEN @StatusID = 0 THEN 1
						 WHEN @StatusID = 1 AND o.oddsstatus IN ('Running','Closed','ClosedPrice','Internal', 'Suspend') THEN 1
						 WHEN @StatusID = 2 AND o.oddsstatus IN ('Running','Closed','ClosedPrice','Internal', 'Suspend', 'Completed') THEN 1
						 WHEN @StatusID = 3 AND o.oddsstatus = 'Completed'	THEN 1	
						 WHEN @StatusID = 4 AND o.oddsstatus = 'Completed' AND o.status = 'WON' THEN 1
						 ELSE 0
					 END 
			AND ISNULL(o.IsDeleted,0) = 0
	ORDER BY o.[teamid] ASC; 
END
GO
GRANT EXECUTE ON [dbo].[NAP_Set_OutrightSelInfoByLeagueID] TO [bodbAdminNet]
GO
