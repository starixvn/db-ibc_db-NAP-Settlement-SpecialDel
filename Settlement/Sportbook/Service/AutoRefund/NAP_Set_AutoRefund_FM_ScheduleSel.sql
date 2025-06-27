/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_AutoRefund_FM_ScheduleSel] 
AS
/*	Creator: 20250623@Hughie
	Task: Get info for Auto Refund FastMarket
	DB: DBPRO/BODB02
	
	Revisions:
		- 20250623@Hughie: Auto Refund- Fast Market ＆ Time Machine- Support Special Session [Redmine:#225889]

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
	VALUES   ('221WB01'),('221WB02'),('221WB03'),('221WB04'),('221SUS');

	DECLARE @CurrTime DATETIME = GETDATE()

	SELECT  m.MatchId
			,m.LeagueId
			,r.ResourceId
			,r.HomeValue
			,r.AwayValue
			,r.OtherInfo
			,r.ResultStatusID
			,r.SettlementStatusID
	FROM match m WITH (NOLOCK) 
		INNER JOIN ResultDetail r WITH (NOLOCK) ON r.MatchId = m.matchid 
		INNER JOIN @tmpResourceIds t ON t.ResourceId = r.ResourceId
		OUTER APPLY (
			SELECT TOP 1 ap.WaitingTime, ap.[Enable]
			FROM AutoPayoutSetting ap WITH (NOLOCK)
			WHERE r.MatchId = ap.MatchId 
				AND ap.AutoType = 11
		) ap
		OUTER APPLY(
			SELECT TOP 1 ss.WaitingTime, ss.[Enable]
			FROM SettlementSetting ss with (nolock) 
			WHERE ss.LeagueId = m.leagueid
				AND ss.AutoType = 11
		) ss
	WHERE (r.ResourceId LIKE '221WB__' OR r.ResourceId = '221SUS')
		AND r.ResultStatusID = 5
		AND m.eventdate BETWEEN @fromdate AND @todate 
		AND GlobalShowTime <= @checktime
		AND COALESCE(ap.[Enable],ss.[Enable],0) = 1
		AND ISNULL(m.SettlementStatus,0) & 87 = 0

END
GO