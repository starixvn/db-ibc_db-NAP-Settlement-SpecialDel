/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoRefund_ResourceCfm_ScheduleSel] 
AS
/*	Creator: 20241223@Aries
	Task: Support Auto Refund for Soccer's Early Results
	DB: DBPRO/BODB02
	
	Revisions:
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]

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
	VALUES   ('38101'),('38102'),('38103'),('38104'),('38105')
			,('38201'),('38202'),('38203'),('38204'),('38205');

	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT m.matchid 
		, m.leagueid
		, m.sporttype
		, rd.ResourceId
		, rd.HomeValue
		, rd.AwayValue
		, m.ChildMatchType
	FROM dbo.match m WITH(NOLOCK)	
		INNER JOIN dbo.ResultDetail rd WITH(NOLOCK) ON m.matchid = rd.MatchId
		INNER JOIN @tmpResourceIds t ON t.ResourceId = rd.ResourceId
		OUTER APPLY (
			SELECT TOP 1 1 AS IsExistAR 
			FROM	dbo.AutoRefundResult AS ar WITH(NOLOCK) 
			WHERE	ar.MatchId = m.matchid 
					AND ar.ResourceId = rd.ResourceId
					AND ar.TypeId = 7 
		)ap	
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime, ss.[Enable]
			FROM	dbo.SettlementSetting AS ss WITH (NOLOCK)
			WHERE	ss.LeagueId = m.leagueid
					AND ss.AutoType = 7 -- Auto Refund
		) ss
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime, ss.[Enable]
			FROM	dbo.AutoPayoutSetting AS ss WITH (NOLOCK)
			WHERE	ss.matchid = m.matchid
					AND ss.AutoType = 7 -- Auto Refund
		) ms
	WHERE	m.eventstatus = 'completed'  
			AND m.ChildMatchType = 202 -- match pen
			AND m.sporttype = 1
			AND rd.ResultStatusID = 3 -- confirmed
			AND ap.IsExistAR IS NULL
			AND m.eventdate BETWEEN @fromdate AND @todate 
			AND GlobalShowTime <= @checktime					
			AND COALESCE(ms.[Enable],ss.[Enable],0) = 1		
			AND ISNULL(m.SettlementStatus,0) & 87 = 0
			AND rd.HomeValue  LIKE '%NT%' 
END
GO
