/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail]
	@matchid 			INT
    ,@IsRefundPage 		BIT = 0
AS
/*
    Created by: 20220719
    Task: get match info 
   
    Revisions:   
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

*/

BEGIN
    SET NOCOUNT ON

	DECLARE @SettleAbandonedMatchIBCParlay	TINYINT
			,@sporttype						SMALLINT
			,@LeagueGroupID					SMALLINT

	SET @SettleAbandonedMatchIBCParlay = 0

	SELECT @LeagueGroupID = ISNULL(l.LeagueGroupID,0)
    FROM   dbo.match m WITH (NOLOCK)
	INNER JOIN  dbo.League l WITH(NOLOCK) 
		ON	m.leagueid = l.leagueid
    WHERE	m.matchid = @matchid

	IF @IsRefundPage = 1
	BEGIN
		-- Check for SDT parlay bettype
		IF EXISTS (
				SELECT TOP 1 1 
				FROM	dbo.ResultDetail rs WITH(NOLOCK)
				WHERE	rs.matchid = @matchid
						AND rs.SettlementStatusID	IN (5,6) --abandoned match
			)
		BEGIN
			SELECT 
				@SettleAbandonedMatchIBCParlay = CASE 
													WHEN ResourceId = '00' THEN 2 --2H 
													WHEN ResourceId = '01' THEN 1 --1H
													ELSE @SettleAbandonedMatchIBCParlay 
												END
			FROM	dbo.ResultDetail rs WITH(NOLOCK)
					CROSS APPLY
					(
						SELECT CAST(SUBSTRING(OtherInfo,CHARINDEX('SDT:',OtherInfo) + 4, 1) AS TINYINT) AS SDTRecord
					) AS sdt
			WHERE	rs.matchid 			= @matchid
					AND rs.ResourceID 		IN ('00', '01')
					AND 4 & sdt.SDTRecord 	= 4
		END

	END 
	
    SELECT m.sporttype
        ,m.betstatus
        ,m.hthomescore AS HalfTimeHomeScore
        ,m.htawayscore AS HalfTimeAwayScore
        ,datediff(minute,m.kickofftime, CURRENT_TIMESTAMP) playtime
        ,m.leagueid
        ,m.matchid
        ,m.homeid
        ,m.awayid
        ,m.matchcode
        ,m.kickofftime
        ,m.finalhomescore
        ,m.finalawayscore
        ,m.eventstatus
        ,isnull(mr.refund, 0) IsRefund
        ,isnull(mr.calrefund, 0) IsCalRefund
        ,isnull(mr.calculate, 0) IsCalculated
        ,isnull(mr.multiple, 0) IsMultiCaled
        ,isnull(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
        ,mr.ishtcal AS IsHalfTimeCal   
        ,m.GoalRecord
        ,mr.ConfirmHT
        ,mr.ConfirmFT      
		,CASE WHEN m.sporttype = 1 
				AND datediff(minute, m.kickofftime, CURRENT_TIMESTAMP) < 100 
                AND (datediff(minute, m.kickofftime, CURRENT_TIMESTAMP) > 45 OR isnull(mr.ConfirmHT, 0) > 0) 
                AND isnull(mr.ConfirmFT, 0) = 0 THEN 1 ELSE 0 END AS IsHTOnly
       	,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting,0)) AS AutoSetting
		,ISNULL(aps.HasInstantCompleted,0) AS HasInstantCompleted
		,@SettleAbandonedMatchIBCParlay AS SettleAbandonedMatchIBCParlay
		,l.LeagueGroupID 
		,m.SettlementStatus
		,m.EventStatusReason
     FROM dbo.match m WITH (NOLOCK)
        LEFT OUTER JOIN dbo.match_remark mr WITH (NOLOCK) 
			ON	m.matchid = mr.matchid
		INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	m.leagueid = l.leagueid
		OUTER APPLY (
			SELECT	TOP (1) CAST(1 AS BIT) AS HasInstantCompleted
			FROM	dbo.AutoPayoutResult WITH(NOLOCK)
			WHERE	matchid = m.matchid
				AND CalculationType IN (101, 102) -- Instant Calculation
				AND StatusId = 2 --completed
			
		) AS aps
    WHERE m.matchid = @matchid

	-- child match
	SELECT	m.matchid
			,m.matchcode
			,m.eventstatus
			,ISNULL(m.SettlementStatus,0)
			,m.homeid
			,m.awayid
			,m.betstatus
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.ParentID = @matchid
			AND m.sporttype = 1 
			AND @LeagueGroupID IN (42,74,108)
			AND m.ChildMatchType IN (201,202,203)
			AND ISNULL(m.IsDeleted,0) = 0
END
GO