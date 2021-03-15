/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210312@Louisa
    Task: 20210312@Louisa: Cricket AIO [Redmine:#148870]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20210312@Louisa: Generate ResultDetailOS for Cricket [Redmine:#148870]
*/

USE bodb02
GO

BEGIN

	INSERT INTO  dbo.ResultDetailOS (
			MatchID				
			,ResourceID			
			,HomeValue			
			,AwayValue			
			,ResultStatusID		
			,SettlementStatusID	
			,CreateBy			
			,CreateDate			
			,LastModifyBy		
			,LastModifyDate	
			)
	SELECT m.matchid
			,'00'		
			,m.finalhomescore			
			,m.finalawayscore			
			,CASE WHEN m.eventstatus = 'completed' THEN 5 --manually settled
					ELSE 1 -- running
				END AS ResultStatusID
				
			,CASE WHEN m.eventstatus = 'completed' THEN 
													CASE WHEN ISNULL(m.betstatus,'') LIKE '%Refund%' THEN 1 --Refund All
														ELSE 4 -- Completed -Cal FT
													END
					ELSE 0 
				END AS SettlementStatusID	
			,8			
			,GETDATE()			
			,8	
			,GETDATE()			
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.sporttype = 50

END