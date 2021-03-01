/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*	Creator: Kathy
	Date: 20210218
	Task: Move ticket of cricket - create new index
	DB: DBTXN/bodb02
*/

USE [bodb02]
GO
CREATE NONCLUSTERED INDEX [IX_zzzbettrans_TransId] ON [dbo].[zzzbettrans]
(
	[transid] ASC
)ON [Others_table]
GO


CREATE NONCLUSTERED INDEX [IX_zzzbettransm_TransId] ON [dbo].[zzzbettransm]
(
	[transid] ASC
)ON [BettransM14_table]
GO