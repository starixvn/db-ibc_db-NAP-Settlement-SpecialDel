/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220629@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220629@Louisa: Update display order on GUI   [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

BEGIN

	DECLARE @tblResource TABLE ( bettype SMALLINT, betid VARCHAR(5),  RoundId VARCHAR(3), ResourceId VARCHAR(20) )	
	
	INSERT INTO @tblResource ( bettype, betid, RoundId, ResourceId )	
	SELECT bettype, betid, LEFT(CAST( BetId AS VARCHAR(5) ),3) AS RoundId ,ResourceId
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
	WHERE sp.SportType = 6
		AND SettleType = 'EAR'
		AND bettype NOT IN (3901,3914)

	;WITH cte_newOrder AS (
	SELECT bettype, betid, ResourceId
		, 6999	+ ROW_NUMBER() OVER( PARTITION BY NULL ORDER BY RoundId, ResourceId, bettype, betid) AS NewOrdNo
	FROM @tblResource
	)

	--317 rows
	UPDATE sp 
	SET sp.OrdNo = tmp.NewOrdNo
	FROM SettlementSpecialBettypeProfile sp
		INNER JOIN cte_newOrder tmp ON sp.BetType =tmp.bettype
			AND tmp.betid = sp.BetID
			AND tmp.ResourceId = sp.ResourceID
	WHERE sp.SportType = 6

END
GO


