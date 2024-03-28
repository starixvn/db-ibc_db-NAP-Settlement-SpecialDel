/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LastTime_Select]
(	
	@MatchId				INT
	,@FilterFromTransTime	DATETIME = NULL
	,@ActionId				INT = 5
	,@FilterBy				TINYINT = 0
)
AS
/*	
	Created by: 20210616@Max
	Task: [TVS] Wrong Score Enhancement 1 [Redmine: #140953]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210616@Max: Create new SP [Redmine: #156349]
		- 20220208@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230713@July: Get time of last ticket (include time cancel CO) [Redmine: #190859]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @LastTime  DATETIME
		   ,@SiteDBGroupID SMALLINT = 0 
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SELECT @LastTime = (
					SELECT MAX(LastTime)
					FROM
					(
						SELECT MAX(CASE WHEN @FilterBy IN (1,4) AND ISNULL(b.betdaqid,0) <> - 2 THEN b.transdate 
										WHEN @FilterBy = 2 AND ISNULL(b.betdaqid,0) <> - 2 THEN ISNULL(b.checktime, b.transdate) 
										WHEN b.betdaqid = -2 THEN c.checktime
										END
								  ) AS LastTime
						FROM dbo.bettrans b WITH (NOLOCK)
							INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.bettype
							LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
						WHERE b.matchid = @MatchId
							AND 1 = CASE WHEN @FilterBy = 1 AND ISNULL(b.betdaqid,0) <> - 2 AND b.transdate > @FilterFromTransTime THEN 1
										 WHEN @FilterBy = 2 AND ISNULL(b.betdaqid,0) <> - 2 AND ISNULL(b.checktime, b.transdate) > @FilterFromTransTime THEN 1
										 WHEN @FilterBy = 4 AND ISNULL(b.betdaqid,0) <> - 2
											AND ((b.checktime > @FilterFromTransTime) OR (b.transdate > @FilterFromTransTime))
										 THEN 1
										 WHEN b.betdaqid = -2 AND c.CheckTime > @FilterFromTransTime THEN 1
									ELSE 0 END 
							AND 1 = CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102, 103) THEN 1
									WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
							AND b.betfrom <> 'P'
							AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
							AND b.SiteDBGroupID = @SiteDBGroupID

						UNION ALL
						SELECT MAX(CASE WHEN @FilterBy IN (1,4) THEN bm.transdate 
										WHEN @FilterBy = 2 THEN ISNULL(bm.checktime, bm.transdate) END) AS LastTime
						FROM dbo.bettransm bm WITH (NOLOCK)
							INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = bm.refno AND b.matchid = 29 AND b.bettype = 29
							INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = bm.bettype
						WHERE bm.matchid = @MatchId
							AND 1 = CASE WHEN @FilterBy = 1 AND b.transdate > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 2 AND ISNULL(b.checktime, b.transdate) > @FilterFromTransTime THEN 1
										WHEN @FilterBy = 4 
											AND ((b.checktime > @FilterFromTransTime) OR (b.transdate > @FilterFromTransTime))
										THEN 1
									ELSE 0 END 
							AND 1 = CASE WHEN @ActionId <> 2 AND bm.statusID NOT IN (101, 102, 103) THEN 1
									WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
								ELSE 0 END
							AND bm.betfrom <> 'P'
							AND b.statusID NOT IN (102, 103)
							AND 1 = CASE WHEN b.livehomescore = 0 AND bm.liveawayscore = 0 AND bm.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END
							AND bm.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = @SiteDBGroupID
					)b
				)

	SELECT ISNULL(@LastTime, @FilterFromTransTime) AS LastTime

END
GO