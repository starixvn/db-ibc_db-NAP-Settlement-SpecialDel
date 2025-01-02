/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241118@Louisa
	Task: InitData for SIT Testing  - Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/


---- RUN THIS SCRIPT ON SIT ONLY
 
USE bodb02
GO 
 

UPDATE match WITH(ROWLOCK, UPDLOCK)
SET eventstatus = 'Completed'
WHERE MatchID IN ( 65964327, 65964348, 65964361, 65964578, 65964579, 65964628 )


UPDATE match WITH(ROWLOCK, UPDLOCK)
SET betstatus = 'Refund'
WHERE MatchID IN (   65964578, 65964579, 65964628 )


UPDATE match WITH(ROWLOCK, UPDLOCK)
SET finalhomescore = 18, finalawayscore = 3
WHERE MatchID IN ( 65964327 ,65964579,65964348,65964578 )
 
 
 UPDATE match WITH(ROWLOCK, UPDLOCK)
SET finalhomescore = 28, finalawayscore = 3
WHERE MatchID IN ( 65964361, 65964628 )

 