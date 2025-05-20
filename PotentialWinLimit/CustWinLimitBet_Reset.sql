/*<info serverAlias="DBSIC-bodb02" executers="wsv_alp" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE CustWinLimitBet_Reset (
	@ListCustId	VARCHAR(MAX) = ''
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
*/
BEGIN
	DECLARE @tmpCustIds TABLE ( CustID INT )
	DECLARE @tmpOldAccumnWinLoss TABLE ( CustID INT PRIMARY KEY, OldAccumnWinLoss MONEY )

	IF ISNULL(@ListCustID,'') = ''
	BEGIN
		SET @ErrCode = 1
		SET @ErrMsg = 'No Data!'
		RETURN;
	END

	BEGIN TRY
		INSERT INTO @tmpCustIds ( CustID )
		SELECT CAST([value] AS INT) FROM STRING_SPLIT(@ListCustId,',')

		UPDATE b	
		SET AccumWinLoss = 0
			,RepUpdateTime = [dbo].[f_GetDateTime2]() 
		OUTPUT deleted.CustID, deleted.AccumWinLoss
		INTO @tmpOldAccumnWinLoss ( CustID, OldAccumnWinLoss)
		FROM CustWinLimitBet b WITH(ROWLOCK,UPDLOCK)
		INNER JOIN @tmpCustIds c ON b.CustID = c.CustID

		INSERT INTO CustWinLimitBet_History (CustID, Transid, AdjToWin, AdjWinLoss, SportType, Bettype, ActionType, RepUpdateTime)
		SELECT tmp.CustId, NULL, 0, -tmp.OldAccumnWinLoss, NULL, NULL, 100, [dbo].[f_GetDateTime2]() 
		FROM @tmpOldAccumnWinLoss tmp

	END TRY
	BEGIN CATCH
		SET @ErrCode = ERROR_NUMBER()
		SET @ErrMsg = ERROR_MESSAGE()
	END CATCH


END
GO


