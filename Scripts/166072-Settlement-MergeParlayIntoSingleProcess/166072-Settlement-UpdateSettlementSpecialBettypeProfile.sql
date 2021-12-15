/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

/*  Created: 20220315@Kathy
	Task: update setting [Redmine:#166072 ]
	DB: DBTXN-bodb02
*/


UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET Is3x30 = 0
		,IsSDT = 0 
WHERE	SportType = 1
		AND SettleType = 'EAR'

UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET IsSDT = 1
WHERE	SportType = 1
		AND SettleType = 'EAR'
		AND (bettype BETWEEN 383 AND 387 OR bettype = 391)

UPDATE s	
	SET Is3x30 = f.Is3x30
		,IsSDT = f.IsDetermined
FROM SettlementSpecialBettypeProfile s WITH(ROWLOCK, UPDLOCK)
	INNER JOIN f_Set_GetGroupBettypes() f
		ON s.bettype = f.bettype
WHERE	s.SportType = 1
		AND s.SettleType = 'MNL'


UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET SDTpfId = CASE	
					WHEN bettype = 8 THEN 3
					WHEN bettype = 127 THEN 14
					WHEN bettype = 178 THEN 18
					WHEN bettype = 163 THEN 144
					WHEN bettype = 406 THEN 159
					WHEN bettype = 407 THEN 161
					WHEN bettype = 409 THEN 162
					WHEN bettype = 415 THEN 172
					WHEN bettype = 427 THEN 188
					WHEN bettype = 434 THEN 189
					WHEN bettype = 435 THEN 190
					WHEN bettype IN (483,462,402) THEN 388
					WHEN bettype IN (401,482,461) THEN 389
					WHEN bettype = 408 THEN 397
					WHEN bettype IN (484, 463) THEN 403
					WHEN bettype IN (464, 485) THEN 404
					WHEN bettype = 423 THEN 422
					WHEN bettype = 487 THEN 486
					WHEN bettype = 489 THEN 488
					ELSE bettype
				END
		,SDTResourceId = CASE 
							WHEN bettype IN (14, 127, 22, 172, 396, 422, 423, 448, 454, 486, 487, 488, 489, 490) THEN bettype
							WHEN bettype = 415 THEN 172
							ELSE NULL 
						END 
WHERE	SportType = 1
		AND SettleType = 'MNL'
		AND IsSDT = 1


GO
