/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250714@July
	Task: Phase 2 - Support SMP, Parlay Tickets (include single ticket of Parlay Lucky) - [Redmine: #232605]
	DB:DBSIC-bodb02
*/
USE bodb02
GO
SELECT COUNT(1) FROM CustWinLimitBet_History WITH (NOLOCK) WHERE actiontype = 100 AND bettype IS NULL

WHILE (1 = 1) 
BEGIN 
	
	UPDATE TOP(2000) CustWinLimitBet_History WITH(ROWLOCK,UPDLOCK)
	SET sporttype = 0, bettype = 0 
	WHERE actiontype = 100 AND bettype IS NULL

	IF @@ROWCOUNT = 0 BREAK;
END


