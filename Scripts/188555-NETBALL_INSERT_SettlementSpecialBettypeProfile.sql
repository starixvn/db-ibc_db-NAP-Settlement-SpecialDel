/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230524@Louisa
	Task: Integration - NETBALL - Offer Moneyline Bet Type [Redmine: #188555]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM SettlementSpecialBettypeProfile sp WITH(NOLOCK) WHERE sp.SportType = 32 AND sp.bettype = 20 )
BEGIN
	INSERT INTO SettlementSpecialBettypeProfile
	(	pfID	
		,BetType	
		,SportType	
		,BetID	
		,ResourceID	
		,SettleType	
		,GroupType	
		,OrdNo	
		,RoundID	
		,OddsType
	)
	SELECT	20	
			,20	
			,32	
			,0	
			,'00'	
			,'MNL'	
			,'FT'	
			,99	
			,0	
			,NULL

END
GO
