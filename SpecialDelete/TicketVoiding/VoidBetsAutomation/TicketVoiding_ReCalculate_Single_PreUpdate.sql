/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
(
	@MatchId		 INT,	
	@TransIds		 VARCHAR(MAX),
	@UserId          INT           = 0,
    @IP              VARCHAR(15)   = NULL,
    @FailedTransIds  VARCHAR(MAX)  = '' OUTPUT,
    @ErrMsg          NVARCHAR(200) = '' OUTPUT,
    @ErrCode         INT           = 0 OUTPUT,
	@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
)
AS
/*	Created by: Max
	Date 20200212
	Task: Abnormal Void Bets Automation [Redmine: #128359]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Max: Create new SP [Redmine: #128359]	
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220307@Max: TVS - Miss update balance when update request abnormal mix parlay [Redmine: #169600]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@xmlTransId		VARCHAR(MAX)
			,@refnos_29				 VARCHAR(MAX) = '' 

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)

	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
	
	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,Refno				BIGINT
		,balanceType		TINYINT
		,betid				BIGINT
		,refcode			BIGINT
	)
	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
	)
	
	INSERT INTO @tmpInputTransId (TransId)
	SELECT	val AS TransId
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90503
	SET @SB_Error = 0
	SET @FailedTransIds = @TransIds
	SET @session = CAST(NEWID() AS NVARCHAR(50))

	INSERT INTO #tmpTransId(TransId, custid, bettype, balanceType, refcode, betid)
	SELECT	b.transid, b.custid, b.bettype
			,1 AS balanceType
			, b.RefCode, b.betid
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	WHERE	b.statusID <> 102

	IF NOT EXISTS (SELECT * FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'
		RETURN
	END

	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, transid)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid
	FROM	#tmpTransId t
	WHERE	t.refcode IS NOT NULL
	GROUP BY t.refcode, t.custid, t.bettype

	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId (TransId, custid, bettype, balanceType, refcode)
		SELECT b.TransId, b.custid, b.bettype, 1, b.refcode
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE b.transid = TransId)
	END

	SET @FailedTransIds = NULL
	SELECT	@FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(it.TransId AS VARCHAR(30)), CAST(it.TransId AS VARCHAR(30)))
	FROM	@tmpInputTransId it
	WHERE	NOT EXISTS (SELECT * FROM #tmpTransId c WHERE c.TransId = it.TransId)

	--capture balance before
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--ReCalculate
	BEGIN TRY						
		IF @MatchId = 29 
		BEGIN
			SET @refnos_29 =''
						SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
						FROM #tmpTransId  
						WHERE bettype = 29 
						GROUP BY refno, transid
						SET @refnos_29 = STUFF(@refnos_29,1,1,'')

			EXEC dbo.NAP_Admin_Calculate_MP_broker  
					@matchdate = ''  
					,@strXML = @refnos_29  
					,@mode  = '29'  
		END
		ELSE
		BEGIN
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									FROM	@tmpInputTransId t
									FOR XML PATH('r'), ROOT('root')
								)

			EXEC TicketVoiding_ReCalculate_Single_Update @TransIds = @xmlTransId
		END
	END TRY
	
	BEGIN CATCH
		
		INSERT INTO @AfterUpd(
			matchid
			,custid
			,balanceType		
			,walletType
			,bonusId
			,balance
		)
		SELECT	@matchid
				,b.custid
				,b.balanceType
				,b.WalletType
				,b.BonusID			
				,SUM(b.balance) AS balance
		FROM (	
			SELECT	b.custid
					,t.balanceType
					,CASE 
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
		)b
		GROUP BY b.custid
				,b.balanceType
				,b.BonusID
				,b.WalletType

		--UPDATE balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @beforeUpd
				, @BalanceWalletAfter	= @afterUpd
				, @ActionId				= 0
			
		SELECT @ErrCode = 100
			, @ErrMsg = 'Called TicketVoiding_ReCalculate_Single_Update with error.'
		
		RETURN	
			
	END CATCH
	
	-- Capture balance before
	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0
			
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	@BeforeUpd b
		INNER JOIN @AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	0 AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@MatchId AS '@MatchId'
							,@IP AS '@IP'
							,'TransId: ' + @TransIds 
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransId
END