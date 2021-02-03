/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	DB: DBTXN.bodb02
	Task: insert new profile [Redmine:#142425]
*/
USE bodb02
GO

SET NOCOUNT ON
INSERT INTO dbo.SettlementSpecialBettypeProfile ([pfID], [BetType], [SportType], [BetID], [ResourceID], [SettleType], [GroupType], [OddsType], [RefResourceId])    
SELECT [pfID], [BetType], [SportType], [BetID], [ResourceID], [SettleType], [GroupType], [OddsType], [RefResourceId]
FROM ( VALUES (1, 1, 1, 0, '00', 'MNL', 'FT', NULL, NULL)
				,(2, 2, 1, 0, '00', 'MNL', 'FT', NULL, NULL)
				,(3, 3, 1, 0, '00', 'MNL', 'FT', NULL, NULL)
				,(4, 4, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(5, 5, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(6, 6, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(1, 7, 1, 0, '01', 'MNL', 'HT', NULL, NULL)
				,(3, 8, 1, 0, '01', 'MNL', 'HT', NULL, NULL)
				,(2, 12, 1, 0, '01', 'MNL', 'HT', NULL, NULL)
				,(13, 13, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(5, 15, 1, 0, '01', 'MNL', 'HT', 1, NULL)
				,(16, 16, 1, 0, '16', 'MNL', 'FT', 1, '00')
				,(6, 126, 1, 0, '01', 'MNL', 'HT', 1, NULL)
				,(405, 405, 1, 0, '405', 'MNL', 'FT', 1, '00')
				,(406, 406, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(407, 407, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(408, 408, 1, 0, '00', 'MNL', 'FT', 1, NULL)
				,(412, 412, 1, 0, '01', 'MNL', 'HT', 1, NULL)
				,(405, 413, 1, 0, '413', 'MNL', 'FT', 1, '00')
				,(405, 414, 1, 0, '414', 'MNL', 'HT', 1, '01')
				,(416, 416, 1, 0, '416', 'MNL', 'FT', 1, '00')
			) AS t([pfID], [BetType], [SportType], [BetID], [ResourceID], [SettleType], [GroupType], [OddsType], [RefResourceId])
WHERE	NOT EXISTS (SELECT TOP 1 1 FROM dbo.SettlementSpecialBettypeProfile s WITH (NOLOCK) WHERE SportType = 1 AND s.bettype = t.BetType)
SET NOCOUNT OFF

GO
