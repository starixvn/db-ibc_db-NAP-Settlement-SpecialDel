/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementService_Calculation]
	@TransInfo			XML				= NULL
	,@TableName			VARCHAR(128) 
	,@MatchId			INT				= 0
	,@Action			VARCHAR(1)		= 'U'
	,@SettlementAction	VARCHAR(20)		= NULL
	,@TicketType		VARCHAR(1)		= NULL
	,@ErrCode			INT				= 0	 OUTPUT
	,@ErrMsg			VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20201123@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE 	@matchdate		SMALLDATETIME
			,@strTransIds	VARCHAR(MAX)
	BEGIN TRY
		/* Sync for some tables when void bettrans14: bettrans14, Transfer, TicketVoiding_RoutineTasks */
		IF @TableName IN ('Transfer', 'TicketVoiding_RoutineTasks') AND @Action = 'I'
		BEGIN
			EXEC dbo.NAP_SyncService_NotExecRep
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
		END
		ELSE IF @TableName = 'bettrans14'
		BEGIN
			EXEC dbo.Bet_ExecRep14_04
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
					,@MatchId = @MatchId
					,@SettlementAction = @SettlementAction
					,@TicketType = @TicketType
		END
		ELSE IF @TableName = 'Transfer' AND @Action =  'U'
		BEGIN
			EXEC dbo.Transfer_ExecRep_04
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
					,@MatchId = @MatchId
					,@SettlementAction = @SettlementAction
					,@TicketType = @TicketType
		END
		/*---------------------------------------------------------------------------------------------*/
		ELSE
		BEGIN
			EXEC dbo.ExecRep_NAP_Admin_04 
					@TransInfo = @TransInfo
					,@TableName = @TableName
					,@Action = @Action
					,@MatchId = @MatchId
					,@SettlementAction = @SettlementAction
					,@TicketType = @TicketType
		END
	END TRY
	BEGIN CATCH
		SET @ErrCode = 100

		SET @ErrMsg = ERROR_MESSAGE()

		RETURN
	END CATCH
END