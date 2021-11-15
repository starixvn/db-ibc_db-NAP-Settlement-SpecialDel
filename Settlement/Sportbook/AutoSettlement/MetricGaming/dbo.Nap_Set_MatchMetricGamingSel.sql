  /*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
  ALTER PROCEDURE [dbo].[Nap_Set_MatchMetricGamingSel]
	@fromdate	DATETIME,
	@todate		DATETIME,
	@MatchCode	VARCHAR(50)='',
	@StatusID	TINYINT = 0,
	@Leagueid	INT =0	
 AS
	/*
		Created: Johnson
		Date: 2015-06-29
		Task: Get matches offer MG
		DB: DBPRO/bodb02
		
		Revisions:
			- 20211108@Louisa: In-house Replicator: Delete Action [Redmine:#164393] 
		
		Parameter's Explanation:
			- @StatusID: 0: all, 1: running, 3: completed
			- @matchcode = '' : all
			- @leagueid = 0: all
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @matchid INT
	
	SELECT @matchid = 0
	
	IF @MatchCode <> ''
	BEGIN	
		SELECT @matchid =  CASE WHEN ISNUMERIC(@MatchCode) = 1 THEN CAST(@matchCode AS INT) ELSE 0 END
	END
		
	SELECT  
		m.matchid, 
		m.matchcode, 
		m.kickofftime, 
		m.leagueid, 
		m.homeid, 
		m.awayid,
		m.hthomescore AS HalfTimeHomeScore,
		m.htawayscore AS HalfTimeAwayScore,
		m.finalhomescore,
		m.finalawayscore,
		ISNULL(mr.isUndecided,0) as isUndecided,
		CASE WHEN rs.SettlementStatusID = 0 then 'Running' ELSE 'Completed' END as EventStatus
	FROM match m WITH(NOLOCK) 	
		INNER JOIN (SELECT matchid, MIN(SettlementStatusID) as SettlementStatusID
					FROM ResultDetail3rd WITH(NOLOCK)
					GROUP BY matchid
					) rs  ON m.matchid = rs.matchid
		INNER JOIN VendorStatus vs WITH(NOLOCK) ON m.matchid = vs.matchid		
		LEFT JOIN match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	WHERE m.eventdate BETWEEN @fromdate AND @todate
		AND m.sporttype = 1
		AND (ISNULL(@matchcode,'') = '' OR m.matchid = @matchid OR m.matchcode = @matchcode)
		AND (@leagueid = 0 OR m.leagueid = @leagueid)
		AND 1 = CASE WHEN @statusid = 0 THEN 1
					WHEN @statusid = 1 AND rs.SettlementStatusID = 0 THEN 1
					WHEN @statusid = 3 AND rs.SettlementStatusID IN (1,4) THEN 1 
					ELSE 0 
				END
		AND vs.opened = 1 -- this match is offered Metric Gaming		
		AND vs.VendorID = 5
		AND ISNULL(m.IsDeleted,0) = 0
	ORDER BY EventStatus DESC, leagueid, kickofftime
		
END
GO