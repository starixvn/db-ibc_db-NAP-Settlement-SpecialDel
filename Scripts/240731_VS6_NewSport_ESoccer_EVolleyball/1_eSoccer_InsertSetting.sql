/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/    
/*
    Created: 20251007@Max
	Task: Script insert setting - Add new sports "eSoccer" for Virtual Sport6-Betby [Redmine: #240731]
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
		,RefResourceId
	)  
	VALUES 
	/*Existting bettypes*/
		(5	, 13000, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(24	, 13001, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(501, 13002, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(10	, 13003, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(3	, 13004, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(401, 13005, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(402, 13006, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(2	, 13019, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(5	, 13012, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(10	, 13014, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(3	, 13015, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(401, 13016, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(402, 13017, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(2	, 13018, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	/*New bettypes*/
	,	(25	, 13020, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(145, 13021, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(170, 13022, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(16	, 13023, 116, 0, '417'	, 'MNL', 'FT', 99, 0, 1, '00')
	,	(418, 13024, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(143, 13025, 116, 0, '144'	, 'MNL', 'FT', 99, 0, 1, '00')
	,	(24	, 13026, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(145, 13027, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
	,	(16	, 13028, 116, 0, '456'	, 'MNL', 'HT', 99, 0, 1, '01')
	,	(143, 13029, 116, 0, '143'	, 'MNL', 'HT', 99, 0, 1, '01')
	,	(450, 13030, 116, 0, '450'	, 'MNL', 'FT', 99, 0, 1, '00')
	,	(451, 13031, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(449, 13032, 116, 0, '449'	, 'MNL', 'FT', 99, 0, 1, '00')
	,	(644, 13033, 116, 0, '00'	, 'MNL', 'FT', 99, 0, 1, NULL)
	,	(644, 13034, 116, 0, '01'	, 'MNL', 'HT', 99, 0, 1, NULL)
END
GO

 
    
