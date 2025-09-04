/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20250829@Max
    Task: Basketball Player Prop [Redmine:#233012]
    DB: DBPRO/bodb02
	
	Revisions:
		 - 20250829@Max: Update SDTpfID [Redmine:#233012]
*/

USE bodb02
GO

UPDATE sp
SET sp.SDTpfId = CASE WHEN sp.BetType IN (654,657,660,663,666,668,670,672,673,674) THEN 3
					WHEN sp.BetType IN (653,655,656,658,659,661,662,664,665,667,669,671) THEN 8827
					WHEN sp.BetType IN (685,686,687,688) THEN 8828
					ELSE sp.SDTpfId 
				END
FROM dbo.SettlementSpecialBettypeProfile sp WITH(ROWLOCK, UPDLOCK)
WHERE sp.SportType = 2
	AND sp.BetType IN (	
			654,657,660,663,666,668,670,672,673,674 --Over/Under
			,653,655,656,658,659,661,662,664,665,667,669,671 --At least/Exact
			,685,686,687,688 --Band
		)

