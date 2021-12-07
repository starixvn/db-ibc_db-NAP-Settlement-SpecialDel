/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20211207@Kathy
	Task: update data 2 new column [Redmine:#164819]  
	DB: DBTXN.bodb02
		   
*/

declare @transids varchar(max) = ''
		,@query nvarchar(max) = ''

declare @tmptransidbk table (transid bigint)
declare @tmpbettransbk table (transid bigint, bettype smallint, betid bigint)

update s	
	set Bettype = b.bettype
		,BetId = b.betid
from TicketVoiding_RequestDetailTicket_Single s with(nolock)
	inner join dbo.bettrans b with(nolock)
		on s.TransId = b.transid

update s	
	set Bettype = b.bettype
		,BetId = b.betid
from TicketVoiding_RequestDetailTicket_Single s with(nolock)
	inner join dbo.bettrans14 b with(nolock)
		on s.TransId = b.transid

insert into @tmptransidbk(transid)
select s.TransId
from TicketVoiding_RequestDetailTicket_Single s with(nolock)
where not exists (select transid 
				  from bettrans b with(nolock) 
				  where b.transid = s.TransId
				  union all 
				  select transid 
				  from bettrans14 b14 with(nolock)
				  where b14.transid = s.TransId
				 )

select @transids = @transids + cast(transid as varchar) + ','
from @tmptransidbk

set @transids = SUBSTRING(@transids,1,len(@transids) - 1)

set @query = 'SELECT	transid, bettype, betid
				FROM	OPENQUERY(dbarc, ''SELECT	transid, bettype, betid
				FROM	bodb_archive.dbo.bettrans_bk AS b WITH (NOLOCK)
				WHERE	transid IN (' + @transids + ')'')'

insert into @tmpbettransbk(transid, bettype, betid)
exec (@query)

update s 
	set Bettype = b.bettype
		,BetId = b.betid
from dbo.TicketVoiding_RequestDetailTicket_Single s with(rowlock, updlock)
	inner join @tmpbettransbk b
		on s.TransId = b.transid

