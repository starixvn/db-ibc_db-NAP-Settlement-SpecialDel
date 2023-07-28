/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
SP_RENAME 'settlementNG2_message', 'del_settlementNG2_message'
GO
SP_RENAME 'bettrans_staging', 'del_bettrans_staging'
GO