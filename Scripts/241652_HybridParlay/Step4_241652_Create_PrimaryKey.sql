/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/ 
/*	
	Created by: 20251113@Louisa
	DB: DBSIG-bodb02
	
	Revisions: 
		- 20251113@Louisa: Basketball Hybrid Parlay [Redmine: #241652]
*/
USE bodb02
GO

ALTER TABLE dbo.SettlementResultHistory_TicketDetails DROP CONSTRAINT PK_SettlementResultHistory_TicketDetails
GO 

ALTER TABLE SettlementResultHistory_TicketDetails ADD ID BIGINT IDENTITY(1,1)

ALTER TABLE dbo.SettlementResultHistory_TicketDetails ADD CONSTRAINT PK_SettlementResultHistory_TicketDetails PRIMARY KEY NONCLUSTERED (ID ASC)
GO

CREATE CLUSTERED INDEX IDX_SettlementResultHistory_TicketDetails_SessionID_Transid ON SettlementResultHistory_TicketDetails (SessionID, Transid)
