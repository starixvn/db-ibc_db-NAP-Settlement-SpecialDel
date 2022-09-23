/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Refund_MP_Push] (
	@AdminId 						INT
	,@MatchId 						INT
	,@Action 						VARCHAR(20) = 'REFUND'
	,@SettleAbandonedMatchIBCParlay TINYINT	= 0
	,@IP 							VARCHAR(15) = ''
	,@BroadcastSessionId	VARCHAR(50)		= NULL
	,@ErrCode 						INT = 0 OUTPUT
	,@ErrMsg NVARCHAR(200) 			= '' OUTPUT
)
AS
/*	Creator: 20161205@Bobby
	Task: #61352 - Implement SDT for parlay tickets
	DB: DBTXN/BODB02
	ORIGINAL:

	Revisions:		
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171204@Kathy: Allow to settle parlay in case Early Settled bettypes have only Single tickets [Redmine:#87544]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]	
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190124@Sol: Second Accept Process of Parlay Tickets [Redmine #107296]
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190725@Sol: Incorporate PHAIO 4b - Implement [ResourceID] = '09' to Settle PH4B Bet Types [Redmine:#115232]
		- 20190924@Sol: Incorporate BMAIO - modified sp to support ResultDetailOS [Redmine:#120324]
		- 20200410@Sol: HotFix - Tennis - Refund parlay [Redmine:#132208]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20210203@Louisa: Cricket AIO [Redmine:#148870]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
	
	Param's Explanation:		
		- @Action: [Refund, Refund-HT, Refund-FT]
		- @SettleAbandonedMatchIBCParlay: TINYINT
			+ 1: Single - Abandoned 1H
			+ 2: Single - Abandoned 2H
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sporttype     		INT	
		,@procName      		NVARCHAR(128)
		,@Mode					VARCHAR(20) 

	SELECT	@Mode = CASE 
						WHEN @Action = 'REFUND' AND @SettleAbandonedMatchIBCParlay =  1 THEN 'ABANDONED-1H'
						WHEN @Action = 'REFUND-FT' AND @SettleAbandonedMatchIBCParlay =  2 THEN 'ABANDONED-2H'
						ELSE @Action
					END						

    SELECT @sporttype   = m.sporttype
    FROM dbo.Match m WITH (NOLOCK)
	WHERE matchid = @MatchId	
	
	SELECT @procName = OBJECT_NAME(@@PROCID)
	
	IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = '0')
					AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
		BEGIN
			UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
					SET VValue = 1
			WHERE VName = 'isCalculatingParlay'
					
		END
		ELSE
		BEGIN
			SELECT	@ErrCode = 1000000
				,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
			RETURN	
		END

		BEGIN TRY
			EXEC [NAP_Admin_Settlement_Refund_MP] @matchid = @matchid
				,@creator 	= @AdminId
				,@action 	= @mode
				,@IP 		= @IP
				,@ErrCode 	= @ErrCode OUTPUT
				,@ErrMsg 	= @ErrMsg OUTPUT
		END TRY

		BEGIN CATCH
			SELECT @ErrMsg = ERROR_MESSAGE()
					,@ErrCode = @@ERROR
		END CATCH

		UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
			SET VValue = 0
		WHERE VName = 'isCalculatingParlay'
	END
	ELSE
	BEGIN		
		INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, Sporttype, BroadcastSessionId)
		SELECT @matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @mode, @sporttype, @BroadcastSessionId
	END
END
GO 

