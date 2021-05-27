/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ScoreInfo_Select]
(	
	@MatchId              INT
)
AS
/*	
	Created by: Max
	Date 20210422
	Task: TVS - Wrong Score [Redmine: #140953]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210422@Max: Create new SP [Redmine: #140953]
		- 20210527@Max: Exclude 2H ticket from get score & time range [Redmine: #155598]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	SELECT sc.WrongScore
		, MIN(sc.FilterFromTransTime) AS FilterFromTransTime
		, MAX(sc.FilterToTransTime) AS FilterToTransTime
	FROM
	(
		SELECT CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS WrongScore
			,MIN(b.transdate) AS FilterFromTransTime
			,MAX(b.transdate) AS FilterToTransTime
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		WHERE b.matchid = @MatchId
			AND b.betfrom <> 'p'
			AND b.statusID NOT IN (101, 102, 103)
			AND b.bettype NOT IN (805, 806, 9, 29)			
			AND b.bettype NOT BETWEEN 901 AND 920
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 THEN 0
					ELSE 1 END
			AND f.GroupName <> '2H'
		GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

		UNION ALL
		SELECT CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS WrongScore
			,MIN(b.transdate) AS FilterFromTransTime
			,MAX(b.transdate) AS FilterToTransTime
		FROM dbo.bettransm b WITH (NOLOCK)
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
		WHERE b.matchid = @MatchId
			AND b.betfrom <> 'p'
			AND b.statusID NOT IN (101, 102, 103)
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 THEN 0
					ELSE 1 END
			AND f.GroupName <> '2H'
		GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
	)sc
	GROUP BY sc.WrongScore

END
GO