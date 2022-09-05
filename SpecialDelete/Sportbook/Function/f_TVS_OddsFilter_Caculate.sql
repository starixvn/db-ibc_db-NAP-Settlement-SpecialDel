/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_OddsFilter_Caculate] (
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
			SELECT CONVERT(SMALLMONEY, f.value) AS OddValue
			FROM STRING_SPLIT(@Odds_str, ',') f
		)
		,cte_convert AS
		(
			--MY -> DEC
			SELECT CASE WHEN c.OddValue > 0 THEN 1 + c.OddValue
						ELSE 1 + (1 / ABS(c.OddValue)) END AS OddValue
					, 1 AS OddsType
			FROM cte c

			--MY -> HK
			UNION ALL
			SELECT CASE WHEN c.OddValue > 0 THEN c.OddValue
						ELSE 1 / ABS(c.OddValue) END AS OddValue
					, 2 AS OddsType
			FROM cte c

			--MY -> INDO
			UNION ALL
			SELECT -1 / c.OddValue AS OddValue
					, 3 AS OddsType
			FROM cte c

			--MY -> MY
			UNION ALL
			SELECT c.OddValue AS OddValue
					, 4 AS OddsType
			FROM cte c

			--MY -> US
			UNION ALL
			SELECT -100 / c.OddValue AS OddValue
					, 5 AS OddsType
			FROM cte c

			--MY -> MMR
			UNION ALL
			SELECT c.OddValue AS OddValue
					, 6 AS OddsType
			FROM cte c

			--MY -> SB
			UNION ALL
			SELECT c.OddValue AS OddValue
					, 7 AS OddsType
			FROM cte c
		)
		INSERT INTO @OddFilter (Odds, OddsType)
		SELECT r.OddValue, r.OddsType
		FROM cte_convert r
	END

	RETURN
END
GO
