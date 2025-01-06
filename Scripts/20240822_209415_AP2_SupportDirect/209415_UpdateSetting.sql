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
WHERE AutoType = 6


UPDATE ss
SET ss.WaitingTime = ISNULL(ss.RetryTime,1800)
FROM SettlementSetting AS ss
WHERE ss.LeagueId IN (SELECT ls.LeagueId  FROM @LeagueSetting AS ls)
    AND ss.AutoType = 6

GO
DECLARE @LeagueAP TABLE(LeagueId INT)

INSERT INTO @LeagueAP(LeagueId)
SELECT LeagueId 
FROM League WITH(NOLOCK)
WHERE sporttype in (5,6,8,43,50)
    AND AutoSetting & 1 = 1


UPDATE l
SET l.AutoSetting = l.AutoSetting | 32
FROM League AS l
WHERE l.LeagueId IN (SELECT ls.LeagueId  FROM @LeagueAP AS ls)


DECLARE @MatchAP TABLE(MatchId INT)

INSERT INTO @MatchAP(MatchId)
SELECT m.MatchId
FROM match  AS  m WITH(NOLOCK)
WHERE m.LeagueId in (SELECT ls.LeagueId FROM  @LeagueAP  AS ls)
    AND m.AutoSetting & 1 = 1


UPDATE m
SET m.AutoSetting = m.AutoSetting | 32
FROM match AS m
WHERE m.MatchId IN (SELECT ml.MatchId  FROM @MatchAP AS ml)


GO
UPDATE SettlementResultTableSetting
SET AP_Group = 1
WHERE Sporttype =2 

GO
UPDATE SettlementResultTableSetting
SET Setting  = Setting^8
WHERE sporttype in (4,47)