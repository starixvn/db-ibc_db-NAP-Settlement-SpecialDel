/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/    
/*
    Created: 20251009@Max
	Task: Script insert setting - Add new sports "eVolleyball" for Virtual Sport6-Betby [Redmine: #240731]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

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
	VALUES 
	/*Existting bettypes*/
		(501, 13002, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
	,	(10	, 13003, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
	,	(3	, 13004, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
	,	(401, 13005, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
	,	(402, 13006, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
	,	(2	, 13019, 114, 0, '00', 'MNL', 'FT', 99, 0, 1)
END
GO

 
    
