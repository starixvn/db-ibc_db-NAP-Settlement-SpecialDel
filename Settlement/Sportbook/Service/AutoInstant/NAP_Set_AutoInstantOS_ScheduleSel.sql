/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoInstantOS_ScheduleSel
	@Sporttype SMALLINT 
AS
/*
	Creator: 20230801@Aries
	Task: Support Instant Settlement for Basketball
	DB: DBPRO/bodb02
	Revisions:	
		- 20230801@Aries: Created [Redmine:#189662]

*/

BEGIN
    SET NOCOUNT ON

	DECLARE	 @CurrentDate	DATETIME
			,@FromDate		DATETIME
			,@ToDate		DATETIME
			,@Checktime		DATETIME
			,@ProcName		SYSNAME	= OBJECT_NAME(@@procid)
			,@WaitingTime	VARCHAR(10)
			,@IsWaiting		BIT = 0
	
	EXEC dbo.NAP_Set_SPDeploymentInfo 
		 @SPName		= @procName
		,@WaitingTime	= @WaitingTime	OUTPUT
		,@IsWaiting		= @IsWaiting	OUTPUT

	IF ISNULL(@IsWaiting,0) = 1
	BEGIN
		RETURN
	END

	SELECT	 @CurrentDate	= CAST(GETDATE() AS DATE)
	SELECT	 @FromDate		= DATEADD(DAY,-1,@CurrentDate)
			,@ToDate		= DATEADD(DAY,1,@CurrentDate)
			,@Checktime		= DATEADD(HOUR, 3, GETDATE())

    SELECT m.MatchID,m.LeagueID, r.HomeValue, r.AwayValue, r.ResourceId
    FROM dbo.Match m WITH (NOLOCK)
		INNER JOIN dbo.League l WITH (NOLOCK) ON m.LeagueID = l.LeagueID      
		CROSS APPLY (
			SELECT	MAX(pr.ProviderExternalID) AS MaxProviderExternalID
			FROM	dbo.ProviderExternalResultDetail AS pr WITH (NOLOCK)
			WHERE	pr.MatchID  = m.MatchID 
					AND pr.SourceID = 98
					AND pr.ResourceId LIKE 'Q[1-4]'
            GROUP BY pr.ResourceId
		) AS mpr
		CROSS APPLY (
			SELECT	pr.ResourceId, pr.HomeValue,pr.AwayValue
			FROM	dbo.ProviderExternalResultDetail AS pr WITH (NOLOCK)
			WHERE	pr.ProviderExternalId  = mpr.MaxProviderExternalID
		) AS r
    WHERE m.SportType = @Sporttype
	 AND m.EventStatus = 'running' 
	 AND m.eventdate BETWEEN @FromDate AND @ToDate
	 AND GlobalShowTime <= @Checktime
	 AND m.SettlementStatus & 87 = 0 --Bit: 1: Pending, 2: Undecided, 3: UnderSettlement, 5: MTDHold, 7: Hold Key
	 AND 2 & ISNULL(m.AutoSetting, l.AutoSetting) = 2
	 AND CHARINDEX('hedge', m.matchcode) = 0 -- hedge match	 
	 AND NOT EXISTS (SELECT 1
				     FROM dbo.ResultDetail AS rd WITH(NOLOCK)
					 WHERE rd.MatchId = m.MatchId
						AND rd.ResourceID = r.ResourceId 
						AND rd.ResultStatusID IN (2,3,5))		
     AND NOT EXISTS (SELECT 1
	 				 FROM dbo.AutoPayoutResultOS AS a WITH(NOLOCK)
	 				 WHERE a.MatchID = m.MatchID
						AND a.ResourceID = r.ResourceID
	 					AND a.HomeValue = r.HomeValue
	 					AND a.AwayValue = r.AwayValue
	 					AND a.SourceID = 98)
	AND  1 = IIF(@Sporttype = 2 AND CAST(ISNULL(r.HomeValue, 0) AS INT) + CAST(ISNULL(r.AwayValue, 0) AS INT) < 6,0,1)

END
GO