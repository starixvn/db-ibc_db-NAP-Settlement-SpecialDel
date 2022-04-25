/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROC [NAP_Set_LeagueSel]
	@FromDate datetime,
	@ToDate datetime,
	@sporttype smallint = 0
AS

/*	Creator: Kathy
	Date: 20131223
	Task: select league to settle
	DB: DB02.bodb02
	
	Revision:	
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393] 
		- 20220425@Louisa: Remove League.IsDeleted [Redmine:#171698]

	Param's Explanation:
		
		
*/
SET NOCOUNT ON
if @sporttype = 0
begin 
	select DISTINCT league.leagueid, leaguename, match.sporttype
	from match with (nolock)
		inner join league with (nolock) on match.leagueid = league.leagueid
	where match.eventdate between @FromDate and @ToDate 
		and match.sporttype <> 162
		and ISNULL(match.IsDeleted,0) = 0

	UNION ALL
	
	SELECT DISTINCT o.leagueid, l.leaguename, l.sporttype
	FROM outright o (nolock)
		INNER JOIN league l (nolock) on o.leagueid = l.leagueid 
	WHERE o.eventdate between @FromDate and @ToDate
		and l.sporttype BETWEEN  151 AND 153
		and ISNULL(o.IsDeleted,0) = 0
	
	UNION ALL
	--- virtual horse racing
	SELECT DISTINCT r.leagueid, l.leaguename, l.sporttype
	FROM VSoutright o (nolock)
		INNER JOIN VSRaceinfo r WITH(NOLOCK) ON o.eventID = r.eventID
		INNER JOIN league l (nolock) on r.leagueid = l.leagueid 
	WHERE o.eventdate between @FromDate and @ToDate
		and l.sporttype in (181,182,184)
	order by sporttype, leaguename
	
end 
else if @sporttype IN (151,152,153) 
begin 
	SELECT DISTINCT o.leagueid, l.leaguename, l.sporttype
	FROM outright o (nolock)
		INNER JOIN league l (nolock) on o.leagueid = l.leagueid 
	WHERE o.eventdate between @FromDate and @ToDate
		and l.sporttype =  @sporttype
		and ISNULL(o.IsDeleted,0) = 0
	order by sporttype, leaguename
end 
else if @sporttype in (181,182,184)
begin 
	SELECT DISTINCT r.leagueid, l.leaguename, l.sporttype
	FROM VSoutright o (nolock)
		INNER JOIN VSRaceinfo r WITH(NOLOCK) ON o.eventID = r.eventID
		INNER JOIN league l (nolock) on r.leagueid = l.leagueid 
	WHERE o.eventdate between @FromDate and @ToDate
		and l.sporttype = @sporttype
	order by sporttype, leaguename
end 
else 
begin 
	select DISTINCT league.leagueid, leaguename, match.sporttype
	from match with (nolock)
		inner join league with (nolock) on match.leagueid = league.leagueid
	where match.eventdate between @FromDate and @ToDate
		and match.sporttype = @sporttype
		and ISNULL(match.IsDeleted,0) = 0
	order by leaguename
end

GO

GRANT EXECUTE ON [NAP_Set_LeagueSel] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Set_LeagueSel] TO [vnteam] AS [dbo]
GO


