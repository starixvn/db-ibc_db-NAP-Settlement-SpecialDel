/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
use bodb02
go

update s
	set DeterminedType = t.DeterminedType
from SettlementSpecialBettypeProfile s with(nolock)
	inner join DBTXN.bodb02.dbo.SettlementSpecialBettypeProfile t with(nolock)
		on s.bettype = t.bettype
where s.sporttype = 1
and t.DeterminedType > 2