/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220811@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-bodb02

	 Revisions:
		- 20220811@Victoria: TRUNCATE for the following tables [Redmineid:#176350]
									1.  dbo.BalancePendingProcessed
									2.  dbo.BalCasinoPendingProcessed
									3.  dbo.BalOthersPendingProcessed
									4.  dbo.BalSportsPendingProcessed
									5.  dbo.bettranssum
									6.  dbo.CustLimitBet_789
									7.  dbo.CustLimitBet_MBC
									8.  dbo.CustLimitBetHistory_789
									9.  dbo.CustLimitBetHistory_MBC
									10. dbo.sum_winloss
									11. dbo.TicketVoiding_AutoVoidRequest_Queue
									12. dbo.TicketVoiding_Queue
*/

	USE bodb02
	GO

	TRUNCATE TABLE [dbo].[BalancePendingProcessed]
	TRUNCATE TABLE [dbo].[BalCasinoPendingProcessed]
	TRUNCATE TABLE [dbo].[BalOthersPendingProcessed]
	TRUNCATE TABLE [dbo].[BalSportsPendingProcessed]
	TRUNCATE TABLE [dbo].[bettranssum]
	TRUNCATE TABLE [dbo].[CustLimitBet_789]
	TRUNCATE TABLE [dbo].[CustLimitBet_MBC]
	TRUNCATE TABLE [dbo].[CustLimitBetHistory_789]
	TRUNCATE TABLE [dbo].[CustLimitBetHistory_MBC]
	TRUNCATE TABLE [dbo].[sum_winloss]
	TRUNCATE TABLE [dbo].[TicketVoiding_AutoVoidRequest_Queue]
	TRUNCATE TABLE [dbo].[TicketVoiding_Queue]
