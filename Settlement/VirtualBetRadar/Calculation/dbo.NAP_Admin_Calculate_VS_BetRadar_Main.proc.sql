/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Main]	
	@matchid 		INT				= 0
	,@SportType		INT				= 0
	,@mode 			VARCHAR(10)		= 'CAL'
	,@CALBettypes 	VARCHAR(MAX)	= NULL
	,@maxTransId	BIGINT			= 0
	,@ActionID		TINYINT			= 0
	,@TicketInfos 	VARCHAR(MAX)	= NULL
	,@IsBalance		BIT 			= 1
	,@CWLBettype	SMALLINT 		= 2701
	,@ErrCode		INT				= 0		OUTPUT
	,@ErrMsg		NVARCHAR(200)	= ''	OUTPUT
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]

	Param's Explanation:
	• @Mode:
		CAL : All single BetTypes (HT-FT)
		RECOVER : Re-settle single ticket
	• @TicketInfos : 
		meaning : single transids (bettrans.transid)	
		format xml : <root><r m="1234" t="2333" /></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @xmlBettype		XML
		, @xmlTicket		XML
		, @commWinRate 		SMALLMONEY
		, @commLostRate 	SMALLMONEY
		, @batchCount		INT
		, @BalanceCount     INT
		, @balanceUpd		VARCHAR(MAX)
		, @BalanceType		TINYINT
		, @balanceAcc 		VARCHAR(MAX)
		, @GroupID			INT
		
	DECLARE @tempBettype 	TABLE (bettype SMALLINT, CalMode TINYINT)
	DECLARE @BetTickets  	TVP_Settlement_BetTicket
	
	CREATE TABLE #tblTicketInfos (matchid int, transid BIGINT)		
	
	CREATE TABLE #tblMatchResult
	(
		matchid INT, 
		fth INT, 
		fta INT, 
		hth INT, 
		hta INT,
		sporttype TINYINT
	)
	
	CREATE TABLE #TempData (
		[recommend] 		[INT]
		, [matchid] 		[INT]
		, [custid] 			[INT]
		, [bettype] 		[SMALLINT]
		, [transid] 		[BIGINT]
		, [actual_stake] 	[MONEY]
		, [stake] 			[MONEY]
		, [odds] 			[SMALLMONEY]
		, [comstatus] 		[NVARCHAR](20)
		, [betteam] 		[nvarchar](10)
		, [apositiontaking] [SMALLMONEY]
		, [mpositiontaking] [SMALLMONEY]
		, [spositiontaking] [SMALLMONEY]
		, [playerdiscount] 	[DECIMAL](9, 8)
		, [discount] 		[DECIMAL](9, 8)
		, [adiscount] 		[DECIMAL](9, 8)
		, [sdiscount] 		[DECIMAL](9, 8)
		, [WinLost] 		[MONEY]
		, [aWinLost] 		[MONEY]
		, [mWinLost] 		[MONEY]
		, [sWinLost] 		[MONEY]
		, [PlayerComm] 		[MONEY]
		, [comm] 			[MONEY]
		, [acomm] 			[MONEY]
		, [scomm] 			[MONEY]
		, [StatusID] 		[TINYINT]
		, [modds] 			[SMALLMONEY]
	)
	
	--SET Ignore DB-Servers
	SELECT @ErrCode 		= 0
			, @ErrMsg  		= ''
			, @batchCount 	= 2000
			, @BalanceType 	= 4 --Others 3rd products
			, @balanceAcc	= ''
			, @GroupID		= 7 --VS Betradar
	
	
	--CONVERT bettype
	SET @xmlBettype = CONVERT(XML, @CALBettypes)			
	
	;WITH CTE_Bettype AS (
		SELECT T.C.value('./@t', 'SMALLINT') AS bettype
		FROM @xmlBettype.nodes('/root/r') AS T(C)
	)
	INSERT INTO @tempBettype (bettype, CalMode)
	SELECT temp.bettype, f.CalMode
	FROM CTE_Bettype temp
		INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f
		ON temp.bettype = f.bettype
	WHERE @mode = 'CAL' 
		AND f.SportType = @SportType
	OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))			
	
	--CONVERT Ticket
	SET @xmlTicket = CONVERT(XML, @TicketInfos)
	
	INSERT INTO #tblTicketInfos(matchid, transid)
	SELECT T.C.value('./@m', 'INT') as matchid
		 , T.C.value('./@t', 'BIGINT') as transid					
	FROM @xmlTicket.nodes('/root/r') as [T](C) --T: table, C: column	
	WHERE @Mode = 'RECOVER'
	OPTION (OPTIMIZE FOR (@xmlTicket = NULL ))	
	
	-- build match list
	;WITH CTE_MatchID AS
	(
		SELECT @matchid AS matchid WHERE @mode = 'CAL'
		UNION ALL
		SELECT DISTINCT matchid FROM #tblTicketInfos WHERE @mode = 'RECOVER'
	)	
	INSERT INTO #tblMatchResult(matchid, fth, fta, hth, hta, sporttype)
	SELECT matchid
		, FinalHomeScore
		, FinalAwayScore
		, HTHomeScore
		, HTAwayScore
		, sporttype
	FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
	WHERE matchid IN (SELECT matchid FROM CTE_MatchID)			
		
	IF (@@ROWCOUNT = 0) RETURN		
	
	--SELECT tickets for calculating
	IF @mode = 'CAL'
	BEGIN	
		INSERT INTO #TempData(recommend, matchid, custid, bettype,
			transid, actual_stake, stake, odds, comstatus, 
			--betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, modds
		)
		SELECT	b.recommend, b.matchid, b.custid, b.bettype,
			transid, actual_stake, stake, odds, comstatus, 
			--betteam, hdp1, hdp2, livehomescore, liveawayscore,
			apositiontaking, mpositiontaking, spositiontaking, 
			playerdiscount,discount, adiscount, sdiscount,
			WinLost, aWinLost, mWinLost, sWinLost, 
			PlayerComm, comm, acomm, scomm,
			StatusID, ods.modds						
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN #tblMatchResult mr 
				ON b.matchid = mr.matchid
			INNER JOIN @tempBettype AS temp
				ON b.bettype = temp.bettype
			OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds (
				b.bettype 			
				, b.betteam 			
				, b.hdp1 			
				, b.hdp2 			
				, b.livehomescore	
				, b.liveawayscore	
				, mr.fth				
				, mr.fta				
				, mr.hth				
				, mr.hta
				, temp.CalMode
			) AS ods
			
		WHERE b.matchid 	= @matchid 
			AND b.statusID NOT IN (101,102) --void/reject
			AND b.transid <= @maxTransId
	END			
	ELSE IF @mode = 'RECOVER'
	BEGIN			
		INSERT INTO #TempData(recommend, matchid, custid, bettype,
				b.transid, actual_stake, stake, odds, comstatus, 
				--betteam, hdp1, hdp2, livehomescore, liveawayscore,
				apositiontaking, mpositiontaking, spositiontaking, 
				playerdiscount,discount, adiscount, sdiscount,
				WinLost, aWinLost, mWinLost, sWinLost, 
				PlayerComm, comm, acomm, scomm,
				StatusID, modds)
		SELECT	b.recommend, b.matchid, b.custid, b.bettype,
				b.transid, actual_stake, stake, odds, comstatus, 
				--betteam, hdp1, hdp2, livehomescore, liveawayscore,
				apositiontaking, mpositiontaking, spositiontaking, 
				playerdiscount,discount, adiscount, sdiscount,
				WinLost, aWinLost, mWinLost, sWinLost, 
				PlayerComm, comm, acomm, scomm,
				StatusID, ods.modds					
		FROM dbo.bettrans b WITH(ROWLOCK)
			INNER JOIN #tblMatchResult mr 
				ON b.matchid = mr.matchid
			INNER JOIN #tblTicketInfos t 
				ON b.transid = t.transid
			INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f
				ON b.bettype = f.bettype
					AND mr.sporttype = f.SportType		
			OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds (
				  b.bettype 			
				, b.betteam 			
				, b.hdp1 			
				, b.hdp2 			
				, b.livehomescore	
				, b.liveawayscore	
				, mr.fth				
				, mr.fta				
				, mr.hth				
				, mr.hta
				, f.CalMode
			) AS ods
		WHERE b.statusID NOT IN (101,102) --void/reject	
	END						

	IF @@ROWCOUNT = 0 RETURN		
	
	UPDATE #TempData
	SET 
		@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
			WHEN '0' THEN 1
			WHEN '1' THEN 0 
			ELSE 1 END,
		@commLostRate = CASE comstatus
			WHEN '0' THEN 1
			WHEN '1' THEN 2 
			ELSE 1 END, 
		
		WinLost = CASE
				WHEN modds >  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end)
				WHEN modds =  0.25	THEN actual_stake + stake * (case when odds<0 then 1 else odds end) * 0.5
				WHEN modds =  0	THEN actual_stake
				WHEN modds = -0.25	THEN actual_stake * 0.5
				WHEN modds < -0.25	THEN 0
			END,

		aWinLost = CASE
				WHEN modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
				WHEN modds =  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking * 0.5
				WHEN modds =  0	THEN 0
				WHEN modds = -0.25	THEN actual_stake * apositiontaking * 0.5
				WHEN modds < -0.25	THEN actual_stake * apositiontaking
			END,
		mWinLost = CASE
				WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
				WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN modds < -0.25 THEN actual_stake * mpositiontaking
			END,
		sWinLost = CASE
				WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
				WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN modds < -0.25 THEN actual_stake * spositiontaking
			END,

		PlayerComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * playerdiscount * stake
				WHEN modds =  0.25 THEN @commWinRate * playerdiscount * stake * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
				WHEN modds < -0.25 THEN @commLostRate * playerdiscount * stake
			END,
		Comm = CASE
				WHEN modds >  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
				WHEN modds =  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
			END,
		aComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
				WHEN modds =  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
			END,
		sComm = CASE
				WHEN modds >  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
				WHEN modds =  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN modds =  0    THEN 0
				WHEN modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
				WHEN modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
			END,
		StatusID = CASE
			WHEN modds > 0 THEN 112 --WON
			WHEN modds = 0 THEN 111 --DRAW
			WHEN modds < 0 THEN 113 --LOSE
		END	

	--UPDATE tickets by batch
	
	BEGIN TRY	
		WHILE (1 = 1)
		BEGIN
		
			SET @balanceUpd = NULL
			DELETE @BetTickets
			
			DELETE TOP (@batchCount) #TempData
			OUTPUT deleted.recommend, deleted.matchid, deleted.custid, deleted.bettype, deleted.transid
				, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost
				, deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm
				, deleted.statusid, deleted.modds, deleted.actual_stake	
			INTO @BetTickets(recommend, matchid, custid, bettype, transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actual_stake)	
			
			IF @@ROWCOUNT = 0 BREAK
			
			EXEC dbo.NAP_Admin_Calculate_Bettrans
				@BetTickets		= @BetTickets	
				,@CWLBettype	= @CWLBettype
				,@balanceUpd 	= @balanceUpd OUTPUT
				,@ErrCode 		= @ErrCode OUTPUT
				,@ErrMsg 		= @ErrMsg OUTPUT
			
			--tracing updated balance ACC
			IF(@balanceUpd IS NOT NULL)
			BEGIN
				SET @balanceAcc += @balanceUpd
			END			
			
			IF (@ErrCode > 0 ) BREAK
		END
	END TRY
	BEGIN CATCH
	
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
		
	END CATCH
	
	-- Settlement balance process
	IF(@IsBalance = 1)
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_BalanceProcess
			@BalanceAcc				= @balanceAcc
			, @BalanceType			= @BalanceType
			, @actionId				= @actionId
			, @MatchID				= @MatchID
			, @GroupID				= @GroupID		
	END
END
GO