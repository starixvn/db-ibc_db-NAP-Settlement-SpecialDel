/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LastTime_Select]
(	
	@MatchId				INT
	,@FilterFromTransTime	DATETIME = NULL
	,@ActionId				INT = 5
)
AS
/*	
	Created by: Max
	Date 20210616
	Task: [TVS] Wrong Score Enhancement 1 [Redmine: #140953]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210616@Max: Create new SP [Redmine: #156349]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @LastTime  DATETIME

	SELECT @LastTime = (
					SELECT MAX(ISNULL(b.checktime, b.transdate))
					FROM dbo.bettrans b WITH (NOLOCK)
						INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
					WHERE b.matchid = @MatchId
						AND ISNULL(b.checktime, b.transdate) > @FilterFromTransTime
						AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
								WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
						AND b.betfrom <> 'P'
						AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
				)

	SELECT ISNULL(@LastTime, @FilterFromTransTime) AS LastTime

END
GO