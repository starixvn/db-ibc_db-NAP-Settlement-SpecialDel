/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp,wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE Acc_CustWinLimitBet_Reset (
	@ListCustId		VARCHAR(MAX) = ''
	,@ErrCode		INT		= 0		OUTPUT
	,@ErrMsg		VARCHAR(MAX) = '' OUTPUT

)
AS
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  Potential Winning Limit/Threshold [Redmine:#226060]
		- 20250714@July: Phase 2 - Support SMP, Parlay Tickets (include single ticket of Parlay Lucky) - [Redmine: #232605]

	Note param:
		@ListCustId =  [{"CustId":"1","ResetType":"0"},{"CustId":"2","ResetType":"1"}]
				ResetType = 0 --all (single + parlay), 1 --parlay 
*/
BEGIN
	SET NOCOUNT ON
	SET XACT_ABORT ON

	DECLARE @tmpCustIds TABLE ( CustID INT, ResetType INT)

	IF ISNULL(@ListCustID,'') = ''
	BEGIN
		SET @ErrCode = 1
		SET @ErrMsg = 'No Data!'
		RETURN;
	END

	BEGIN TRY
		INSERT INTO @tmpCustIds ( CustID, ResetType )
		SELECT CustId, ResetType
		FROM OPENJSON(@ListCustId) 
		WITH(CustId INT, ResetType INT)
		
		IF EXISTS(SELECT TOP 1 1 FROM @tmpCustIds WHERE ResetType = 0) --Single
		BEGIN
			UPDATE b	
			SET AccumWinLoss = 0
				,RepUpdateTime = [dbo].[f_GetDateTime2]() 
			OUTPUT deleted.CustID, NULL, 0, -deleted.AccumWinLoss, 0, 0, 100, [dbo].[f_GetDateTime2]() 
			INTO CustWinLimitBet_History (CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime)
			FROM CustWinLimitBet b WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @tmpCustIds c ON b.CustID = c.CustID 
			WHERE c.ResetType = 0 AND b.SportType = 0 AND b.Bettype = 0
		END
		
		IF EXISTS(SELECT TOP 1 1 FROM @tmpCustIds WHERE ResetType IN (0,1)) --Parlay
		BEGIN
			UPDATE b	
			SET AccumWinLoss = 0
				,RepUpdateTime = [dbo].[f_GetDateTime2]() 
			OUTPUT deleted.CustID, NULL, 0, -deleted.AccumWinLoss, 0, 29, 100, [dbo].[f_GetDateTime2]() 
			INTO CustWinLimitBet_History (CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime)
			FROM CustWinLimitBet b WITH(ROWLOCK,UPDLOCK)
				INNER JOIN @tmpCustIds c ON b.CustID = c.CustID 
			WHERE c.ResetType IN (0,1) AND b.SportType = 0 AND b.Bettype = 29
		END

	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SET @ErrMsg = ERROR_MESSAGE()
	END CATCH


END
GO


