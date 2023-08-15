-- Group 3 - Before UM
/*
	Run on SiteDB1
	1) Bettrans14	
	2) BettransInfo14	
	3) bettransm14	
	4) BettransLC14	
	5) BettransRnG14	
	6) bettransG14	
	7) Translog14	
	8) Task_bettrans14_IP2Country	
	9) Task_bettransRNG14_IP2Country	
	10) Task_bettransLC14_IP2Country	
	11) balanceTable	
	12) balanceTable_tmp	
	13) BalanceTable_tmp_cal	
	14) sum_winloss	

*/
--check data
drop table if exists #t1
drop table if exists #t2

create table #t1 (cnt int, tableName varchar(200))
create table #t2 (cnt int, tableName varchar(200))

drop table if exists #__custidList
create table #__custidList(custid int primary key)

insert into #__custidList(custid)
select distinct custid
from CustDB.dbo.Customer c with (nolock)
	inner join CustDB.dbo.Site s with(nolock) on c.Site = s.Site
where s.SiteLabel = 'IBC' 

declare @__sqlCmd nvarchar(max)
set @__sqlCmd = '
	select count(1) cnt, ''bettrans14'' tableName 
	from bodb02.dbo.bettrans14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''bettransInfo14'' tableName 
	from bodb02.dbo.bettransInfo14 b with(nolock)
	inner join bodb02.dbo.bettrans14 bb with(nolock) on b.transid = bb.transid
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = bb.custid

	union all
	select count(1) cnt, ''bettransm14'' tableName 
	from bodb02.dbo.bettransm14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''bettransLC14'' tableName 
	from bodb02.dbo.bettransLC14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''bettransRnG14'' tableName 
	from bodb02.dbo.bettransRnG14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''bettransG14'' tableName 
	from bodb02.dbo.bettransG14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''translog14'' tableName 
	from bodb02.dbo.translog14 b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''Task_bettrans14_IP2Country'' tableName 
	from bodb02.dbo.Task_bettrans14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettrans14 bb with(nolock) on b.transid = bb.transid
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = bb.custid

	union all
	select count(1) cnt, ''Task_bettransRNG14_IP2Country'' tableName 
	from bodb02.dbo.Task_bettransRNG14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettransRnG14 bb with(nolock) on b.transid = bb.transid
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = bb.custid

	union all
	select count(1) cnt, ''Task_bettransLC14_IP2Country'' tableName 
	from bodb02.dbo.Task_bettransLC14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettransLC14 bb with(nolock) on b.transid = bb.transid
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = bb.custid

	union all
	select count(1) cnt, ''balanceTable'' tableName 
	from bodb02.dbo.balanceTable b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''balanceTable_tmp'' tableName 
	from bodb02.dbo.balanceTable_tmp b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalanceTable_tmp_cal'' tableName 
	from bodb02.dbo.BalanceTable_tmp_cal b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''sum_winloss'' tableName 
	from bodb02.dbo.sum_winloss b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid
'

--target
insert into #t1(cnt, tableName)
exec DBCTG.bodb02.sys.sp_executesql @__sqlCmd
--source
insert into #t2(cnt, tableName)
select count(1) cnt, 'bettrans14' tableName 
	from bodb02.dbo.bettrans14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'bettransInfo14' tableName 
	from bodb02.dbo.bettransInfo14 b with(nolock)
	inner join bodb02.dbo.bettrans14 bb with(nolock) on b.transid = bb.transid
	inner join #__custidList c on c.custid = bb.custid

	union all
	select count(1) cnt, 'bettransm14' tableName 
	from bodb02.dbo.bettransm14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'bettransLC14' tableName 
	from bodb02.dbo.bettransLC14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'bettransRnG14' tableName 
	from bodb02.dbo.bettransRnG14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'bettransG14' tableName 
	from bodb02.dbo.bettransG14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'translog14' tableName 
	from bodb02.dbo.translog14 b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'Task_bettrans14_IP2Country' tableName 
	from bodb02.dbo.Task_bettrans14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettrans14 bb with(nolock) on b.transid = bb.transid
	inner join #__custidList c on c.custid = bb.custid

	union all
	select count(1) cnt, 'Task_bettransRNG14_IP2Country' tableName 
	from bodb02.dbo.Task_bettransRNG14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettransRnG14 bb with(nolock) on b.transid = bb.transid
	inner join #__custidList c on c.custid = bb.custid

	union all
	select count(1) cnt, 'Task_bettransLC14_IP2Country' tableName 
	from bodb02.dbo.Task_bettransLC14_IP2Country b with(nolock)
	inner join bodb02.dbo.bettransLC14 bb with(nolock) on b.transid = bb.transid
	inner join #__custidList c on c.custid = bb.custid

	union all
	select count(1) cnt, 'balanceTable' tableName 
	from bodb02.dbo.balanceTable b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'balanceTable_tmp' tableName 
	from bodb02.dbo.balanceTable_tmp b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalanceTable_tmp_cal' tableName 
	from bodb02.dbo.BalanceTable_tmp_cal b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'sum_winloss' tableName 
	from bodb02.dbo.sum_winloss b with(nolock)
	inner join #__custidList c on c.custid = b.custid

select * from #t1 order by tableName
select * from #t2 order by tableName

select * from #t1 t1
full outer join #t2 t2 on t1.tableName = t2.tableName
where isnull(t1.cnt, 0) <> isnull(t2.cnt, 0)

