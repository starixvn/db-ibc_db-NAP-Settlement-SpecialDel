/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220629@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220629@Louisa: Insert settle formular for Volleyball ( 27 bettype ) [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

BEGIN

--SELECT top 1 * FROM dbo.SettlementSpecialBettypeProfile

	DECLARE @tblNumber TABLE ( Id INT, Num VARCHAR(2) )
	DECLARE @tblResourceFormat TABLE ( pfid SMALLINT, bettype SMALLINT, SettleType	VARCHAR(3), OddsType SMALLINT, Prefix VARCHAR(20), X VARCHAR(20) ,Y VARCHAR(20) )	
	DECLARE @tblResource TABLE ( pfid SMALLINT , Ord INT, bettype SMALLINT, betid VARCHAR(5), SettleType VARCHAR(3), OddsType SMALLINT,  Prefix VARCHAR(20), ResourceId VARCHAR(20), RoundID	VARCHAR(10), GroupType CHAR(2) )	
	

	INSERT INTO @tblNumber
	SELECT p.number, CAST(p.number AS VARCHAR(2) )
	FROM master.dbo.spt_values p 
	WHERE p.type  = 'p' and p.number BETWEEN 1 AND 50
	ORDER BY p.number

	INSERT INTO @tblResourceFormat	( pfid, bettype, SettleType, OddsType, Prefix, X, Y )		 	
	----manual FT
			  SELECT 3900,	3900	,'MNL'		,1			,'00'		,''			,''			
	UNION ALL SELECT 9128,	401		,'MNL'		,NULL		,'0100'		,''			,''					
	UNION ALL SELECT 9096,	402		,'MNL'		,NULL		,'0100'		,''			,''					
	UNION ALL SELECT 10,	701		,'MNL'		,NULL		,'00'		,''			,''					
	UNION ALL SELECT 10,	704		,'MNL'		,NULL		,'0100'	,''			,''					
	UNION ALL SELECT 3,		705		,'MNL'		,NULL		,'0100'	,''			,''					
	UNION ALL SELECT 2,		706		,'MNL'		,NULL		,'0100'		,''			,''					
	UNION ALL SELECT 401,	3902	,'MNL'		,NULL		,'3902'		,''			,'' 
	----manual SET
	UNION ALL SELECT 3910,	3910	,'MNL'		,1			,'010'		,'[1-4]'	,''
	UNION ALL SELECT 3910,	3917	,'MNL'		,1			,'010'		,'3'		,''	
	UNION ALL SELECT 3910,	3917	,'MNL'		,1			,'010'		,'5'		,''	
	UNION ALL SELECT 3911,	3911	,'MNL'		,1			,'010'		,'[1-5]'	,''				
	UNION ALL SELECT 3913,	3913	,'MNL'		,1			,'010'		,'[1-5]'	,''				
	UNION ALL SELECT 2,		3906	,'MNL'		,NULL		,'010'		,'[1-5]'	,''				
	UNION ALL SELECT 9128,	3907	,'MNL'		,NULL		,'010'		,'[1-5]'	,''				
	UNION ALL SELECT 9096,	3908	,'MNL'		,NULL		,'010'		,'[1-5]'	,''					
	UNION ALL SELECT 20,	154		,'MNL'		,NULL		,'010'		,'[1-5]'	,''		
	UNION ALL SELECT 10,	219		,'MNL'		,NULL		,'010'		,'[1-5]'	,''		
	UNION ALL SELECT 3,		220		,'MNL'		,NULL		,'010'		,'[1-5]'	,''		
	--early Other
	UNION ALL SELECT 100,	3901	,'EAR'		,NULL		,'3901'		,''			,''			 		
	UNION ALL SELECT 102,	3914	,'EAR'		,NULL		,'3914'		,''			,''	
	----early base on SET
	UNION ALL SELECT 3915,	3903	,'EAR'		,NULL		,'39030'		,'[1-4]'	,'15'		 
	UNION ALL SELECT 3904,	3904	,'EAR'		,NULL		,'39030'		,'[1-4]'	,'15'		 
	UNION ALL SELECT 3905,	3905	,'EAR'		,NULL		,'39030'		,'[1-4]'	,'15'		 
	UNION ALL SELECT 3915,	3912	,'EAR'		,NULL		,'39030'		,'[1-5]'	,'10'		 
	UNION ALL SELECT 3915,	3912	,'EAR'		,NULL		,'39030'		,'[1-5]'	,'15'		 
	UNION ALL SELECT 3915,	3912	,'EAR'		,NULL		,'39030'		,'[1-5]'	,'20'		 
	UNION ALL SELECT 100,	3909	,'EAR'		,NULL		,'39090'		,'[1-5]'	,'[1-5][0-9]'		
	UNION ALL SELECT 3915,	3915	,'EAR'		,1			,'39150'		,'[1-5]'	,'10'	
	UNION ALL SELECT 3915,	3915	,'EAR'		,1			,'39150'		,'[1-5]'	,'20'	
	UNION ALL SELECT 3915,	3915	,'EAR'		,1			,'39150'		,'[1-5]'	,'30'	
	UNION ALL SELECT 3915,	3915	,'EAR'		,1			,'39150'		,'[1-5]'	,'40'	
	UNION ALL SELECT 3915,	3916	,'EAR'		,NULL		,'39150'		,'[1-5]'	,'05'	
	UNION ALL SELECT 3915,	3916	,'EAR'		,NULL		,'39150'		,'[1-5]'	,'15'	
	UNION ALL SELECT 3915,	3916	,'EAR'		,NULL		,'39150'		,'[1-5]'	,'25'	
	UNION ALL SELECT 3915,	3916	,'EAR'		,NULL		,'39150'		,'[1-5]'	,'35'

	INSERT INTO @tblResource ( pfid, bettype, betid, SettleType, OddsType, ResourceId ,  Prefix )	
	SELECT  pfid, bettype
		, CASE WHEN X <> '' THEN '80' + x.Num + Y
				ELSE '0'
			END AS betid
		, SettleType, OddsType, Prefix + ISNULL(x.Num,'') + Y
		, Prefix
	FROM @tblResourceFormat r
		OUTER APPLY ( SELECT  Num
						FROM @tblNumber n
						WHERE n.Num LIKE r.X
					) x
	WHERE bettype <> 3909
	
	--bettype 3909
	;WITH cte_3909 (  pfid, bettype, SettleType, OddsType, ResourceId, Prefix ) AS
	(	SELECT  pfid, bettype
			, SettleType, OddsType, Prefix + x.Num
			, Prefix
		FROM @tblResourceFormat r
			CROSS APPLY ( SELECT  Num FROM @tblNumber n	WHERE n.Num LIKE r.X  ) x
		WHERE bettype = 3909
	)
	INSERT INTO @tblResource ( pfid, bettype, betid, SettleType, OddsType, ResourceId, Prefix )	
	SELECT  pfid, bettype
			,'80' + RIGHT(ResourceId,1) + RIGHT( '0'  + Y.Num , 2) AS betid
			, SettleType, OddsType
			, ResourceId + RIGHT( '0'  + Y.Num , 2) AS ResourceId
			, Prefix
	FROM cte_3909
	CROSS APPLY ( SELECT  Num FROM @tblNumber n ) Y
	
	;WITH cte_UpdateOrder AS 
	(
		SELECT bettype, betid, resourceid
			 , 6999	+ ROW_NUMBER() OVER( 
										 PARTITION BY CASE WHEN SettleType= 'MNL' THEN ResourceId ELSE NULL END  
										 ORDER BY LEFT(ResourceId,6), betid, bettype
										) 
			AS rk
		FROM @tblResource
		WHERE ResourceId NOT IN ('00','0100', '3901', '3914', '3902', '0101', '0102', '0103', '0104', '0105' )
	)
	
	UPDATE r
	SET Ord = rk
		, GroupType =  'SP'
	FROM @tblResource r
	INNER JOIN cte_UpdateOrder u ON r.bettype = u.bettype AND r.betid = u.betid AND r.ResourceId = u.ResourceId

	UPDATE @tblResource
	SET Ord = CASE  WHEN ResourceId = '0101' THEN 1
					WHEN ResourceId = '0102' THEN 2
					WHEN ResourceId = '0103' THEN 3
					WHEN ResourceId = '0104' THEN 4
					WHEN ResourceId = '0105' THEN 5
					WHEN ResourceId IN ( '00', '3902', '0100' ) THEN 99
					WHEN ResourceId = '3901'		 THEN 6000
					WHEN ResourceId = '3914'		 THEN 6001
					END
		,GroupType =  CASE WHEN  ResourceId IN ('00','0100', '3902' ) THEN 'FT' 
							ELSE 'SP' 
							END
	WHERE ResourceId IN ('00','0100', '3901', '3914', '3902', '0101', '0102', '0103', '0104', '0105' ) 

	UPDATE @tblResource
	SET betid = LEFT(betid, 3)
	WHERE bettype IN (3903,3904, 3905)

	----373 rows
	INSERT INTO dbo.SettlementSpecialBettypeProfile 
	(	pfID
		, BetType
		, SportType
		, BetID
		, ResourceID
		, SettleType
		, GroupType
		, OrdNo
		, RoundID
		, OddsType
		, RefResourceId
	)
	SELECT pfid, bettype, 6 AS SportType , CAST(betid AS BIGINT) AS betid, ResourceId,SettleType,GroupType,Ord,RoundID,OddsType
		, CASE WHEN ResourceId IN ( '0100', '3902' ) THEN '00'
				ELSE NULL 
				END AS RefResourceId
	FROM @tblResource ORDER BY Ord

	
END
GO


