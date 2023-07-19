/*<info serverAlias="DBTXN-bodb02"></info>*/
--dbtrans
USE bodb02
go

sp_rename 'NetPositionQueue','del_NetPositionQueue'
GO