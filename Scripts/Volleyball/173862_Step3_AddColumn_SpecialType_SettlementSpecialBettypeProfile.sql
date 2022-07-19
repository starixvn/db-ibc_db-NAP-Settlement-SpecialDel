/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220629@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220629@Louisa: Add column SpecialType to define bettype not allow settle directly FT [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

----1. Add new column [SpecialType]
BEGIN
	IF NOT EXISTS ( SELECT TOP 1 1
					FROM sys.columns c 
						INNER JOIN sys.objects o 
							ON c.object_id = o.object_id
					WHERE c.name = 'SpecialType'
						AND o.name = 'SettlementSpecialBettypeProfile'
					)
	ALTER TABLE SettlementSpecialBettypeProfile ADD SpecialType TINYINT
END
GO

----2. Update value for [SpecialType]
BEGIN
	;WITH cte_SpecialType ( SportType, Bettype ) 
	AS (
				SELECT CAST( 6 AS TINYINT )  AS SportType	,CAST( 401 AS SMALLINT ) AS bettype
				UNION ALL SELECT 6	,402
				UNION ALL SELECT 6	,704
				UNION ALL SELECT 6	,705
				UNION ALL SELECT 6	,706
				UNION ALL SELECT 6	,3902
				UNION ALL SELECT 6	,3910
				UNION ALL SELECT 6	,3917
				UNION ALL SELECT 6	,3911
				UNION ALL SELECT 6	,3913
				UNION ALL SELECT 6	,3906
				UNION ALL SELECT 6	,3907
				UNION ALL SELECT 6	,3908
				UNION ALL SELECT 6	,154
				UNION ALL SELECT 6	,219
				UNION ALL SELECT 6	,220

				UNION ALL SELECT 5	,153

				UNION ALL SELECT 9	,704
				UNION ALL SELECT 9	,705
				UNION ALL SELECT 9	,706
		)

	--56 rows
	UPDATE ss
	SET SpecialType = 1
	FROM SettlementSpecialBettypeProfile ss
		INNER JOIN cte_SpecialType cte
			ON ss.SportType = cte.SportType AND ss.BetType = cte.Bettype
END
GO