/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AccountWinLost_Update]
(
	@RequestId	INT = 0
	,@ActionId	TINYINT = 0
	,@AccountWinLostXml VARCHAR(MAX) = '' 
)
AS
/*	
	Creator: 20231109@Max
	Task: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
	
	Revisions:
		- 20231109@Max: Create SP [Redmine:#194140]
*/
BEGIN

    SET NOCOUNT ON;

	--Clear data in case change action void
	IF @ActionId <> 10
	BEGIN
		DELETE acc
		FROM dbo.TicketVoiding_AbnormalAccountVoidAmount acc
		WHERE acc.RequestId = @RequestId

		RETURN
	END
	
	DECLARE @xmlAccountWinLost XML = NULL

	CREATE TABLE #tblAccountWinlost (
		RequestID				INT
		,CustId				    INT
		,GivenCredit			MONEY 
		,AdjustVoidLimit		MONEY 
		,CurrentWinning			MONEY 
		,CurrentLosing			MONEY 
		,EstimateVoidAmount		MONEY 
		,WinLostAfterVoid		MONEY 
	)

	SET @xmlAccountWinLost = CONVERT(XML, @AccountWinLostXml)
	INSERT INTO #tblAccountWinlost( 
			RequestID					
			,CustId				    
			,GivenCredit			 
			,AdjustVoidLimit		 
			,CurrentWinning			 
			,CurrentLosing			 
			,EstimateVoidAmount		 
			,WinLostAfterVoid		 
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@CustId','INT') 
			,t.c.value('@GivenCredit','MONEY') 
			,t.c.value('@AdjustVoidLimit','MONEY') 
			,t.c.value('@CurrentWinning','MONEY') 
			,t.c.value('@CurrentLosing','MONEY') 
			,t.c.value('@EstimateVoidAmount','MONEY')
			,t.c.value('@WinLostAfterVoid','MONEY')
	FROM @xmlAccountWinLost.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@xmlAccountWinLost  = NULL))

	--DELETE NOT EXISTS DATA
	DELETE acc
	FROM dbo.TicketVoiding_AbnormalAccountVoidAmount acc
	WHERE acc.RequestId = @RequestId
		AND acc.custid NOT IN (SELECT CustId FROM #tblAccountWinlost)

	--UPDATE EXISTS DATA
	UPDATE acc SET
		acc.GivenCredit = tmp.GivenCredit
		,acc.AdjustLimit = tmp.AdjustVoidLimit
		,acc.CurrLosing = tmp.CurrentLosing
		,acc.CurrWinning = tmp.CurrentWinning
		,acc.EstVoidAmount = tmp.EstimateVoidAmount
		,acc.WinlostAfterVoid = tmp.WinLostAfterVoid
		,acc.ModifiedDate = GETDATE()
	FROM dbo.TicketVoiding_AbnormalAccountVoidAmount acc WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tblAccountWinlost tmp ON tmp.RequestID = acc.RequestId AND acc.custid = tmp.CustId

	--INSERT NEW DATA
	INSERT INTO dbo.TicketVoiding_AbnormalAccountVoidAmount
	(
		RequestId
		,custid
		,GivenCredit
		,AdjustLimit
		,CurrLosing
		,CurrWinning
		,EstVoidAmount
		,WinlostAfterVoid
	)
	SELECT tmp.RequestID
		,tmp.CustId
		,tmp.GivenCredit
		,tmp.AdjustVoidLimit
		,tmp.CurrentLosing
		,tmp.CurrentWinning
		,tmp.EstimateVoidAmount
		,tmp.WinLostAfterVoid
	FROM #tblAccountWinlost tmp
		LEFT JOIN dbo.TicketVoiding_AbnormalAccountVoidAmount acc WITH (NOLOCK) ON acc.RequestId = tmp.RequestID AND acc.custid = tmp.CustId
	WHERE acc.RequestId IS NULL

	DROP TABLE #tblAccountWinlost
END
