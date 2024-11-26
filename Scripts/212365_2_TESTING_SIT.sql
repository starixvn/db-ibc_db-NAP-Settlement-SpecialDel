/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241118@Louisa
	Task: InitData for SIT Testing  - Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/


---- RUN THIS SCRIPT ON SIT ONLY
 
USE bodb02
GO 

 --select *    FROM ResultDetailOS with(nolock)
--WHERE MatchID IN ( 65964327, 65964348, 65964361, 65964578, 65964579, 65964628 ) 

DELETE FROM ResultDetailOS 
WHERE MatchID IN ( 65964327, 65964348, 65964361, 65964578, 65964579, 65964628 ) 
	AND ResourceID = 'EI'
	
UPDATE ResultDetailOS WITH(ROWLOCK, UPDLOCK)
SET SettlementStatusID = 1, HomeValue = NULL, AwayValue = NULL, ResultSetting = 0
WHERE Matchid IN ( 65964327, 65964348, 65964361, 65964578, 65964579,  65964628)
	AND ResourceID IN ( '0106',	'0107','0108','0109'  )

UPDATE ResultDetailOS WITH(ROWLOCK, UPDLOCK)
SET OtherInfo = 'A'
WHERE Matchid = 65964578
	AND ResourceID = '0105' 

	
UPDATE ResultDetailOS WITH(ROWLOCK, UPDLOCK)
SET HomeValue = '18', AwayValue = '3'
WHERE Matchid IN (65964578, 65964579)
	AND ResourceID = '00' 

UPDATE ResultDetailOS WITH(ROWLOCK, UPDLOCK)
SET OtherInfo = NULL
WHERE Matchid IN (65964579, 65964628)
	AND ResourceID = '0105' 

UPDATE ResultDetailOS WITH(ROWLOCK, UPDLOCK)
SET HomeValue = '20', AwayValue = '3'
WHERE Matchid IN (65964628)
	AND ResourceID = '00' 
