/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

declare @AutoType tinyint = 5

;with cteMatchId
as
(
	select m.matchid, ((isnull(m.AutoSetting, l.AutoSetting) | power(2,@AutoType - 1)) - 1) as AutoSetting  -- on bit 5, off bit 1
	from match m with(nolock)
	inner join league l with(nolock)
	  on m.leagueid = l.leagueid
	where m.sporttype = 50
	and ISNULL(m.AutoSetting, l.AutoSetting) & 1 > 0 
	and eventstatus <> 'completed'
)
update  m 
	set AutoSetting = c.AutoSetting
from dbo.match m with(rowlock, updlock)
	inner join cteMatchId c
		on c.matchid = m.matchid
	

;with cteLeagueId
as(
	select	l.leagueid, ((l.AutoSetting | power(2,@AutoType -1)) - 1) as AutoSetting -- on bit 5, off bit 1
	from	dbo.League l with(nolock)
	where	l.sporttype = 50
			and ISNULL(l.autosetting,0) & 1 > 0
)
update l
	set AutoSetting = c.AutoSetting
from dbo.League l with(rowlock, updlock)
	inner join cteLeagueId c
		on c.leagueid = l.leagueid