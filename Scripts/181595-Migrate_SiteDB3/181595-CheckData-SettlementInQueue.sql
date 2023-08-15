/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/

-- DBTXN/bodb02

--- Check Settlement queue
-- sportbook: single
select *
from Single_Calculate_Queue with(nolock)
where IsCalculating = 1

-- sportbook: parlay
select *
from Parlay_Calculate_Queue with(nolock)
where IsCalculating = 1

-- betbuilder
select *
from Single_Calculate_Queue_3rd with(nolock)
where IsCalculating = 1

-- VS betradar: single
select *
from Single_Calculate_Queue_VS with(nolock)
where IsCalculating = 1

-- VS betradar: parlay
select *
from Parlay_Calculate_Queue_VS with(nolock)
where IsCalculating = 1
