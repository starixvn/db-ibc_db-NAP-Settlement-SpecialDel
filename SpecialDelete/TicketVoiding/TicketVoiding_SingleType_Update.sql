/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SingleType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)

	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

	DECLARE @avaiableProcess BIT
			,@isExistMG BIT
			,@isExistMatch BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			
			,@CustIdsCashOut VARCHAR(MAX)
			,@CustIdsBetTrade VARCHAR(MAX)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)		
	DECLARE @tmpCustCashOut TABLE (CustId INT)
	DECLARE @tmpCustBettrade TABLE (CustId INT)

	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,balanceType		TINYINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade, 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,isSubTransaction	BIT	DEFAULT(0)
	)
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0

	SET @session = CAST(NEWID() AS NVARCHAR(50))	

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	val AS TransId
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	INSERT INTO #tmpTransId(custid, bettype, KeyId, Refno, balanceType, TicketType)
	SELECT	tl.custid, tl.gameID, 3, tl.translogid, 4 AS balanceType, 5 -- Metric gaming
	FROM	@tmpInputTransId t
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON t.TransId = tl.translogid
	WHERE	tl.statusID <> 102			
	
	IF @@ROWCOUNT <> 0
		SET @isExistMG = 1
		
	INSERT INTO #tmpTransId(TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo)
	SELECT	b.transid, b.custid, b.bettype, 1 AS KeyId, 1 AS balanceType
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 0 AND b.ExtraInfo IS NULL THEN 4 				
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
	WHERE	b.statusID <> 102		

	IF @@ROWCOUNT <> 0
		SET @isExistMatch = 1

	IF NOT EXISTS (SELECT * FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 1
				,@ErrMsg = 'no ticket'				

		RETURN
	END
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@MatchId, KeyId
	FROM	#tmpTransId
	GROUP BY KeyId
	
	EXEC dbo.NAP_Admin_CheckingProcess
		 @isExistMG = @isExistMG
		, @isExistMatch	= @isExistMatch
		, @avaiableProcess = @avaiableProcess OUTPUT
		, @ErrCode = @ErrCode OUTPUT
		, @ErrMsg = @ErrMsg OUTPUT
		
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		SELECT	@ErrCode = 1
				,@ErrMsg = 'lock match'
				

		RETURN
	END

	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT	t.transid
	FROM	#tmpTransId t	
	WHERE	t.TicketType = 3

	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
		@Mode = 'Original'
		,@Action = 'Void'
		,@IsReleased = 0

	DELETE	t
	FROM	#tmpTransId t
		 INNER JOIN #tblCashOutProcess co
				 ON t.transid = co.transid					
					AND co.IsAvailable = 0

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId t)
	BEGIN
		SELECT	@ErrCode = 1
				,@ErrMsg = 'No ticket found.'

		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= @isExistMatch
			,@isExistMG = @isExistMG 
			,@IsReleased	= 1
			
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original' 
			  , @Action = 'Void'
			  , @IsReleased = 1				

		RETURN
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO #tmpTransId (TransId, Refno, bettype, TicketType, isSubTransaction)
		SELECT	sub.transid, sub.refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction
		FROM	#tmpTransId main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)
		
		-- cashout bet ticket, 912, 913
		INSERT INTO #tmpTransId(TransId, Refno, bettype, TicketType, isSubTransaction)
		SELECT	sub.TransId, sub.Refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction
		FROM	#tmpTransId sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)

		INSERT INTO @tmpCustCashOut(CustId)
		SELECT	t.custid
		FROM	#tmpTransId t
		WHERE	t.TicketType = 3
				AND t.bettype = 912
		GROUP BY t.custid
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 4)
	BEGIN
		INSERT INTO #tmpTransId(TransId, Refno, bettype, awinlost, isSubTransaction)
		SELECT	sub.transid, sub.refno, sub.bettype, sub.awinlost, 1 AS isSubTransaction
		FROM	#tmpTransId main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.bettype BETWEEN 901 AND 903
				AND sub.statusID IN (111, 112, 113, 103)
				AND main.betdaqid = 0
				AND main.ExtraInfo IS NULL

		INSERT INTO @tmpCustBettrade (CustId)
		SELECT	t.custid
		FROM	#tmpTransId t
		WHERE	t.TicketType = 4
				AND t.bettype = 902
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 5)
	BEGIN
		INSERT INTO [bodb02].[dbo].[bettrans]  (
				[custid]  
				,[transdate]  
				,[oddsid]  
				,[hdp1]  
				,[hdp2]  
				,[odds]  
				,[stake]  
				,[status]  
				,[winlost]  
				,[awinlost]  
				,[mwinlost]  
				,[playercomm]  
				,[comm]  
				,[acomm]  
				,[apositiontaking]  
				,[mpositiontaking]  
				,[tpositiontaking]  
				,[playerdiscount]  
				,[discount]  
				,[adiscount]  
				,[livehomescore]  
				,[liveawayscore]  
				,[liveindicator]  
				,[betteam]  
				,[creator]  
				,[refno]  
				,[comstatus]  
				,[winlostdate]  
				,[betfrom]  
				,[betcheck]  
				,[checktime]  
				,[oddsspread]  
				,[actualrate]  
				,[matchid]  
				,[recommend]  
				,[mrecommend]  
				,[ruben]  
				,[betid]  
				,[statuswinlost]  
				,[modds]  
				,[bettype]  
				,[betdaqid]  
				,[actual_stake]  
				,[currency]  
				,[ip]  
				,[transdesc]  
				,[sdiscount]  
				,[scomm]  
				,[spositiontaking]  
				,[swinlost]  
				,[srecommend]  
				,[Username]  
				,[CurrencyName]  
				,[virtualrate]  
				,[oddstype]  
				,[statusID]  
				,[currency2]  
				,[balance]  
				,[SecAcceptFlag]  
				,[transid2]  
				,[RecommDate]
		)  
		SELECT	tl.[custid]  
				,tl.[transdate]  
				,0 [oddsid]  
				,0 [hdp1]  
				,0 [hdp2]  
				,tl.[odds]  
				,tl.[stake]  
				,tl.[status]  
				,0 [winlost]  
				,0 [awinlost]  
				,0 [mwinlost]  
				,0 [playercomm]  
				,0 [comm]  
				,0 [acomm]  
				,tl.[apositiontaking]  
				,tl.[mpositiontaking]  
				,tl.[tpositiontaking]  
				,tl.[playerdiscount]  
				,tl.[discount]  
				,tl.[adiscount]  
				,0 [livehomescore]  
				,0 [liveawayscore]  
				,tl.[liveindicator]  
				,SUBSTRING(tl.[transdesc],11,CHARINDEX(';BettypeTime',tl.[transdesc],0) - 11) [betteam]  
				,tl.[creator]  
				,tl.translogid [refno]  
				,tl.custom2 [comstatus]  
				,tl.[winlostdate]  
				,tl.[betfrom]  
				,tl.transdate [betcheck]  
				,NULL [checktime]  
				,0 [oddsspread]  
				,tl.[actualrate]  
				,tl.EventID  
				,tl.[recommend]  
				,tl.[mrecommend]  
				--,1 [ruben]  
				,0 [ruben] --#94603
				,CASE WHEN ISNULL(tl.custom3,'') = '' THEN NULL ELSE CAST(tl.custom3 AS BIGINT) END [betid]  
				,NULL [statuswinlost]  
				,0 [modds]  
				,tl.GameID [bettype]  
				,NULL [betdaqid]  
				--,b.[actual_stake] --#94603 
				,0 [actual_stake]
				,tl.[currency]  
				,tl.[ip]  
				,tl.[transdesc]  
				,tl.[sdiscount]  
				,0 [scomm]  
				,tl.[spositiontaking]  
				,0 [swinlost]  
				,tl.[srecommend]  
				,tl.[Username]  
				,tl.[CurrencyName]  
				,tl.[virtualrate]  
				,tl.custom1 [oddstype]  
				,tl.[statusID]  
				,NULL [currency2]  
				,tl.[balance]  
				,0 [SecAcceptFlag]  
				,0 [transid2]  
				,NULL [RecommDate] 				
			FROM #tmpTransId t
				INNER JOIN dbo.translog tl WITH(NOLOCK)  
					ON tl.translogid = t.Refno
			WHERE NOT EXISTS (
					SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK) 
					WHERE b.custid = tl.custid 
						AND b.refno = tl.translogid 
						AND b.matchid = tl.eventID
				)

		UPDATE  t
			SET TransId = b.transid
				,betid = ISNULL(b.BetID, rs.ResultID)
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.Refno = b.refno
					AND b.matchid = @MatchId
					AND b.bettype = t.bettype
					AND b.custid = t.custid
			OUTER APPLY (
				SELECT	rs.ResultID
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)
				WHERE	(
							(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0)
							OR b.bettype = 806
						)
						AND rs.GameID = b.bettype	
						AND rs.VendorID = 5		
						AND rs.MatchID = b.matchid	
			) rs
		WHERE	t.TicketType = 5

	END

	-- backup into zzzbettrans
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
			,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
			,betteam, creator, refno, winlostdate, betfrom
			,betcheck
			,comstatus
			,checktime, matchid, bettype  
			,VoidingHistoryId
		)  
	SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
		,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
		,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
		,CASE 
			WHEN t.TicketType = 3 AND b.bettype NOT BETWEEN 911 AND 913 THEN @session 
			ELSE b.betcheck END AS betcheck -- original ticket & cashout bet ticket
		,b.comstatus
		,b.checktime, b.matchid, b.bettype  
		,@VoidingHistoryId
	FROM	#tmpTransId AS t WITH (NOLOCK)  
		INNER JOIN dbo.bettrans b WITH (NOLOCK)  
			ON b.transid = t.TransId

	-- capture balance before voiding
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
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914

		UNION ALL
		SELECT	b904.custid
				,1 AS balanceType
				,0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				,2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				,b904.winlost - b904.actual_stake + b904.playercomm AS balance
		FROM	@tmpCustBettrade c
			INNER JOIN bettrans b904 WITH (NOLOCK)
				ON	b904.matchid = @MatchId
					AND b904.custid = c.CustId
					AND b904.bettype = 904
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	SELECT @xmlTransId = (SELECT	t.TransId AS '@transid'
									,CASE WHEN t.TicketType = 5 THEN t.Refno ELSE NULL END AS '@translogid'
									,t.betid AS '@betid'
									,CASE WHEN t.TicketType = 5 THEN 1 ELSE NULL END AS '@isMG'
							FROM	#tmpTransId t
							FOR XML PATH('r'), ROOT('root')
						)
						
	EXEC dbo.TicketVoiding_Admin_VoidingTransId 
		@TransIds = @xmlTransId
		,@UserId = @UserId

	-- PRE CAL 914
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId t WHERE t.TicketType = 3)
	BEGIN
		BEGIN TRY				
			SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(c.CustId AS VARCHAR(50))
											FROM	@tmpCustCashOut c						    
											FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')	
																					    
			EXEC dbo.NAP_Admin_Calculate_914 
					@MatchId 	= @MatchID
					,@Action 	= 'VOID'
					,@CustIds 	= @CustIdsCashOut				
		END TRY 
		BEGIN CATCH
			SELECT @ErrCode = 914
					, @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
		END CATCH
	END

	-- PRE CAL 904
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE TicketType = 4)
	BEGIN
		BEGIN TRY
			SET @CustIdsBetTrade = STUFF((SELECT ',' + CAST(c.custid AS VARCHAR(50))
									FROM	@tmpCustBettrade c 
									FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
			
			EXEC dbo.NAP_Admin_Calculate_904 
				@MatchId 	= @MatchId
				,@Action 	= 'VOID'
				,@CustIds 	= @CustIdsBetTrade
						
		END TRY
		BEGIN CATCH
			SELECT	@ErrCode = 904
					,@ErrMsg = 'Called NAP_Admin_Calculate_904 with error.'
		END CATCH
	END

	-- PRE CAL 501 Cricket - charge comm
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 501)
	BEGIN
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))		
		BEGIN TRY
			DECLARE @CustIdsCricket VARCHAR(MAX)

			SET @CustIdsCricket = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
										FROM	#tmpTransId t where t.bettype = 501
										FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')

			EXEC dbo.NAP_Admin_Calculate_500 
				@MatchId = @MatchId
				,@Action = 'VOID'
				,@CustIds = @CustIdsCricket
		END TRY 
		BEGIN CATCH
			SELECT	@ErrCode = 500
				,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
		END CATCH
	END

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
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		
		UNION ALL
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914

		UNION ALL
		SELECT	b904.custid
				,1 AS balanceType
				,0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				,2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				,b904.winlost - b904.actual_stake + b904.playercomm AS balance
		FROM	@tmpCustBettrade c
			INNER JOIN bettrans b904 WITH (NOLOCK)
				ON	b904.matchid = @MatchId
					AND b904.custid = c.CustId
					AND b904.bettype = 904
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

	UPDATE odds  
		SET hometotal = hometotal - (CASE WHEN b.betteam = 'h' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
			   ELSE 0 END )  
		,awaytotal = awaytotal - (CASE WHEN b.betteam = 'a' THEN CASE WHEN abs(b.odds) > 1 THEN b.stake * e.actualrate * abs(b.odds) * (1 - b.tpositiontaking)  
					  ELSE b.stake * e.actualrate * (1 - b.tpositiontaking) END  
				ELSE 0 END)  
		FROM dbo.odds o WITH (ROWLOCK,UPDLOCK)  
			INNER JOIN dbo.bettrans b WITH (NOLOCK) 
				ON o.matchid = b.matchid AND o.oddsid = b.oddsid  
			INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) 
				ON c.custid = b.custid  
			INNER JOIN CustDB.dbo.exchange e WITH (NOLOCK) 
				ON c.currency = e.exchangeid  
		
		WHERE	b.matchid = @MatchId
			AND EXISTS ( 
				SELECT TOP 1 1   
				FROM #tmpTransId AS t
				WHERE t.TransID  = b.transid
					AND t.Bettype IN (1,3,7,8)				
		   ) 

	-- Update BetTradeSellingCancelled information
	SELECT	@CustIds = CAST(t.custid AS VARCHAR(20)) + ','
	FROM	#tmpTransId t
	WHERE	t.custid IS NOT NULL
	GROUP BY t.custid

	EXEC dbo.TicketVoiding_BalanceMember_Select 
		@CustIds = @CustIds
		,@CustBalance = @CustBalance OUTPUT

	INSERT INTO @tmpBalanceMember (CustId, Balance)
	SELECT	T.C.value('./@c', 'int')
			,T.C.value('./@b', 'money')
	FROM	@CustBalance.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustBalance = NULL ))

	;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' AS [Remark]
					,sub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,c.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM	#tmpTransId sub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = sub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN sub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = sub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN @tmpBalanceMember c
						 ON sub.custid = c.custid						 							
			WHERE sub.BetType IN (901,911)			  
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE TicketType = 5)
	BEGIN		
		INSERT INTO dbo.BettradeAPI (
					transid
					,matchid
					,[Session]
					,[action]
					,buybackNo
					,Payout
					,Remark
			)
		SELECT	b.TicketID
				,b.MatchID
				,@session
				,'VOID'
				,b.BuyBackNo
				,b.PayOut
				,'SB void ticket due to ' 
		FROM	#tmpTransId t
			INNER JOIN dbo.BetTradeSelling b WITH(NOLOCK)
				ON t.TransId = b.TicketID
		WHERE	t.TicketType = 5
			AND b.[Status] IN ('Accept', 'Confirm')
	END

	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch = @isExistMatch
		,@isExistMG	= @isExistMG
		, @IsReleased = 1

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ' Single ticket with TransId: ' + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

