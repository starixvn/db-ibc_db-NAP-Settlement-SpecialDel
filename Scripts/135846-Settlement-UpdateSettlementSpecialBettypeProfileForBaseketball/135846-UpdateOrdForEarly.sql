/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: Kathy
    Date: 20200716
    Task : update ord for early bettype of basketball [Redmine:#135846]
    DB: DBTXN/bodb02
*/

USE bodb02
GO
	
UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET OrdNo = CASE WHEN bettype = 604 then 1
					WHEN BetType = 613 AND BetID = 80110 THEN 100
					WHEN BetType = 613 AND BetID = 80115 THEN 101
					WHEN BetType = 613 AND BetID = 80120 THEN 102
					WHEN BetType = 613 AND BetID = 80125 THEN 103
					WHEN BetType = 613 AND BetID = 80210 THEN 200
					WHEN BetType = 613 AND BetID = 80215 THEN 201
					WHEN BetType = 613 AND BetID = 80220 THEN 202
					WHEN BetType = 613 AND BetID = 80225 THEN 203
					WHEN BetType = 606 AND BetID = 820 THEN 300
					WHEN BetType = 606 AND BetID = 825 THEN 301
					WHEN BetType = 606 AND BetID = 830 THEN 302
					WHEN BetType = 606 AND BetID = 835 THEN 303
					WHEN BetType = 613 AND BetID = 80310 THEN 400
					WHEN BetType = 613 AND BetID = 80315 THEN 401
					WHEN BetType = 613 AND BetID = 80320 THEN 402
					WHEN BetType = 613 AND BetID = 80325 THEN 403
					WHEN BetType = 613 AND BetID = 80410 THEN 500
					WHEN BetType = 613 AND BetID = 80415 THEN 501
					WHEN BetType = 613 AND BetID = 80420 THEN 502
					WHEN BetType = 613 AND BetID = 80425 THEN 503
					WHEN BetType = 607 AND BetID = 820 THEN 600
					WHEN BetType = 607 AND BetID = 825 THEN 601
					WHEN BetType = 607 AND BetID = 830 THEN 602
					WHEN BetType = 607 AND BetID = 835 THEN 603
					ELSE 0
					END
WHERE	SportType = 2
		AND SettleType = 'ear'

GO



