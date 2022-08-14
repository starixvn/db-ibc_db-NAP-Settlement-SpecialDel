/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Main]	
	@matchid 		INT				= 0
	,@SportType		INT				= 0
	,@mode 			VARCHAR(10)		= 'CAL'
	,@CALBettypes 	VARCHAR(MAX)	= NULL
	,@maxTransId	BIGINT			= 0
	,@ActionID		TINYINT			= 0
	,@TicketInfos 	VARCHAR(MAX)	= NULL
	,@IsBalance		BIT 			= 1
	,@CWLBettype	SMALLINT 		= 1201
	,@ResourceIDs	VARCHAR(200)	= ''
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
		- 20170829@Kathy: Change datatype of sporttype [Redmine:#73545]
		- 20180207@Helen: Betradar VS 2 - basketball [Redmine:#90154] 
		- 20181212@Alan: Integrate Betradar VS phase 3 [106158]
		- 20200324@Helen: Betradar VS 4 -  [Redmine:#130984] 
		- 20200409@Helen: Virtual Soccer Euro Cup  -  [Redmine:#132048]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:
		- ? @Mode:
			CAL : All single BetTypes (HT-FT)
			RECOVER : Re-settle single ticket
		- ? @TicketInfos : 
			meaning : single transids (bettrans.transid)	
			format xml : <root><r m="1234" t="2333" /></root>
		- @ResourceIDs: Used for basketball only (280920,280940,280960)	
	
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @xmlBettype			XML
		, @xmlTicket			XML
		, @commWinRate 			SMALLMONEY
		, @commLostRate 		SMALLMONEY
		, @batchCount			INT
		, @BalanceCount			INT
		, @balanceUpd			VARCHAR(MAX)
		, @BalanceType			TINYINT
		, @balanceAcc 			VARCHAR(MAX)
		, @GroupID				INT
		, @ResourceResult		VARCHAR(200) = ''
		, @fth					INT
		, @fta					INT
		, @hth					INT
		, @hta					INT
		, @IsCentral			BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		
	DECLARE @tempBettype 	TABLE (bettype SMALLINT, CalMode TINYINT)
	DECLARE @BetTickets  	TVP_Settlement_BetTicket
	
	CREATE TABLE #tblTicketInfos (matchid int, transid BIGINT)		
	
	CREATE TABLE #tblMatchResult
	(
		matchid INT PRIMARY KEY, 
		fth INT, 
		fta INT, 
		hth INT, 
		hta INT,
		sporttype SMALLINT,
		ResourceResult VARCHAR(MAX)
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
			
	BEGIN TRY	
		-------------------STARTING: Result PREPARATION ----------------------
		IF @mode = 'CAL'
		BEGIN
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
			WHERE f.SportType = @SportType
			OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))			
		
			SELECT 
				 @fth = FinalHomeScore
				,@fta = FinalAwayScore
				,@hth = HTHomeScore
				,@hta = HTAwayScore
			FROM DBPRO.BODB02.dbo.Match WITH (NOLOCK)
			WHERE matchid = @matchid
			
			IF @SportType = 193
			BEGIN
				SELECT	 @ResourceResult = @ResourceResult + CASE WHEN ResourceID LIKE '2809__' THEN RIGHT(ResourceID,2) + Custom1 +',' ELSE '' END 
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd WITH (NOLOCK)
				WHERE	MatchID = @MatchID 
					AND SettlementStatusID = 4
					AND ResourceID IN (SELECT [value] FROM STRING_SPLIT(@ResourceIDs,','))
			END
		END
		ELSE IF @mode = 'RECOVER' AND @TicketInfos IS NOT NULL
		BEGIN
			
			--CONVERT Ticket
			SET @xmlTicket = CONVERT(XML, @TicketInfos)
			INSERT INTO #tblTicketInfos(matchid, transid)
			SELECT T.C.value('./@m', 'INT') as matchid
				 , T.C.value('./@t', 'BIGINT') as transid					
			FROM @xmlTicket.nodes('/root/r') as [T](C) --T: table, C: column	
			WHERE @Mode = 'RECOVER'
			OPTION (OPTIMIZE FOR (@xmlTicket = NULL ))	
			
			;WITH CTE_MatchID AS
			(
				SELECT DISTINCT matchid FROM #tblTicketInfos WHERE @mode = 'RECOVER'
			)	
			
			INSERT INTO #tblMatchResult(matchid, fth, fta, hth, hta, sporttype,ResourceResult)
			SELECT matchid
				, FinalHomeScore
				, FinalAwayScore
				, HTHomeScore
				, HTAwayScore
				, sporttype
				, STUFF(Result.ResouceResult,1,1,'') AS ResouceResult
			FROM DBPRO.BODB02.dbo.Match m WITH (NOLOCK)
				OUTER APPLY (SELECT  ',' + RIGHT(ResourceID,2) + Custom1 
							FROM	DBPRO.bodb02.dbo.ResultDetail3rd m1 WITH (NOLOCK)
							WHERE	m1.MatchID = m.matchid 
									AND m1.SettlementStatusID = 4
									AND m1.ResourceId LIKE '2809__'
									AND m.sporttype = 193
							FOR XML PATH ('')		
							) AS Result (ResouceResult)
			WHERE m.matchid IN (SELECT matchid FROM CTE_MatchID)	
			 
		END
		-------------------END: Result PREPARATION ----------------------
		
		-------------------STARTING: Tickets for Calculating PREPARATION ----------------------
		IF @mode = 'CAL'
		BEGIN	
			IF @SportType = 193 -- BASEKETBALL
			BEGIN
				INSERT INTO #TempData(recommend, matchid, custid, bettype,transid, actual_stake, stake, odds, comstatus, apositiontaking, mpositiontaking, spositiontaking
									, playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, modds)
				SELECT	b.recommend, b.matchid, b.custid, b.bettype,transid, actual_stake, stake, odds, comstatus, 	apositiontaking, mpositiontaking, spositiontaking, 
					playerdiscount,discount, adiscount, sdiscount,	WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, ods.modds						
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN @tempBettype AS temp ON b.bettype = temp.bettype
					OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds_193 (
						b.bettype 			
						, b.betteam 			
						, b.hdp1 			
						, b.hdp2 			
						, b.livehomescore	
						, b.liveawayscore	
						, @fth				
						, @fta				
						, @hth				
						, @hta
						, temp.CalMode
						, b.betid
						, @ResourceResult
					) AS ods
				WHERE b.matchid = @matchid 
					AND b.statusID NOT IN (101,102) --void/reject
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			END
			ELSE -- SOCCER
			BEGIN
				INSERT INTO #TempData(recommend, matchid, custid, bettype,transid, actual_stake, stake, odds, comstatus, apositiontaking, mpositiontaking, spositiontaking
									, playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, modds)
				SELECT	b.recommend, b.matchid, b.custid, b.bettype,transid, actual_stake, stake, odds, comstatus, 	apositiontaking, mpositiontaking, spositiontaking, 
					playerdiscount,discount, adiscount, sdiscount,	WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, ods.modds						
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN @tempBettype AS temp ON b.bettype = temp.bettype
					OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds(
						b.bettype 			
						, b.betteam 			
						, b.hdp1 			
						, b.hdp2 			
						, b.livehomescore	
						, b.liveawayscore	
						, @fth				
						, @fta
						, @hth
						, @hta
						, temp.CalMode
						, b.transdesc
					) AS ods
				WHERE b.matchid = @matchid 
					AND b.statusID NOT IN (101,102) --void/reject
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					
			END	
		END			
		ELSE IF @mode = 'RECOVER'
		BEGIN			
			INSERT INTO #TempData(recommend, matchid, custid, bettype,transid, actual_stake, stake, odds, comstatus,apositiontaking, mpositiontaking, spositiontaking, 
				playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, modds)
			SELECT	b.recommend, b.matchid, b.custid, b.bettype,b.transid, actual_stake, stake, odds, comstatus, apositiontaking, mpositiontaking, spositiontaking, 
					playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, ods.modds					
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN #tblMatchResult mr ON b.matchid = mr.matchid
				INNER JOIN #tblTicketInfos t ON b.transid = t.transid
				INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f ON b.bettype = f.bettype AND mr.sporttype = f.SportType		
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
					, b.transdesc
				) AS ods
			WHERE	mr.sporttype IN (190,191,192,194,195,196,197)
					AND b.statusID NOT IN (101,102) --void/reject	
			
			IF EXISTS (SELECT TOP 1 * FROM #tblMatchResult WITH (NOLOCK) WHERE sporttype = 193)
			BEGIN
				INSERT INTO #TempData(recommend, matchid, custid, bettype,transid, actual_stake, stake, odds, comstatus,apositiontaking, mpositiontaking, spositiontaking, 
						playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, modds)
				SELECT	b.recommend, b.matchid, b.custid, b.bettype,b.transid, actual_stake, stake, odds, comstatus, apositiontaking, mpositiontaking, spositiontaking, 
						playerdiscount,discount, adiscount, sdiscount,WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm,StatusID, ods.modds					
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #tblMatchResult mr ON b.matchid = mr.matchid
					INNER JOIN #tblTicketInfos t ON b.transid = t.transid
					INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f ON b.bettype = f.bettype AND mr.sporttype = f.SportType		
					OUTER APPLY dbo.f_Set_VS_BetRadar_CalModds_193 (
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
						, b.betid
						, mr.ResourceResult
					) AS ods
				WHERE	mr.sporttype = 193
						AND b.statusID NOT IN (101,102) --void/reject	
			END	
		END	
		-------------------END: Tickets for Calculating PREPARATION ----------------------
		
		-------------------STARTING: Ticket Results PREPARATION ----------------------					
		IF EXISTS (SELECT TOP 1 1 FROM #TempData)
		BEGIN
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
						ELSE WinLost
					END,	

				aWinLost = CASE
						WHEN modds >  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking
						WHEN modds =  0.25	THEN stake * (case when odds<0 then 1 else odds end) * -apositiontaking * 0.5
						WHEN modds =  0	THEN 0
						WHEN modds = -0.25	THEN actual_stake * apositiontaking * 0.5
						WHEN modds < -0.25	THEN actual_stake * apositiontaking
						ELSE aWinLost
					END,
				mWinLost = CASE
						WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking
						WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -mpositiontaking * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN actual_stake * mpositiontaking * 0.5
						WHEN modds < -0.25 THEN actual_stake * mpositiontaking
						ELSE mWinLost
					END,
				sWinLost = CASE
						WHEN modds >  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking
						WHEN modds =  0.25 THEN stake * (case when odds<0 then 1 else odds end) * -spositiontaking * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN actual_stake * spositiontaking * 0.5
						WHEN modds < -0.25 THEN actual_stake * spositiontaking
						ELSE sWinLost
					END,

				PlayerComm = CASE
						WHEN modds >  0.25 THEN @commWinRate * playerdiscount * stake
						WHEN modds =  0.25 THEN @commWinRate * playerdiscount * stake * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN @commLostRate * playerdiscount * stake * 0.5
						WHEN modds < -0.25 THEN @commLostRate * playerdiscount * stake
						ELSE PlayerComm
					END,
				Comm = CASE
						WHEN modds >  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking)
						WHEN modds =  0.25 THEN @commWinRate * discount * stake * (1-apositiontaking) * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking) * 0.5
						WHEN modds < -0.25 THEN @commLostRate * discount * stake * (1-apositiontaking)
						ELSE Comm
					END,
				aComm = CASE
						WHEN modds >  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
						WHEN modds =  0.25 THEN @commWinRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking)) * 0.5
						WHEN modds < -0.25 THEN @commLostRate * adiscount * stake * (1-(mpositiontaking+apositiontaking))
						ELSE aComm
					END,
				sComm = CASE
						WHEN modds >  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
						WHEN modds =  0.25 THEN @commWinRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
						WHEN modds =  0    THEN 0
						WHEN modds = -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking)) * 0.5
						WHEN modds < -0.25 THEN @commLostRate * sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
						ELSE sComm
					END,
				StatusID = CASE
					WHEN modds > 0 THEN 112 --WON
					WHEN modds = 0 THEN 111 --DRAW
					WHEN modds < 0 THEN 113 --LOSE
					ELSE StatusID
				END	
			-------------------END: Ticket Results PREPARATION ----------------------					
			
			-------------------STARTING: UPDATE Tickets By Batch ----------------------					
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
			-------------------END: UPDATE Tickets By Batch ----------------------	
		END
	END TRY
	BEGIN CATCH
	
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
		
	END CATCH
	
	-- Settlement balance process
	IF(@IsBalance = 1 AND LEN(@balanceAcc) > 0)
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_BalanceProcess
			@BalanceAcc				= @balanceAcc
			, @BalanceType			= @BalanceType
			, @actionId				= @actionId
			, @MatchID				= @MatchID
			, @GroupID				= @GroupID		
	END
	
	DROP TABLE #TempData
	DROP TABLE #tblMatchResult
	DROP TABLE #tblTicketInfos
	
END
GO