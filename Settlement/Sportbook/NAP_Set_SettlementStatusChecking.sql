/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20211108@Louisa: In-house Replicator: Deleted Action [Redmine:#164393]
		- 20240108@Aries: Refund-SDT only when the match is 'Suspend' (from Admin-site) for Soccer [Redmine:#208512]
		- 20250514@Hughie: Pingoal Soccer Marble [Redmine:#220002]
		
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
			,@IsMarkedRefund BIT = 0

	SELECT	@SettlementStatus = m.SettlementStatus
			,@EventStatus = m.eventstatus
			,@LeagueId = m.leagueid
			,@EventStatusReason = ISNULL(m.EventStatusReason,0)
			,@IsMarkedRefund = CASE WHEN ISNULL(m.SettlementStatus,0) & 32 = 32 THEN 1
									ELSE 0
								END
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT	@LeagueGroupId = ISNULL(LeagueGroupID, 0)
	FROM	dbo.League WITH(NOLOCK)
	WHERE	leagueid = @LeagueId
	
	IF @LeagueGroupId IN (113, 252) -- skip check refund flag for PinGoal
	RETURN

	IF @EventStatusReason > 0 AND @EventStatus = 'running' AND @IsEarly = 0 AND @IsAutoRefund = 0 -- exclude Refund Fast market, Refund early, Auto Refund	
	BEGIN
		SELECT  @ErrCode = CASE WHEN @Action LIKE 'CAL%' AND @IsMarkedRefund = 1 THEN 1001033
								WHEN @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 AND @IsMarkedRefund = 0 THEN 1001034
								ELSE 1001068
								END
				,@ErrMsg = CASE WHEN @Action LIKE 'CAL%' AND @IsMarkedRefund = 1 THEN 'WARNING! Cannot proceed due to this match is marked for Refund All.	'
								WHEN @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 AND @IsMarkedRefund = 0 THEN 'WARNING! Cannot proceed due to this match is NOT marked for Refund All.'
								ELSE 'WARNING! Cannot proceed this action with current match''s status.	'
								END
		WHERE 1 = CASE WHEN @Action = 'REFUND-HT' THEN 1
						 
						WHEN @IsSettleAbandonedMatchIBC = 1 
							AND ( @EventStatusReason <> 4 OR @IsMarkedRefund = 1) THEN 1 ---REFUND-FT(SUS), REFUND All(SUS)
						 
						WHEN @Action = 'REFUND-FT' AND @IsSettleAbandonedMatchIBC = 0 
							AND ( @EventStatusReason <> 2 OR @IsMarkedRefund = 1) THEN 1
						 
						WHEN @Action ='REFUND' 
							AND @IsSettleAbandonedMatchIBC = 0 
							AND (@EventStatusReason NOT IN ( 1, 3) OR @IsMarkedRefund = 0 ) THEN 1

						WHEN @Action IN ('CAL', 'CAL-FT') AND @EventStatusReason IN ( 2, 4) THEN 1
						
						WHEN @Action LIKE 'CAL%' AND @IsMarkedRefund = 1 THEN 1

						ELSE 0
					END

		IF ISNULL(@ErrCode,0) > 0
		RETURN

		-- check running odds: REFUND ALL(POS)
		IF EXISTS (	SELECT TOP 1 1 
					FROM dbo.odds o WITH(NOLOCK) 
					WHERE @Action = 'REFUND' 
						AND @IsSettleAbandonedMatchIBC = 0
						AND o.matchid = @matchid AND o.oddsstatus NOT IN ('closed', 'internal') 
					)
		SELECT	@ErrCode = 1001035
				,@ErrMsg = 'WARNING! Cannot proceed due to running odds. Please close them all and try again.'

		IF ISNULL(@ErrCode,0) > 0
		RETURN

	END
	ELSE IF  @EventStatusReason <> 4 AND @EventStatus = 'running' AND @IsEarly = 0 AND @IsAutoRefund = 0 AND  @IsSettleAbandonedMatchIBC = 1 AND  @Action IN ('REFUND', 'REFUND-FT')
	BEGIN
		SELECT   @ErrCode = 1001068							
				,@ErrMsg = 'The match must be marked as "Suspend" to Refund SDT. Please contact Event Team then try again.'
		RETURN 						
	END
	ELSE IF @IsMarkedRefund = 1 OR (@Action = 'REFUND' AND @EventStatus = 'Postponed')
	BEGIN
		IF @Action LIKE 'CAL%' 
			OR (@Action = 'REFUND' AND @IsSettleDetermined = 1) -- fast SDT market
		BEGIN
    		SELECT	@ErrCode = 1001033
					,@ErrMsg = 'WARNING! Cannot proceed due to this match is marked for Refund All.	'
		END
		ELSE IF @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 -- Refund ALL (POS), Refund early, refund fast market
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM dbo.odds o WITH(NOLOCK) WHERE o.matchid = @matchid AND o.oddsstatus NOT IN ('closed', 'internal') AND ISNULL(o.IsDeleted,0) = 0 ) 	-- check running odds
				SELECT	@ErrCode = 1001035
						,@ErrMsg = 'WARNING! Cannot proceed due to running odds. Please close them all and try again.'
		END
    END
	ELSE
	BEGIN
		IF @Action = 'REFUND' AND @IsSettleAbandonedMatchIBC = 0 AND @IsEarly = 0 ---- Refund ALL (POS), refund fast market
			SELECT	@ErrCode = 1001034
					,@ErrMsg = 'WARNING! Cannot proceed due to this match is NOT marked for Refund All.'

	END

	

END
GO
