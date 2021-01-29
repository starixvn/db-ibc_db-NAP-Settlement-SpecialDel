/*
	Created: 20210129@Kathy
	DB: DBPRO.bodb02
	Task: get statistics of auto refund match function [Redmine:#145597]
*/
use bodb02
go

select  sum(case when typeid = 1  then 1 else 0 end) single_total
	, sum(case when typeid = 1 and statusid = 2  then 1 else 0 end) single_completed
	, sum(case when typeid = 1 and statusid = 3  then 1 else 0 end) single_failed
	, sum(case when typeid = 10 then 1 else 0 end) parlay_total
	, sum(case when typeid = 10 and statusid = 2  then 1 else 0 end) parlay_completed
	, sum(case when typeid = 10 and statusid = 3  then 1 else 0 end) parlay_failed 	
from AutoRefundResult   with(nolock)


select Remark 'single_reason', count(1) cnt
from AutoRefundResult  with(nolock)
where typeid = 1
group by Remark



select substring(Remark,0, 50) 'parlay_reason', count(1) cnt
from AutoRefundResult  with(nolock)
where typeid = 10
group by substring(Remark,0, 50) 