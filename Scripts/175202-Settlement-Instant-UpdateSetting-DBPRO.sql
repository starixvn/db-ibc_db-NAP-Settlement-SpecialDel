/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
use bodb02
go
-- 29 rows affected
update s
	set DeterminedType = isnull(s.determinedtype,0) 
							+ case 
								when f.instanttype = 1 then 1 
								when f.instanttype = 2 then 4
								when f.instanttype = 3 then 5
								else 0
							end
from SettlementSpecialBettypeProfile s with(rowlock, updlock)
	inner join DBTXN.bodb02.dbo.f_Set_Instant_GetBettypes() f
		on s.bettype = f.bettype
where s.sporttype = 1

go