/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_OddsFilter_Calculate] (
	@Odds_str VARCHAR(100)
	,@OddsType_Input VARCHAR(20)
)
RETURNS @OddFilter TABLE
(
	Odds SMALLMONEY
	,OddsType TINYINT
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20231214@July: Fix Divide by zero [Redmine: #196467]

	Param's explanation:
*/

BEGIN 
	IF @OddsType_Input = 'DEC'
	BEGIN
		INSERT INTO @OddFilter (Odds, OddsType)
		SELECT f.value, 1
		FROM STRING_SPLIT(@Odds_str, ',') f
	END
	ELSE IF @OddsType_Input = 'MY'
	BEGIN
		;WITH cte AS
		(
			SELECT CONVERT(SMALLMONEY, f.value) AS OddsValue
			FROM STRING_SPLIT(@Odds_str, ',') f
			WHERE f.value <> ''
		)
		,cte_convert AS
		(
			--MY -> DEC
			SELECT CASE WHEN c.OddsValue > 0 THEN CONVERT(DECIMAL(18,2), ROUND(1 + c.OddsValue, 2, 1))
						ELSE  CONVERT(DECIMAL(18,2), ROUND(1 + (1 / ABS(c.OddsValue)), 2, 1)) END AS OddsValue
					, CONVERT(TINYINT, 1) AS OddsType
			FROM cte c

			--MY -> HK
			UNION ALL
			SELECT CASE WHEN c.OddsValue > 0 THEN c.OddsValue
						ELSE CONVERT(DECIMAL(18,2), ROUND(1 / ABS(c.OddsValue), 2, 1)) END AS OddsValue
					, 2 AS OddsType
			FROM cte c

			--MY -> INDO
			UNION ALL
			SELECT CONVERT(DECIMAL(18,2),-1 / c.OddsValue) AS OddsValue
					, 3 AS OddsType
			FROM cte c

			--MY -> MY
			UNION ALL
			SELECT c.OddsValue AS OddsValue
					, 4 AS OddsType
			FROM cte c

			--MY -> US: because values US odds storage, so must /100 after converted
			UNION ALL
			SELECT CONVERT(DECIMAL(18,2), (-100 / c.OddsValue) / 100) AS OddsValue
					, 5 AS OddsType
			FROM cte c

			--MY -> MMR
			UNION ALL
			SELECT c.OddsValue AS OddsValue
					, 6 AS OddsType
			FROM cte c

			--MY -> SB
			UNION ALL
			SELECT c.OddsValue AS OddsValue
					, 7 AS OddsType
			FROM cte c
		)
		INSERT INTO @OddFilter (Odds, OddsType)
		SELECT CONVERT(SMALLMONEY,r.OddsValue), r.OddsType
		FROM cte_convert r
	END

	RETURN
END
GO
