/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
/*	
	Created by: 20251113@Louisa
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251113@Louisa: Basketball Hybrid Parlay [Redmine: #241652]
*/

ALTER TABLE dbo.SettlementResultHistory_TicketDetails DROP CONSTRAINT PK_SettlementResultHistory_TicketDetails
GO 
ALTER TABLE dbo.SettlementResultHistory_TicketDetails ADD CONSTRAINT PK_SettlementResultHistory_TicketDetails PRIMARY KEY (SessionID, Transid, SeqNo)
GO

