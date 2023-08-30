/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230706@Louisa
	Task: Integration -Leap Gaming - remove bettype 5305 due to not support [Redmine: #189854]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

BEGIN

	DELETE sp 
	FROM SettlementSpecialBettypeProfile sp
	WHERE sp.SportType = 178 
			AND sp.BetType = 5305

END
GO