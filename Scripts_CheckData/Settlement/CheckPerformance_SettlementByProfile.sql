/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

SELECT execTime, * 
FROM Single_Calculate_Queue WITH(NOLOCK)
WHERE matchid = 53213024
and Action <> 'CAL-FM'

-- get sessionid
select *
from Settlement_SettledSession with(nolock)
where matchid = 53213024
order by CreatedTime desc

-- get batch upd
;with cte
as(
select StartTime, EndTime, MessageType, MessageBody
from SSB_SettlementLogs with(nolock)
where SessionId = 395953
and MessageType  like '%prepare%'
)
select c.MessageType, c.MessageBody, count(1) totalCommandUpd, c.StartTime, min(s.starttime) 'start upd', max(s.starttime) 'end upd', c.EndTime
from SSB_SettlementLogs s with(nolock)
	cross apply (
		select MessageType, MessageBody, c.StartTime, c.EndTime
		from cte c
		where  s.StartTime between c.StartTime and c.EndTime
	)c
where SessionId = 395953
and s.MessageType  not like '%prepare%'
group by c.MessageType, c.MessageBody, c.StartTime, c.EndTime
order by c.StartTime


-- settle rate
select count(1) cnt, convert(varchar(19), settlementtime, 121) settle_time_in_s					
from dbo.bettrans with(nolock)				
where matchid = 53213024				
and ISNULL(SettlementTime,'') > '2022-05-28 17:32:43.380'	-- exectime		
group by convert(varchar(19), settlementtime, 121)				
order by 2				