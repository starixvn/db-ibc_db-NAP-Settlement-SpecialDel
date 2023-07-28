/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
USE [bodb_Archive]
GO
SP_RENAME 'settlementNG2_message_bk', 'del_settlementNG2_message_bk'
GO
SP_RENAME 'bettrans_Staging_bk', 'del_bettrans_Staging_bk'
GO

