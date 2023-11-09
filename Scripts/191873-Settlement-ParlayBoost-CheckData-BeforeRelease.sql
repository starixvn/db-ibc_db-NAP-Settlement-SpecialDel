-- Run on DBTP/bodb02
USE bodb02
GO
--dbtp
 with __cb as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from dbo.BetParlayResult r  with(nolock)
	where winlostdate = '2023-10-23'
		and exists (
			select top 1 1 from dbo.bettrans b with(nolock)
			where r.RefNo = b.refno 
				and SiteDBGroupID = 1
		)
), __ct as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from DBGRP01L.bodb02.dbo.BetParlayResult with(nolock)
	where winlostdate = '2023-10-23'
)
select top 1000 *
from __cb t
full outer join __ct tt on t.[RefNo] = tt.[RefNo] and t.[Serial] = tt.[Serial]
where isnull(t.__sum, 0) <> isnull(tt.__sum, 0)

GO
with __cb as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from dbo.BetParlayResult r  with(nolock)
	where winlostdate = '2023-10-23'
		and exists (
			select top 1 1 from dbo.bettrans b with(nolock)
			where r.RefNo = b.refno 
				and SiteDBGroupID = 2
		)
), __ct as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from DBGRP02L.bodb02.dbo.BetParlayResult with(nolock)
	where winlostdate = '2023-10-23'
)
select top 1000 *
from __cb t
full outer join __ct tt on t.[RefNo] = tt.[RefNo] and t.[Serial] = tt.[Serial]
where isnull(t.__sum, 0) <> isnull(tt.__sum, 0)

GO

with __cb as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from dbo.BetParlayResult r  with(nolock)
	where winlostdate = '2023-10-23'
		and exists (
			select top 1 1 from dbo.bettrans b with(nolock)
			where r.RefNo = b.refno 
				and SiteDBGroupID = 3
		)
), __ct as (
	select [RefNo], [Serial], binary_checksum ([transid], [winlostdate], [statusid], [stake], [Odds], [mOdds], [winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [ExtraValue]) as __sum --,betid,betcheck
	from DBGRP03L.bodb02.dbo.BetParlayResult with(nolock)
	where winlostdate = '2023-10-23'
)
select top 1000 *
from __cb t
full outer join __ct tt on t.[RefNo] = tt.[RefNo] and t.[Serial] = tt.[Serial]
where isnull(t.__sum, 0) <> isnull(tt.__sum, 0)