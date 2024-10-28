/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_Resource_ScheduleSel] 
AS
/*	Creator: 20241002@Kathy
	Task: direct payout for early soccer
	DB: DBPRO/BODB02
	
	Revisions:
		
		- 20241002@Kathy: direct payout for early soccer [Redmine:#211079]

	Param's Explanation:
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@currentdate	DATETIME
			,@fromdate		DATETIME
			,@todate		DATETIME
			,@checktime		DATETIME

	SET @currentdate = CAST(GETDATE() AS DATE)
	SELECT	@fromdate = DATEADD(DAY,-1,@currentdate)
			,@todate = DATEADD(DAY,1,@currentdate)
			,@checktime = DATEADD(HOUR, 3, GETDATE())


	DECLARE @tmpResourceIds TABLE(
		ResourceId VARCHAR(20)
	)

	INSERT INTO @tmpResourceIds(ResourceId) 
	SELECT	ISNULL(ss.RefResourceId, ss.ResourceId) AS ResourceId
	FROM	dbo.SettlementSpecialBettypeProfile ss WITH(NOLOCK)
	WHERE	ss.SportType = 1
			AND ss.SettleType = 'EAR'

	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.matchid 
		, m.leagueid
		, rd.ResourceId
		, rd.HomeValue
		, rd.AwayValue
		, rd.LastModifyDate
		, ssp.relatedCalResources
		, ssp.relatedSettResources
	FROM dbo.match m WITH(NOLOCK)	
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
		INNER JOIN dbo.ResultDetail rd WITH(NOLOCK)
			ON m.matchid = rd.MatchId
		INNER JOIN @tmpResourceIds t
			ON t.ResourceId = rd.ResourceId
		OUTER APPLY (
			SELECT TOP 1 1 AS IsExistAP 
			FROM	dbo.AutoPayoutResult ap WITH(NOLOCK) 
			WHERE	ap.MatchId = m.matchid 
					AND ap.ResourceId = rd.ResourceId
					AND ap.CalculationType = 5 -- Early result
		)ap		
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime
			FROM	dbo.SettlementSetting ss WITH (NOLOCK)
			WHERE	ss.LeagueId = l.leagueid
					AND ss.AutoType = 5 -- Direct Auto Payout
		) ss
		OUTER APPLY(
			SELECT TOP 1 JSON_VALUE(sp.APSetting,'$."relatedCalResources"') AS relatedCalResources
						,JSON_VALUE(sp.APSetting,'$."relatedSettResources"') AS relatedSettResources
			FROM	dbo.SettlementSpecialBettypeProfile AS sp WITH (NOLOCK)
			WHERE	sp.SportType = 1
					AND sp.ResourceID =  rd.ResourceId
		) ssp
	WHERE	m.sporttype = 1
			AND rd.ResultStatusID = 3 -- confirmed
			AND ISNULL(rd.ResultSetting,0) & 1 = 0
			AND ap.IsExistAP IS NULL
			AND m.eventdate BETWEEN @fromdate AND @todate 
			AND GlobalShowTime <= @checktime					
			AND 16 & ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) > 0
			AND ISNULL(m.SettlementStatus,0) & 87 = 0
			AND rd.LastModifyDate <= DATEADD(SECOND, - ISNULL(ss.WaitingTime,1), @CurrTime)
			AND rd.HomeValue NOT LIKE '%NT%' 
			AND rd.AwayValue NOT LIKE '%NT%'
			AND rd.ResourceId LIKE '38[1245]0[1-9]' 

END
GO
