/*<info serverAlias="DBTXN-ActivityDB" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20240401@Aries
    Task: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
	DB: DBTXN-ActivityDB

*/
SELECT   TOP 100
         m.MatchId 
        ,m.eventstatus
        ,m.eventdate
        ,th.teamname AS HomeName
        ,ta.teamname AS AwayName
        ,m.leagueid 
        ,l.leaguename
        ,ls.BetType 
        ,ls.MinBet 
        ,ls.MinPool 
        ,ls.MaxPool 
        ,pr.TotalPool 
        ,ld.TotalWinner AS TotalWinner 
        ,IIF(l.IsTest = 1 OR ls.IsTest = 1,1,0) AS IsTest 
FROM ActivityDB.dbo.LuckyDrawSetting AS ls WITH(NOLOCK)   
    INNER JOIN bodb02.dbo.match AS m WITH(NOLOCK) ON ls.MatchId = m.matchid 
    INNER JOIN bodb02.dbo.League AS l WITH(NOLOCK) ON m.leagueid = l.leagueid 
    LEFT JOIN bodb02.dbo.team AS th WITH(NOLOCK) ON m.homeid = th.teamid 
    LEFT JOIN bodb02.dbo.team AS ta WITH(NOLOCK) ON m.awayid = ta.teamid 
    CROSS APPLY (SELECT TOP 1 p.TotalPool 
                 FROM ActivityDB.dbo.LuckyDrawPoolPrize AS p WITH(NOLOCK)  
                 WHERE p.MatchId = ls.matchid  
                    AND p.BetType = ls.BetType 
                    AND p.SiteId = ls.SiteId 
                    AND p.BetTeam = 'TotalPool' 
    ) AS pr 
    OUTER APPLY (SELECT COUNT(1) TotalWinner 
                 FROM bodb02.dbo.LuckyDrawList AS ldl WITH(NOLOCK)  
                 WHERE ldl.MatchId = ls.matchid AND ldl.TypeID = 1 
                ) AS ld 
WHERE ls.BetType = 413 
AND ls.SiteId = 4100 
-- AND m.eventstatus = 'completed'   
-- AND m.betstatus NOT LIKE '%Refund%'  
ORDER BY m.eventdate DESC


