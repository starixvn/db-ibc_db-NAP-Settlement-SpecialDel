/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created by: 20251113@Louisa
	DB: DBSIG-bodb02
	
	Revisions: 
		- 20251113@Louisa: Basketball Hybrid Parlay [Redmine: #241652]
*/
USE bodb02
GO

---off sync data
UPDATE dbo.RepInfo WITH(ROWLOCK, UPDLOCK) SET active = 1 
WHERE [name] = 'SettlementResultHistory_TicketDetails'
	AND [group] IN (3,4,5)
GO