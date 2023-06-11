/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
 
-- run only on SITEDB1
use bodb02
go
-- bettrans
update bettrans with(rowlock, updlock)
	set RepUpdateTime = SYSDATETIME()
where transid in (127787676630777908,
	127788737487699978,
	127788767552471040,
	127788767552471090) 
GO
