/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 08@Aries
	Task: Support turn-off AutoPayout setting for Main Result of All Cricket's Real Matches [Redmine:#216540]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
DECLARE @LeagueSetting TABLE(LeagueId INT)

INSERT INTO @LeagueSetting(LeagueId)
SELECT LeagueId 
FROM League WITH(NOLOCK)
WHERE sporttype = 50 
    AND AutoSetting & 1 = 1
	AND LeagueGroupID != 42 


UPDATE l
SET l.AutoSetting = l.AutoSetting^1
FROM League AS l
WHERE l.LeagueId IN (SELECT ls.LeagueId  FROM @LeagueSetting AS ls)



GO
DECLARE @MatchSetting TABLE(MatchId INT)

INSERT INTO @MatchSetting(MatchId)
SELECT MatchId 
FROM Match AS m WITH(NOLOCK)
    INNER JOIN League AS l WITH(NOLOCK) ON l.LeagueID = m.LeagueID
WHERE l.sporttype = 50 
    AND LeagueGroupID != 42 
    AND m.AutoSetting & 1 = 1


UPDATE m
SET m.AutoSetting = m.AutoSetting^1
FROM Match AS m
WHERE m.MatchId IN (SELECT ms.MatchId  FROM @MatchSetting AS ms)