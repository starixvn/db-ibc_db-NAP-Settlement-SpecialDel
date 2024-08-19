/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
USE bodb02
GO

/*
	select (
		select pfid, bettype, sporttype, betid, oddstype, resourceid, settletype, grouptype, ordno, roundid, refresourceid, sdtpfid, sdtresourceid, determinedtype, specialtype
		from SettlementSpecialBettypeProfile 
		where sporttype = 8 and bettype in (8828,8829,8830,8831,8832,8834,8833,8835)
		order by bettype
		for json auto
	)

*/


declare @json varchar(max) = '[{"pfid":20,"bettype":8828,"sporttype":8,"betid":0,"resourceid":"00","settletype":"MNL","grouptype":"FT","ordno":99,"roundid":"0"},{"pfid":10,"bettype":8829,"sporttype":8,"betid":0,"resourceid":"00","settletype":"MNL","grouptype":"FT","ordno":99,"roundid":"0"},{"pfid":3,"bettype":8830,"sporttype":8,"betid":0,"resourceid":"00","settletype":"MNL","grouptype":"FT","ordno":99,"roundid":"0"},{"pfid":8831,"bettype":8831,"sporttype":8,"betid":0,"oddstype":1,"resourceid":"00","settletype":"MNL","grouptype":"FT","ordno":99,"roundid":"0"},{"pfid":20,"bettype":8832,"sporttype":8,"betid":0,"resourceid":"8832","settletype":"MNL","grouptype":"SP","ordno":3,"roundid":"803","refresourceid":"0103","specialtype":1},{"pfid":5,"bettype":8833,"sporttype":8,"betid":0,"oddstype":1,"resourceid":"8833","settletype":"MNL","grouptype":"SP","ordno":4,"roundid":"804","refresourceid":"0104","specialtype":1},{"pfid":8831,"bettype":8834,"sporttype":8,"betid":0,"oddstype":1,"resourceid":"8832","settletype":"MNL","grouptype":"SP","ordno":3,"roundid":"803","refresourceid":"0103","specialtype":1},{"pfid":8831,"bettype":8835,"sporttype":8,"betid":0,"oddstype":1,"resourceid":"8833","settletype":"MNL","grouptype":"SP","ordno":4,"roundid":"804","refresourceid":"0104","specialtype":1}]'

declare @tmpSettlementSpecialBettypeProfile table (pfid smallint
	,bettype smallint
	,sporttype smallint
	, oddstype int
	,betid bigint
	,resourceid varchar(20)
	,settletype char(3)
	,grouptype char(3)
	,ordno smallint
	,roundid varchar(10)
	,refresourceid varchar(20)
	,sdtpfid int
	,sdtresourceid varchar(20)
	,determinedtype bigint
	,specialtype tinyint
)

Insert into @tmpSettlementSpecialBettypeProfile (pfid, bettype, sporttype, oddstype, betid, resourceid, settletype, grouptype, ordno, roundid, refresourceid, sdtpfid, sdtresourceid, determinedtype, specialtype)
select pfid, bettype, sporttype, oddstype, betid, resourceid, settletype, grouptype, ordno, roundid, refresourceid, sdtpfid, sdtresourceid, determinedtype, specialtype
from openjson(@json)
with(
	pfid smallint
	,bettype smallint
	,sporttype smallint
	,oddstype int
	,betid bigint
	,resourceid varchar(20)
	,settletype char(3)
	,grouptype char(3)
	,ordno smallint
	,roundid varchar(10)
	,refresourceid varchar(20)
	,sdtpfid int
	,sdtresourceid varchar(20)
	,determinedtype bigint
	,specialtype tinyint
)


insert into SettlementSpecialBettypeProfile(pfid, bettype, sporttype, oddstype, betid, resourceid, settletype, grouptype, ordno, roundid, refresourceid, sdtpfid, sdtresourceid, determinedtype, SpecialType)
select pfid, bettype, sporttype, oddstype, betid, resourceid, settletype, grouptype, ordno, roundid, refresourceid, sdtpfid, sdtresourceid, determinedtype, specialtype
from @tmpSettlementSpecialBettypeProfile t
where not exists (select top 1 1 from SettlementSpecialBettypeProfile s with(nolock) where sporttype = 8 and bettype = t.bettype)

update s with(rowlock, updlock)
	set resourceid = t.resourceid
		,betid = t.betid
		,refresourceid = t.refresourceid
		,sdtpfid = t.sdtpfid
		, sdtresourceid = t.sdtresourceid
		, determinedtype = t.determinedtype
		, oddstype = t.oddstype
		, SettleType = t.settletype
		, OrdNo = t.ordno
		, SpecialType = t.specialtype
		, roundid = t.roundid
from SettlementSpecialBettypeProfile s
	inner join @tmpSettlementSpecialBettypeProfile t
		on s.bettype = t.bettype
		and s.betid = t.betid
where s.bettype in (8828,8829,8830,8831,8832,8834,8833,8835)



    
