/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket - create new index
	DB: DB061/bodb02
*/

USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_zzzbettransm_TransId] ON [dbo].[zzzbettransm]
(
	[transid] ASC
)ON [BettransM14_table]
GO