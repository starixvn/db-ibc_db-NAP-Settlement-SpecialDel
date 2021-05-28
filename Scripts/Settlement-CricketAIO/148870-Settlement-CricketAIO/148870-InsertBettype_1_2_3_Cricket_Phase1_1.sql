/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210408@Louisa
    Task: 20210408@Louisa: Cricket AIO [Redmine:#148870]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210126@Louisa: Insert SettlementSpecialBettypeProfile for Cricket ( bettype 1,2,3 ) [Redmine:#148870]
*/

USE bodb02
GO



	DECLARE @tblSettlementSpecialBettypeProfile TABLE 
			(pfID			SMALLINT 
			,BetType	SMALLINT 
			,SportType	TINYINT 
			,BetID		BIGINT 
			,ResourceID	VARCHAR(20)
			,SettleType	CHAR(3)
			,GroupType	CHAR(2)
			,OrdNo		SMALLINT
			,RoundID	VARCHAR(10)
			)
	INSERT INTO @tblSettlementSpecialBettypeProfile 
			(	pfID			
				,BetType	
				,SportType	
				,BetID		
				,ResourceID	
				,SettleType	
				,GroupType	
				,OrdNo		
				,RoundID	)
	SELECT * FROM ( VALUES	 (10,	1,	50,	0,	'00',	'MNL',	'FT',	99,	'0' )
							,(2	,	2,	50,	0,	'00',	'MNL',	'FT',	99,	'0' )
							,(3	,	3,	50,	0,	'00',	'MNL',	'FT',	99,	'0' )
					) v (pfID,BetType ,SportType,BetID	 ,ResourceID ,SettleType ,GroupType	 ,OrdNo	,RoundID)
	WHERE NOT EXISTS (SELECT pfid FROM dbo.SettlementSpecialBettypeProfile p WITH(NOLOCK) WHERE p.SportType = 50 AND p.Bettype = v.BetType )


	
	INSERT INTO dbo.SettlementSpecialBettypeProfile
					(pfID
					 ,BetType	
					 ,SportType	
					 ,BetID	
					 ,ResourceID	
					 ,SettleType	
					 ,GroupType	
					 ,OrdNo	
					 ,RoundID	)
	SELECT pfID
			,BetType	
			,SportType	
			,BetID	
			,ResourceID	
			,SettleType	
			,GroupType	
			,OrdNo	
			,RoundID
	FROM @tblSettlementSpecialBettypeProfile 

GO