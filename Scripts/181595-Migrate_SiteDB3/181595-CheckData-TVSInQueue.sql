/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/

-- DBTXN/bodb02
select *
from TicketVoiding_Queue with(nolock)
where StatusId = 1

select *
from TicketVoiding_AutoVoidQueue with(nolock)
where StatusId = 1