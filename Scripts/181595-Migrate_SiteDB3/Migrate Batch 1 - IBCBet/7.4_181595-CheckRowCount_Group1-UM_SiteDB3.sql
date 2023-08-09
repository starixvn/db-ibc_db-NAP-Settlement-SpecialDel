/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 - Batch 1 - before UM Settlement [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: check data consistency - UM - Group 1 (8 tables balance)  [Redmineid:#181595]

		8 tables: 
			BalDebitCasino 	,BalDebitOthers  ,BalDebitSports  ,BalDebitTransfer 
			BalCreditCasino ,BalCreditOthers ,BalCreditSports ,BalCreditTransfer 	

*/

use CustDB
go

drop table if exists #t1
drop table if exists #t2

create table #t1 (cnt int, tableName varchar(200))
create table #t2 (cnt int, tableName varchar(200))

drop table if exists #__custidList
create table #__custidList(custid int primary key)

insert into #__custidList(custid)
select distinct custid
from dbo.Customer c with (nolock)
	inner join dbo.Site s with(nolock) on c.Site = s.Site
where s.SiteLabel = 'IBC' 

declare @__sqlCmd nvarchar(max)
set @__sqlCmd = '
	select count(1) cnt, ''BalDebitCasino'' tableName 
	from bodb02.dbo.BalDebitCasino b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalDebitOthers'' tableName 
	from bodb02.dbo.BalDebitOthers b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalDebitSports'' tableName 
	from bodb02.dbo.BalDebitSports b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalDebitTransfer'' tableName 
	from bodb02.dbo.BalDebitTransfer b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalCreditCasino'' tableName 
	from bodb02.dbo.BalCreditCasino b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalCreditOthers'' tableName 
	from bodb02.dbo.BalCreditOthers b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalCreditSports'' tableName 
	from bodb02.dbo.BalCreditSports b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid

	union all
	select count(1) cnt, ''BalCreditTransfer'' tableName 
	from bodb02.dbo.BalCreditTransfer b with(nolock)
	inner join SiteDBtmp.dbo.CustSiteDB3_20230626 c on c.custid = b.custid
'

--target
insert into #t1(cnt, tableName)
exec DBCTG.bodb02.sys.sp_executesql @__sqlCmd
--source
insert into #t2(cnt, tableName)
select count(1) cnt, 'BalDebitCasino' tableName 
	from bodb02.dbo.BalDebitCasino b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalDebitOthers' tableName 
	from bodb02.dbo.BalDebitOthers b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalDebitSports' tableName 
	from bodb02.dbo.BalDebitSports b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalDebitTransfer' tableName 
	from bodb02.dbo.BalDebitTransfer b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalCreditCasino' tableName 
	from bodb02.dbo.BalCreditCasino b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalCreditOthers' tableName 
	from bodb02.dbo.BalCreditOthers b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalCreditSports' tableName 
	from bodb02.dbo.BalCreditSports b with(nolock)
	inner join #__custidList c on c.custid = b.custid

	union all
	select count(1) cnt, 'BalCreditTransfer' tableName 
	from bodb02.dbo.BalCreditTransfer b with(nolock)
	inner join #__custidList c on c.custid = b.custid

select * from #t1 order by tableName
select * from #t2 order by tableName

select * from #t1 t1
full outer join #t2 t2 on t1.tableName = t2.tableName
where isnull(t1.cnt, 0) <> isnull(t2.cnt, 0)

