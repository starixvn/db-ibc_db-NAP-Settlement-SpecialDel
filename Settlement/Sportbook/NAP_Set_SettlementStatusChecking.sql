/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [NAP_Set_SettlementStatusChecking]
	@MatchId				INT
	,@Action				VARCHAR(20)
	,@IsEarly				BIT = 0
	,@IsSettleDetermined	BIT = 0
	,@IsSettleAbandonedMatchIBC BIT = 0
	,@IsAutoRefund			BIT = 0
	,@ErrCode				INT = 0 OUTPUT
	,@ErrMsg				VARCHAR(200) = '' OUTPUT
AS
/*
	Created: Kathy
	Date: 20200724
	Task : check settlement status
	DB: DBPRO/bodb02

	Revisions:
		- 20200724@Kathy: Prevent Refund Wrong Match by Checking Settlement Status [Redmine:#136390]
		- 20200819@Kathy: Allow to Refund a postponed match without checking Refund flag [Redmine:#139903]
		- 20201123@Kathy: Not Allow to refund determined match (Fast market) [Redmine:#143573]
		- 20210514@Kathy: Incorporate Saba Soccer PinGoal [Redmine:#155052]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		
	Parameters Explanation:    
		@Action: CAL, CAL-HT, CAL-FT, REFUND, REFUND-HT, REFUND-FT

		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @SettlementStatus TINYINT
			,@EventStatus NVARCHAR(50)
			,@LeagueId INT
			,@LeagueGroupId INT
			,@EventStatusReason TINYINT

	SELECT	@SettlementStatus = m.SettlementStatus
			,@EventStatus = m.eventstatus
			,@LeagueId = m.leagueid
			,@EventStatusReason = ISNULL(m.EventStatusReason,0)
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT	@LeagueGroupId = ISNULL(LeagueGroupID, 0)
	FROM	dbo.League WITH(NOLOCK)
	WHERE	leagueid = @LeagueId
	
	IF @LeagueGroupId = 113 -- skip check refund flag for PinGoal
	RETURN

	IF @SettlementStatus & 32 > 0 OR (@Action LIKE 'REFUND%' AND @EventStatus = 'Postponed')
	BEGIN
		SELECT  @ErrCode = 1001033 
				,@ErrMsg = 'WARNING! Cannot proceed due to this match is marked for Refund All.	'
		WHERE 1 = CASE  WHEN @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 AND @IsSettleDetermined = 0 THEN 0 --REFUND ALL (SUS)
						WHEN @Action IN ('REFUND-HT','REFUND-EAR') THEN 0
						ELSE 1
					END

		IF ISNULL(@ErrCode,0) > 0
		RETURN
	END

	ELSE
	BEGIN
		SELECT  @ErrCode = 1001034
				,@ErrMsg = 'WARNING! Cannot proceed due to this match is NOT marked for Refund All.	'
		WHERE 1 = CASE  WHEN @Action LIKE 'CAL%' THEN 0
						WHEN @Action IN ('REFUND-FT', 'REFUND-EAR') THEN 0
						WHEN @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 1 THEN 0
						WHEN @IsSettleDetermined = 1 THEN 0 --fast market
						ELSE 1 END

		IF ISNULL(@ErrCode,0) > 0
		RETURN
	END
	

	SELECT  @ErrCode = 1001068
			,@ErrMsg = 'WARNING! Cannot proceed this action with current match''s status.'
	WHERE @IsSettleDetermined = 0 --  Fastmarket
		AND @IsAutoRefund = 0 --Auto Refund
		AND 1 = CASE  WHEN @Action = 'REFUND-HT' AND @EventStatusReason > 0 THEN 1
					WHEN @Action IN ('REFUND-FT', 'REFUND') AND @IsSettleAbandonedMatchIBC = 1 AND @EventStatusReason <> 4 THEN 1 ---REFUND-FT (Sus), REFUND All(SUS)
					WHEN @Action = 'REFUND-FT' AND @IsSettleAbandonedMatchIBC = 0 AND @EventStatusReason <> 2 THEN 1
					WHEN @Action = 'REFUND'	AND @IsSettleAbandonedMatchIBC = 0 AND @EventStatusReason NOT IN ( 1, 3) THEN 1
					WHEN @Action IN ('CAL','CAL-FT') AND @EventStatusReason IN (2, 4) THEN 1
					ELSE 0
			  END

	IF ISNULL(@ErrCode,0) > 0
	RETURN
	
	
	-- check running odds: REFUND ALL(POS), REFUND EARLY with bit[6] = 1
	IF EXISTS (SELECT TOP 1 1 
			FROM dbo.odds o WITH(NOLOCK) 
			WHERE o.matchid = @matchid AND o.oddsstatus NOT IN ('closed', 'internal')
			AND 1 = CASE WHEN @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 AND @IsSettleDetermined = 0 THEN 1
							WHEN @Action = 'REFUND-EAR' AND @SettlementStatus & 32 > 0 THEN 1
							ELSE 0 END
			)
	SELECT	@ErrCode = 1001035
			,@ErrMsg = 'WARNING! Cannot proceed due to running odds. Please close them all and try again.'

	IF ISNULL(@ErrCode,0) > 0
	RETURN

END
GO
