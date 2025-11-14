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
UPDATE dbo.RepInfo WITH(ROWLOCK, UPDLOCK) SET active = 0 
WHERE [name] = 'SettlementResultHistory_TicketDetails'
	AND [group] IN (3,4,5)
GO

DROP PROC Repl_PutSettlementResultHistory_TicketDetails
GO

DROP TYPE TVP_ReplSettlementResultHistory
GO

CREATE TYPE [dbo].[TVP_ReplSettlementResultHistory_TicketDetails] AS TABLE(
	 ID					BIGINT
	,SessionID			VARCHAR(50) 
	,SeqNo				SMALLINT	
	,Transid			BIGINT	    
	,ExtraInfo_Before	VARCHAR(MAX)
	,ExtraInfo_After	VARCHAR(MAX)
	,RepUpdateTime		DATETIME2(7)	
	,IsDeleted			BIT		
	,_FetchedTime		DATETIME2(7)	
)
GO

GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplSettlementResultHistory_TicketDetails] TO [repl_ap] AS [dbo]
GO