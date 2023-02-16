/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20230214@Max
    Task: Reset Turnover custid 23118252 - [Redmine: #00000]

	DB: DBCTG/bodb02 
*/
USE [bodb02]
GO

UPDATE m
  SET AccumTurnover = 0, ModifiedDate = GETDATE()
FROM CustLimitBet_MBC m WITH (ROWLOCK,UPDLOCK)
WHERE custid = 23118252  AND EventTypeID = 4 AND matchid = 29

    
