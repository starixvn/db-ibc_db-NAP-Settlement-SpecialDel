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
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	SELECT CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2)) AS WrongScore
		,MIN(b.transdate) AS FromTime
		,MAX(b.transdate) AS ToTime
	FROM dbo.bettrans b WITH (NOLOCK)
	WHERE b.matchid = @MatchId
		AND b.betfrom <> 'p'
		AND b.statusID NOT IN (101, 102, 103)
		AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 THEN 0
				ELSE 1 END
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + ' - ' + CAST(b.liveawayscore AS VARCHAR(2))

END
GO