/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240822@Aries
	Task: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

DECLARE @LeagueSetting TABLE(LeagueId INT)

INSERT INTO @LeagueSetting(LeagueId)
SELECT LeagueId 
FROM SettlementSetting WITH(NOLOCK)
WHERE AutoType = 10


UPDATE l
SET l.AutoSetting = l.AutoSetting^16
FROM League AS l
WHERE l.LeagueId IN (SELECT ls.LeagueId  FROM @LeagueSetting AS ls)


DECLARE @MatchAP TABLE(MatchId INT)

INSERT INTO @MatchAP(MatchId)
SELECT m.MatchId
FROM match  AS  m WITH(NOLOCK)
WHERE m.LeagueId in (SELECT ls.LeagueId FROM  @LeagueSetting  AS ls)
    AND m.AutoSetting & 16 = 16
    AND m.EventStatus = 'running'

UPDATE m
SET m.AutoSetting = m.AutoSetting^16
FROM match AS m
WHERE m.MatchId IN (SELECT ml.MatchId  FROM @MatchAP AS ml)