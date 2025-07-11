-----------Part 3. Sync service (settlement-TVS): Check settlement Queue, settlement sync logs, balance pending, ...------------
----------------1.1 at sitedb
/*
DBSITEC1.bodb02
DBSITEC2.bodb02
DBSITEC3.bodb02
*/
begin --1. check settlement Queue
	select 'Single_Calculate_Queue' as 'task', *
	from dbo.Single_Calculate_Queue with(nolock) where IsCalculating < 2

	select 'Parlay_Calculate_Queue' as 'task', *
	from dbo.Parlay_Calculate_Queue with(nolock) where IsCalculating < 2

	select 'Single_Calculate_Queue_VS' as 'task', *
	from dbo.Single_Calculate_Queue_VS with(nolock) where IsCalculating < 2
	-- queue3 3rd betbuilder
end --check settlement Queue

begin --check sync settlement log
	select top 100 'SiteDB_SettlementService_CalculationLog' as 'task', *
	from dbo.SiteDB_SettlementService_CalculationLog l with(nolock)
		left join dbo.SiteDB_SettlementService_LastLog ll with(nolock) on l.LogId = ll.LogId
	where ll.LogId is null or (ll.LogId is not null and ll.StatusId < 2)

	select top 100 'SiteDB_SettlementService_CalculationLog_3rd' as 'task', *
	from dbo.SiteDB_SettlementService_CalculationLog_3rd l with(nolock)
		left join dbo.SiteDB_SettlementService_LastLog_3rd ll with(nolock) on l.LogId = ll.LogId
	where ll.LogId is null or (ll.LogId is not null and ll.StatusId < 2)
end --check sync settlement log


begin --check balance pending
	select 'BalCreditCasinoPending' as 'task', * 
	from dbo.BalCreditCasinoPending with(nolock)
	select 'BalCreditSportsPending' as 'task', * 
	from dbo.BalCreditSportsPending with(nolock)
	select 'BalCreditOthersPending' as 'task', * 
	from dbo.BalCreditOthersPending with(nolock)
	
	select 'BalDebitCasinoPending' as 'task', * 
	from dbo.BalDebitCasinoPending with(nolock)
	select 'BalDebitSportsPending' as 'task', * 
	from dbo.BalDebitSportsPending with(nolock)
	select 'BalDebitOthersPending' as 'task', * 
	from dbo.BalDebitOthersPending with(nolock)

end --check balance pending

begin --check balance pending game
	select 'BalancePendingDebitGame' as 'task', * 
	from dbo.BalancePendingDebitGame with(nolock)
	select 'BalancePendingCreditGame' as 'task', * 
	from dbo.BalancePendingCreditGame with(nolock)

end --check balance pending game

select * 
from sys.dm_broker_activated_tasks with(nolock)
 
----------------Check settlement procssing ---------------------
/*DBSITEC1.bodb02
DBSITEC2.bodb02
DBSITEC3.bodb02
DBTrans.bodb02*/
--ssb v2
declare @__starttime datetime2
select @__starttime = max(starttime) from dbo.SSB_SettlementLogs with(nolock)
waitfor delay '00:00:30:000' -- waifor 30s
select top 10 * 
from dbo.SSB_SettlementLogs with(nolock) where StartTime > @__starttime
order by StartTime desc
go
----------------1.2 at subdb - Check settlement processing
/*
DB061.bodb02
DB062.bodb02
DBTP.bodb02
DB052.bodb02
DB053.bodb02
DB054.bodb02
DB055.bodb02
*/
select * 
from sys.dm_broker_activated_tasks with(nolock)
--ssb v2
declare @__starttime datetime2
select @__starttime = max(starttime) from dbo.SSB_SettlementLogs with(nolock)
waitfor delay '00:00:30:000' -- waifor 30s
select top 10 * 
from dbo.SSB_SettlementLogs with(nolock) where StartTime > @__starttime
order by StartTime desc
go
--ssb v1
declare @__starttime datetime
select @__starttime = max(creationTime) from sb.CalculationLogs with(nolock)
waitfor delay '00:00:30:000' -- waifor 30s
select top 10 * 
from sb.CalculationLogs with(nolock) where creationTime > @__starttime
order by creationTime desc
----------------1.1 Check more for sync service got isssue
----*******************************************
---STEP 1. CHECK DATA ON SiteDB
--- run on Sitedb /bodb02
----tickets
use bodb02
go
select matchid, transid, transdate, settlementtime, custid, creator, status, repupdatetime, repdstupdatetime, fcupdatetime
		, status, sitedbgroupid, @@servername as ServerName
from bettrans b with(nolock) 
where transid in
(
167012741070979110
)
order by matchid, transid

---table sync service
SELECT top 10 l.LogId	,l.matchid, tmp.transid	,l.TableName,l.LogDate,l.SessionId,l.IsParallel ,l.FunctionName, l.Action, l.SettlementAction, l.TicketType																				
		, tmp.*
		, l.TransInfoJson	
FROM SiteDB_SettlementService_CalculationLog l WITH (NOLOCK)
	CROSS APPLY (	SELECT t TransID, m modds,o odds,os oddsspread,statuswl  statuswinlost,st SettlementTime
						,w WinLost, aw aWinLost, mw mWinLost, sw sWinLost, pc PlayerComm, c Comm, ac aComm, sc sComm, s Status, sid StatusID, r ruben
						,wld winlostdate
						,ex extrainfo 
						,bef_w bef_winlost 
						,bef_sid bef_statusid 
						,bt bettype 
						,bi betid 
						,rf refno 

					FROM OPENJSON(DECOMPRESS(l.TransinfoJson) )
						WITH (
						t   BIGINT
						,m  VARCHAR(11)
						,o  SMALLMONEY	
						,os  VARCHAR(20)
						,statuswl  VARCHAR(1)
						,st  DATETIME
						,w  MONEY
						,aw  MONEY
						,mw  MONEY
						,sw  MONEY
						,pc  MONEY
						,c  MONEY
						,ac  MONEY
						,sc  MONEY
						,s  NVARCHAR(10)
						,sid  TINYINT
						,r  TINYINT
						,wld DATETIME
						,ex varchar(1000)
						,bef_w MONEY
						,bef_sid TINYINT
						,bt SMALLINT
						,bi bigint
						,rf bigint
					)
					) as tmp

where matchid = 72775374
	AND tmp.transid IN 
	(
	167012741070979110
	)
order by matchid, transid,logdate

select top 10 Logid, StatusId 
from SiteDB_SettlementService_LastLog with (nolock)
where logid = xxxx
----STEP 2. Check sync service at DBTRANS/bodb02
--Queue at DBTRANS sitedb1/2/3_bet_settle_queue
--SP: NAP_SettlementService_CalculationLogIns
use bodb02
go
select top 10 * from SiteDB_SettlementService_CalculationLog_History with (nolock)
where logid in (21186645,21220417)

SELECT top 10 
		REPLACE( SUBSTRING (MessageBody, charindex('@TransInfoJson=',MessageBody)+15, len(MessageBody)) , '''', '')     as TransInfoJson
		, *
FROM SSB_SettlementLogs l WITH(NOLOCK) 
WHERE MessageType like '%sitedb3_bet_settle_msg_type_0_%'
	AND SessionId = xxxx -- sessionid from step 1

---------Part 7. Void service- Check TVS processing -----------------
select top 10 * from TicketVoiding_Queue with (nolock)
where StatusId = 1
order by QueueId desc
select top 10 * from TicketVoiding_AutoVoidQueue with (nolock)
where StatusId = 1
order by QueueId desc
--Check only central (after void service)
--DBCTG
SELECT * FROM dbo.Ticketvoiding_VoidBetAutomation_Service (NOLOCK) WHERE StatusId = 1
SELECT * FROM dbo.TicketVoiding_Letstalk (NOLOCK) 
WHERE StatusId = 1 AND createddate >= DATEADD(DAY, -2, CAST(GETDATE() AS DATE))

-----------Part 4. Balance Record -------------------
---DB05/DB05BK1
USE bodb02
GO
----Service pull data BalanceTrigger, expect Vvalue will be changed continously for BT_SiteDB0X_Sync
SELECT * FROM [bodb02].[dbo].SystemSettings WITH (NOLOCK) WHERE VName 
IN ( 
    'BT_SiteDB01_ServiceStatus','BT_SiteDB01_InsStatus', 'BT_SiteDB01_Sync',
    'BT_SiteDB02_ServiceStatus','BT_SiteDB02_InsStatus', 'BT_SiteDB02_Sync',
    'BT_SiteDB03_ServiceStatus','BT_SiteDB03_InsStatus', 'BT_SiteDB03_Sync'
    )
/*
   %ServiceStatus = 1: running
   %InsStatus = 2: insert done
   %_Sync =  X  : last row in sitedbX BalanceTrigger

*/

select count(1) from BalanceTrigger  WITH(NOLOCK)
select count(1) from BalanceTrigger_ProcessData WITH(NOLOCK)

select * from BalanceRecord.dbo.balancerecord_bk with (nolock)
where custid = 238246021 and transid = 409784410263519232
select * from dbo.balancerecord with (nolock)
where custid = 238246021 and transid = 409784410263519232
-- SITEDB:
select * from bodb02.dbo.balancetrigger with (nolock)
where custid = 238246021 and transid = 409784410263519232

-----------Part 5. CWL Service to pull data to table WinLimit_CustWinlostGame --------------------------
--DBCUST/CUSTDB
---> Expect: new RepUpdateTime will be changed
declare @date datetime
set @date = convert(date, getdate())
SELECT TOP 10 * FROM WinLimit_CustWinlostGame WITH (NOLOCK)
WHERE  WinlostDate = @date 
ORDER BY RepUpdateTime DESC

-----------Part 10. TO Control --------------------------
---Flow Information
-- DBAGE: Trigger bettrans --> Insert TOControl_Transition
-- DBCUST-CustDB: table TOControl_Setting 
--TASK_TOControl_MergeTransition 
--> EXEC DBTOC.bodb02.dbo.TASK_TOControl_GetTransition @RowId = @__lastRowId
    /*
	DECLARE @__lastRowId BIGINT, @__maxRowId BIGINT
	SELECT @__lastRowId = CONVERT(BIGINT, VValue)
	FROM dbo.TOConTrol_GlobalVariables WITH (ROWLOCK)
	WHERE VName = 'MaxID'
	*/
--DBAGE/bodb02
--expect sValue will be changed
SELECT TOP 10 *
FROM dbo.TOControl_Tickets_Setting WITH(NOLOCK)
--Job name: bodb02: SSB - TO Control -  Get tickets
--> expect max(id) will be changed
SELECT max(id)  FROM TOControl_Transition with (nolock)
SELECT top 10 *  FROM TOControl_Transition with (nolock)
order by CreatedDate desc
--DBCUST/CUSTDB
SELECT top 10 * FROM TOControl_Setting WITH (NOLOCK)
WHERE  matchid =xxx and custid = xxxx 
ORDER BY ModifiedDate DESC
