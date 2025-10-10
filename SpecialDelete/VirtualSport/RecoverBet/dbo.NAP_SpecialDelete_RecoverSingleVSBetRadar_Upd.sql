/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverSingleVSBetRadar_Upd]			
	@TransIds					VARCHAR(MAX),
    @UserID						INT,
    @IP							VARCHAR(15)
AS
/*  
	Created by: 20170607@Kent  
	Task: 
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]			
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
		- 20230921@Max: [TVS] Recover Virtual Sports Bet and Recover By Bet ID - Update more info when calling SP from Settlement site [Redmine: #194269]
		- 20231030@July: [TVS] Integrate a new sport type "Virtual Football League" [Redmine: #195313]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241028@Max: [TVS] Virtual Sports 6 (Betby) - Virtual Betby Basketball [Redmine: #212502]
		- 20241126@Lani: [TVS] Get site from srecommend, change serverAlias [Redmine: #213451]
		- 20241211@Louisa: Enhance Winlimit - add matchid/transid for BalancePendingCreditGame [Redmine:#215066]
		- 20250402@Mike: [TVS] Upgrade ExchangeID data type [Redmine:#222191]
		- 20250612@July: Fix replication issue caused by NULL values in the action call/refund input ticket [Redmine:#229870]
		- 20250624@Lani: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]
		- 20251009@July: [TVS] Virtual Sport 6 - Integrate new sport type [Redmine:#241016]

	Param's Explanation:		
		- @TransIds : Main transids.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Action_Recal			VARCHAR(100)  = 'Re-Cal'
		  , @Action_Refund			VARCHAR(100)  = 'Refund'				
		  , @Movebetdate			DATETIME
		  , @spName					VARCHAR(500) = OBJECT_NAME(@@PROCID)

	DECLARE @isExistMatch				  BIT = 0	
		  , @IsExistVS					  BIT = 0	  	  
		  , @avaiableProcess			  BIT = 0
		  , @IsExistVSBetradar			  BIT = 0
		  , @IsExistInspiredVS			  BIT = 0
		  , @IsExistVS3					  BIT = 0
		  , @IsExistVS4					  BIT = 0
		  , @isITAdmin					  BIT = 0
		  , @before_yesterday			  DATETIME
		  , @CustIds					  VARCHAR(MAX) = ''			  		 
		  , @i							  INT = 0
		  , @matchId					  INT
		  , @TicketType					  TINYINT	
		  , @isExistMatch3rd			  BIT = 0
		  , @ActionId					  INT = 90999 --TVS - Agency Cash Service
	
	DECLARE @cnt_RecalMatchInspiredVS	  INT = 0	
		  , @cnt_RefundMatchInspiredVS	  INT = 0		 
	
	DECLARE @IgnoreList				VARCHAR(200)  = ''
		  , @_xml					XML		
		  , @_sXML					VARCHAR(MAX)  = ''
		  , @TicketInfos_Recal 		VARCHAR(MAX) = ''
		  , @TicketInfos_Refund 	VARCHAR(MAX) = ''
		  , @CompletedMatchIds		VARCHAR(MAX)	= ''
		  , @NegativeBalanceUsers	VARCHAR(MAX)	= '' 
		  , @ErrMsg					NVARCHAR(200)	= ''
		  , @ErrCode				INT				= 0	
		  , @SiteDBGroupID		    SMALLINT
		  , @transInfo				VARBINARY(MAX) 
		  , @TransInfoMaxPO		    VARCHAR(MAX)
		  , @TotalTransMaxPO		INT = 0
		  , @batchPO				SMALLINT = 500

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE (matchid INT, transid BIGINT, transdate DATETIME, comstatus NVARCHAR(40) )
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)
	DECLARE @tmpTransIDMaxPO TABLE (TransID BIGINT
		,custid INT, actualPO MONEY, winlost MONEY
		,transdate DATETIME, bettype SMALLINT
	)
	DECLARE @tmpSelectedResources TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
								  BetType SMALLINT,OddsType SMALLINT,  BetID BIGINT, pfID SMALLINT ,PRIMARY KEY (BetType,BetID))
		  
	SET @IgnoreList = 'DB04,DB042,DB043,DB044'		  
	
	CREATE TABLE #RecoverBet
	(
		Stake				MONEY,
		AwayId				INT,
		BetCheck			NVARCHAR(50),
		BetId				BIGINT,
		BetTeam				NVARCHAR(10),
		BetType				SMALLINT,
		CurrencyCode		NVARCHAR(50),
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		HomeId				INT,
		IsLiveIndicator		BIT,
		LiveAwayScore		SMALLINT,
		LiveHomeScore		SMALLINT,
		Odds				SMALLMONEY,
		OddsType			INT,
		RefNo				BIGINT,
		SportType			SMALLINT,
		Status				NVARCHAR(10),
		TransDate			DATETIME,
		TransDesc			NVARCHAR(1000),
		TransId				BIGINT,
		UserName			VARCHAR(30),
		WinLost				MONEY,
		IsDeposit			BIT DEFAULT(0),
		recommend			INT,
		mrecommend			INT,
		srecommend			INT,
		CustId				INT,		
		eventdate			DATETIME,
		eventstatus			NVARCHAR(100),		
		showtime			NVARCHAR(20),
		creator				INT,
		oddsid				INT,
		LeagueId			INT,
		matchcode			NVARCHAR(50),
		modds				SMALLMONEY,
		BetFrom				NVARCHAR(4),
		matchid				INT,
		[Action]			VARCHAR(100),
		TicketType			TINYINT, -- 1 : VS Betradar, 2 : Inspired VS 180, 3 : Inspired VS 181, 4 : VS3(Leap Gaming), 5: VS4(Edge Gaming), 6: VS5, 7: VS6
		currency			SMALLINT,
		actualPO			MONEY,
		IsApplyMaxPO		BIT
	)
	
	CREATE TABLE #ReCalMatchID_InspiredVS
	(
		RowNum				INT IDENTITY(1, 1),
		matchid				INT,
		TicketType			TINYINT	-- 2 : Inspired VS 180, 3 : Inspired VS 181	
	)
	
	CREATE TABLE #ReFundMatchID_InspiredVS
	(
		RowNum				INT IDENTITY(1, 1),
		matchid				INT,
		TicketType			TINYINT	-- 2 : Inspired VS 180, 3 : Inspired VS 181	
	)		
	
	CREATE TABLE #beforeUpd	
	(
		custid				INT,
		winlostdate			SMALLDATETIME,
		gametypeid			SMALLINT,
		balance				MONEY,
		winlost				MONEY,
		TransId				BIGINT
	)
	
	CREATE TABLE #afterUpd	
	(
		custid				INT,
		winlostdate			SMALLDATETIME,
		gametypeid			SMALLINT,
		balance				MONEY,
		winlost				MONEY,
		TransId				BIGINT
	)
	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30), username2 VARCHAR(50), site VARCHAR(10), currency SMALLINT)
	CREATE TABLE #tblTransIds (transid BIGINT)
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, increased BIT)

	DECLARE @beforeUpd 		TVP_BalanceChange		  
		  , @afterUpd 		TVP_BalanceChange		  		  		  		 		
	
	SELECT @before_yesterday = CONVERT(VARCHAR(10), DATEADD(DAY, -2, GETDATE()), 120)	
	
	BEGIN TRY	 
		--> parse @TransIds
		INSERT INTO #tblTransIds (transid)
		SELECT	t.value
		FROM STRING_SPLIT(@TransIds, ',') t					
		
		--> Search tickets			
		INSERT INTO #RecoverBet(
				Stake,
				BetCheck,
				BetId,
				BetTeam,
				BetType,
				CurrencyCode,
				Hdp1,
				Hdp2,
				IsLiveIndicator,
				LiveAwayScore,
				LiveHomeScore,
				Odds,
				OddsType,
				RefNo,
				Status,
				TransDate,
				TransDesc,
				TransId,
				UserName,
				WinLost,
				recommend,
				mrecommend,
				srecommend,
				CustId,					
				creator,
				oddsid,
				modds,
				BetFrom,
				matchid,					
				currency
		)
		SELECT  z.Stake,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				b.CustId,					
				z.creator,
				b.oddsid,
				b.modds,
				b.betfrom,
				b.matchid,					
				b.currency
		FROM #tblTransIds tbl
			 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)	ON tbl.transid = z.transid
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype
		WHERE z.winlostdate >= @before_yesterday
		  AND NOT EXISTS (SELECT TOP 1 1 FROM f_TVS_SpeciallyBettypes() f WHERE TypeId IN (1) AND f.bettype = z.bettype)
		  AND z.SiteDBGroupID = @SiteDBGroupID
		  
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT 99 AS ErrorCode
				  ,'No ticket found.' AS ErrorMsg
			RETURN
		END	
		
		-- update Isdeposit
		UPDATE r 
			SET IsDeposit = 1
		FROM #RecoverBet r
		WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = r.srecommend)
	
		BEGIN
			UPDATE r
			SET  matchcode 	= NULL
				,homeid 	= m.homeid
				,awayid 	= m.awayid
				,leagueid 	= m.leagueid
				,sporttype	= m.SportType
				,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
				,eventdate  = m.eventdate
				,eventstatus = ISNULL(m.eventstatus,'')
				,[Action]   = CASE
									WHEN m.eventstatus = 'completed'
											THEN CASE
													WHEN m.betstatus LIKE '%' + 'Refund' + '%' THEN @Action_Refund
													ELSE @Action_Recal
												 END
									ELSE NULL
							   END
				,TicketType = CASE 
								  WHEN m.sporttype BETWEEN 190 AND 199 THEN 1 -- VS Betradar
								  WHEN m.sporttype IN (180, 186) THEN 2 -- Inspired VS 180
								  WHEN m.sporttype IN (178, 179) THEN 4 -- VS 3 (Leap Gaming)
								  WHEN m.sporttype IN (188) THEN 5 -- VS 4 (Edge Gaming)
								  WHEN m.sporttype IN (147) THEN 6 -- VS5
								  WHEN m.sporttype IN (134, 116) THEN 7 -- VS6
								  ELSE NULL
								END 
			FROM #RecoverBet r
				CROSS APPLY (
					SELECT m.homeid, m.awayid, m.sporttype, m.leagueid, m.kickofftime, m.matchcode, m.eventdate, m.eventstatus, m.betstatus
					FROM match m WITH (NOLOCK)
					WHERE m.matchid = r.matchid
					UNION 
					SELECT m.homeid, m.awayid, m.sporttype, m.League3rdId AS leagueid, m.StartTime, m.MatchNo AS matchcode, m.EventDate, m.eventstatus, m.betstatus
					FROM Match3rd m WITH (NOLOCK)
					WHERE m.Match3rdId = r.matchid
				 )m			
			WHERE m.sporttype BETWEEN 190 AND 199 -- VS Betradar
				 OR m.sporttype IN (180, 186	-- Inspired VS 
								  , 178, 179	-- VS 3 (Leap Gaming)
								  , 188			-- VS 4 (Edge Gaming)
								  , 147			-- VS5
								  , 134, 116	-- VS6
							) 

			-- Inspired VS 181
			UPDATE r
			SET  matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= vs.leagueid
				,sporttype 	= vs.sporttype
				,showtime	= CONVERT(VARCHAR(20), vs.EventTime, 113) 
				,eventdate  = o.eventdate
				,eventstatus = ISNULL(o.eventstatus,'')
				,[Action]   = CASE
									WHEN o.eventstatus = 'completed'
											THEN CASE
													WHEN vs.betstatus LIKE '%' + 'Refund' + '%' THEN @Action_Refund
													ELSE @Action_Recal
												 END
									ELSE NULL
							   END
				,TicketType = 3
			FROM #RecoverBet r
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
					 ON r.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo vs WITH (NOLOCK) 
						 ON vs.EventID = o.EventID		
			WHERE vs.sporttype BETWEEN 181 AND 185 -- Inspired VS 181	
		END

		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
		
		IF EXISTS ( SELECT TOP 1 1 FROM #RecoverBet WHERE eventdate <= @Movebetdate )
		BEGIN
			SELECT 112 AS ErrorCode
				  ,'Could not recover some tickets due to Movebet process. Please try Search again.' AS ErrorMsg
			RETURN	
		END
		
		--> Check Concurrency				
		SELECT @isExistMatch	  = MAX(CASE WHEN TicketType IN (1, 2, 4, 5) THEN 1 ELSE 0 END)
			 , @IsExistVS		  = MAX(CASE WHEN TicketType = 3 THEN 1 ELSE 0 END)			 
			 , @IsExistVSBetradar = MAX(CASE WHEN TicketType = 1 THEN 1 ELSE 0 END)
			 , @IsExistVS3		  = MAX(CASE WHEN TicketType = 4 THEN 1 ELSE 0 END)
			 , @IsExistVS4	      = MAX(CASE WHEN TicketType = 5 THEN 1 ELSE 0 END)
			 , @IsExistInspiredVS = MAX(CASE WHEN TicketType IN (2,3) THEN 1 ELSE 0 END)
			 , @isExistMatch3rd	  = MAX(CASE WHEN TicketType IN (6,7) THEN 1 ELSE 0 END)
		FROM #RecoverBet
			
		INSERT INTO #tblMatchProcess (matchid, KeyID)
		SELECT DISTINCT 
				matchid
			  , CASE 
					WHEN TicketType IN (1, 2, 4, 5) THEN 1 -- VS Betradar, Inspired VS 180, VS3(Leap Gaming), VS4(Edge Gaming)
					WHEN TicketType IN (6,7) THEN 8 --VS5
					ELSE 4 -- Inspired VS 181
				END AS KeyId
		FROM #RecoverBet
			
		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMatch				= @isExistMatch								
			, @spName					= @spName
			, @IsExistVS				= @IsExistVS
			, @isExistMatch3rd			= @isExistMatch3rd
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT																		
		
		IF @ErrCode <> 0 OR @avaiableProcess = 0
		BEGIN
			SELECT @ErrCode AS ErrorCode
				  ,@ErrMsg AS ErrorMsg

			RETURN
		END
						
		--> Capture balance before
		INSERT INTO #beforeUpd(custid										  
							 , winlostdate
							 , gametypeid
							 , balance
							 , winlost
							 , TransId)
		SELECT	b.custid				  
			  , b.winlostdate
			  , b.bettype AS gametypeid
			  , (b.winlost - b.actual_stake + b.playercomm) AS balance 
			  , (CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END) AS winlost	
			  , b.TransId
		FROM bettrans b WITH (NOLOCK) 
			 INNER JOIN #RecoverBet t ON b.transid = t.TransId

		INSERT INTO @beforeUpd(custid, balance, balanceType)
		SELECT	CustID
			  , SUM (balance) AS balance 
			  , 4 AS balanceType
		FROM #beforeUpd						 					 	  
		GROUP BY CustID
		
		DECLARE @tmpMatchId TABLE (matchId INT, Sporttype SMALLINT, IsFinish BIT)
		
		IF @IsExistVSBetradar = 1 OR @IsExistInspiredVS = 1
		BEGIN	
			DELETE FROM @tmpMatchId

			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT b.MatchId
			FROM #RecoverBet b
			WHERE b.TicketType IN (1, 2, 3)

			WHILE (1=1)
			BEGIN
				SET @_sXML = NULL

				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId
				FROM @tmpMatchId m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

				--> Update Bettrans	to running
				SET @_xml = (
					SELECT transid '@q' -- transid			 
						 , creator '@cr' -- creator
					FROM #RecoverBet	
					WHERE TicketType IN (1, 2, 3) AND matchid = @matchId	 					 
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC dbo.Bet_ExecRep_05 
					  @IgnoreList 	= @IgnoreList
					, @updatetype 	= 6
					, @_sXML 		= @_sXML
					, @matchId = @matchId
			END									
					
			IF @IsExistVSBetradar = 1
			BEGIN 
				--> Re-cal	
				SET @_xml = (
					SELECT matchid '@m' 
						 , transid '@t'
					FROM #RecoverBet
					WHERE TicketType = 1
					  AND [Action] = @Action_Recal
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Recal = CONVERT(VARCHAR(MAX), @_xml)											
		
				EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Main] 
							@mode = 'RECOVER'
						  , @TicketInfos = @TicketInfos_Recal
						  , @IsBalance = 0
						  , @CWLBettype = 0
						  , @ErrCode = @ErrCode OUTPUT
						  , @ErrMsg = @ErrMsg OUTPUT						
		
				--> Refund		
				SET @_xml = (
					SELECT transid '@t'
					FROM #RecoverBet
					WHERE TicketType = 1
					  AND [Action] = @Action_Refund
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Refund = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Refund] 
							@mode = 'RECOVER'
						  , @TicketInfos = @TicketInfos_Refund
						  , @IsBalance = 0
						  , @CWLBettype = 0
						  , @ErrCode = @ErrCode OUTPUT
						  , @ErrMsg = @ErrMsg OUTPUT										  				
			END
			
			IF @IsExistInspiredVS = 1
			BEGIN
				--> Build #ReCalMatchID_InspiredVS
				INSERT INTO #ReCalMatchID_InspiredVS(matchid, TicketType)
				SELECT matchid, TicketType
				FROM #RecoverBet
				WHERE TicketType IN (2, 3)
				  AND [Action] = @Action_Recal
				GROUP BY matchid, TicketType					
		
				SET @cnt_RecalMatchInspiredVS = @@ROWCOUNT													
	
				--> Re-cal For Inspired VS								
				SET @i = 1					
				WHILE @i <= @cnt_RecalMatchInspiredVS
				BEGIN
					SELECT @matchId = matchid
						 , @TicketType = TicketType
					FROM #ReCalMatchID_InspiredVS
					WHERE RowNum = @i
			
					IF @TicketType = 2 -- inspired vs 180				
						EXEC dbo.NAP_Admin_Settlement_3_VS 
							 @Creator	= @UserID
						   , @MatchId	= @matchid
						   , @Mode		= 'CAL'
					ELSE IF @TicketType = 3 -- inspired vs 181
					BEGIN
						EXEC Admin_Calculate_181M @matchid =@matchid  
						EXEC Admin_Calculate_181 @matchid =@matchid
					END						   
		
					SET @i = @i + 1
				END	
			
				--> Build #RefundMatchID_InspiredVS
				INSERT INTO #RefundMatchID_InspiredVS(matchid, TicketType)
				SELECT matchid, TicketType
				FROM #RecoverBet
				WHERE TicketType IN (2, 3)
				  AND [Action] = @Action_Refund
				GROUP BY matchid, TicketType
		
				SET @cnt_RefundMatchInspiredVS = @@ROWCOUNT														
		
				--> Refund For Inspired VS								
				SET @i = 1				
				WHILE @i <= @cnt_RefundMatchInspiredVS
				BEGIN
					SELECT @matchId = matchid
						 , @TicketType = TicketType
					FROM #RefundMatchID_InspiredVS
					WHERE RowNum = @i
			
					IF @TicketType = 2 -- inspired vs 180
						EXEC dbo.NAP_Admin_Calculate_VS_180_Refund 
							 @matchid = @matchid
					ELSE IF @TicketType = 3 -- inspired vs 181
						EXEC Admin_Calculate_VS_181_Refund 
							 @matchid =@matchid							 
		
					SET @i = @i + 1
				END						
			END		
		END			
		
		IF @IsExistVS3 = 1 OR @IsExistVS4 = 1
		BEGIN	
			DELETE @tmpMatchId
			DELETE @tmpSelectedResources
			DELETE @tmpMaxWinLimit

			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT b.MatchId
			FROM #RecoverBet b
			WHERE b.TicketType IN (4,5)

			INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID,OddsType )  
			SELECT DISTINCT Id, ISNULL(Home,''), ISNULL(Away,''), sp.BetType, sp.BetID, sp.pfID , sp.OddsType
			FROM (
				SELECT '00' AS Id, m.finalhomescore AS Home, m.finalawayscore AS Away
				FROM @tmpMatchId t
					INNER JOIN dbo.match m WITH (NOLOCK) ON t.matchId = m.matchid
				UNION ALL
				SELECT '01' AS Id, m.hthomescore AS Home, m.htawayscore AS Away
				FROM @tmpMatchId t
					INNER JOIN dbo.match m WITH (NOLOCK) ON t.matchId = m.matchid
			) AS tbl
				INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON	sp.ResourceID = tbl.Id
			WHERE sp.SportType IN (178, 179, 188)

			UPDATE r SET 
				 r.actualPO = CASE
				   		WHEN m.modds >  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1  
																				   WHEN sr.oddstype = 1 THEN b.odds - 1 
																				   ELSE b.odds 
																				END)
				   		WHEN m.modds =  0.25 THEN b.actual_stake + b.stake * 0.5 * (CASE WHEN b.odds < 0 THEN 1  
																						 WHEN sr.oddstype = 1 THEN b.odds - 1 
																						 ELSE b.odds 
																					END)
				   		ELSE NULL
				    END 
				,r.OddsType = sr.OddsType
			FROM	#RecoverBet r
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = r.TransId
			CROSS APPLY(
							SELECT TOP 1 pfID, HomeValue, AwayValue, OddsType
							FROM @tmpSelectedResources t
							WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
						) sr
					CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
			WHERE	r.TicketType IN (4, 5)
					AND b.statusID <> 101
					AND b.SiteDBGroupID = @SiteDBGroupID
					AND r.Action = @Action_Recal

			-- check if winlost reaches the maxpayout
			IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
			BEGIN
				;WITH cteCustIds
				AS(
					SELECT DISTINCT custid, currency
					FROM	#RecoverBet t
					WHERE	modds >= 0.25
						AND  t.TicketType IN (4, 5)
				)
				INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
				SELECT	t.custid, fc.MaxWinLimit
				FROM	CustDB.dbo.Customer c WITH(NOLOCK)
					INNER JOIN cteCustIds t
						ON t.custid = c.custid
					INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
						ON s.site = c.site
					INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
						ON s.siteid = fs.siteid
					INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
						ON	t.currency = fc.ExchangeId
							AND fc.SiteDBGroupId = @SiteDBGroupId

				IF @@ROWCOUNT > 0
				BEGIN
					UPDATE t 
						SET IsApplyMaxPO = 1
							,winlost = m.MaxWinLimit
					FROM	#RecoverBet t
						INNER JOIN	@tmpMaxWinLimit m
							ON t.CustId = m.CustId
					WHERE	t.actualPO > m.MaxWinLimit
						AND t.TicketType IN (4, 5)

					SET @TotalTransMaxPO = @TotalTransMaxPO + @@ROWCOUNT
				END
					
			END

			WHILE (1=1)
			BEGIN
				SET @_sXML = NULL

				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId
				FROM @tmpMatchId m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

				--> Update Bettrans	to running
				SET @_xml = (
					SELECT transid '@q' -- transid			 
						 , creator '@cr' -- creator
					FROM #RecoverBet	
					WHERE TicketType IN (4, 5) AND matchid = @matchId	 					 
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC dbo.Bet_ExecRep_05 
					  @IgnoreList 	= @IgnoreList
					, @updatetype 	= 6
					, @_sXML 		= @_sXML
					, @matchId = @matchId
			
				--> Re-cal	
				SET @_xml = (
					SELECT transid AS '@t'
						  ,modds AS '@m'
						  ,ISNULL(OddsType,0) AS '@ot'
						  ,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
						  ,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
						  ,IsApplyMaxPO AS '@iMPO'
					FROM #RecoverBet
					WHERE TicketType IN (4, 5) AND matchid = @matchid
					  AND [Action] = @Action_Recal
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Recal = CONVERT(VARCHAR(MAX), @_xml)											
				
				IF ISNULL(@TicketInfos_Recal,'') <> ''
				BEGIN
					EXEC [dbo].[NAP_Admin_Calculate_OtherSports] 
								@matchid			 = @matchid 
							   ,@action				 = 'CAL'  
							   ,@strTransIds		 = @TicketInfos_Recal
							   ,@EventTable			 = 1
							   ,@Is3rd				 = 1 
							   ,@IsCalculateBalance  = 0
							   ,@CWLBettype			 = 0
							   ,@BalanceType		 = 0				
				END

				--> Refund		
				SET @_xml = (
					SELECT transid AS '@t'
						  ,modds AS '@m'
						  ,ISNULL(OddsType,0) AS '@ot'
					FROM #RecoverBet
					WHERE TicketType IN (4, 5) AND matchid = @matchid 
					  AND [Action] = @Action_Refund
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Refund = CONVERT(VARCHAR(MAX), @_xml)											
				
				IF ISNULL(@TicketInfos_Refund,'') <> ''
				BEGIN
					EXEC [dbo].[NAP_Admin_Calculate_OtherSports] 
								@matchid			 = @matchid 
							   ,@action				 = 'REFUND'  
							   ,@strTransIds		 = @TicketInfos_Refund
							   ,@EventTable			 = 1
							   ,@Is3rd				 = 1 
							   ,@IsCalculateBalance  = 0
							   ,@CWLBettype			 = 0
							   ,@BalanceType		 = 0		
				END
			END
		END		

		--VS5/VS6
		IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE TicketType IN (6,7))
		BEGIN	
			DELETE @tmpMatchId
			DELETE @tmpSelectedResources
			DELETE @tmpMaxWinLimit

			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT b.MatchId
			FROM #RecoverBet b
			WHERE b.TicketType IN (6,7)
			
			IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE TicketType = 6)
			BEGIN
				INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID,OddsType )  
				SELECT DISTINCT Id, ISNULL(Home,''), ISNULL(Away,''), sp.BetType, sp.BetID, sp.pfID , sp.OddsType
				FROM (
					SELECT '00' AS Id, m.finalhomescore AS Home, m.finalawayscore AS Away
					FROM @tmpMatchId t
						INNER JOIN dbo.Match3rd m WITH (NOLOCK) ON t.matchId = m.Match3rdId
					UNION ALL
					SELECT '01' AS Id, m.hthomescore AS Home, m.htawayscore AS Away
					FROM @tmpMatchId t
						INNER JOIN dbo.Match3rd m WITH (NOLOCK) ON t.matchId = m.Match3rdId
				) AS tbl
					INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON	sp.ResourceID = tbl.Id
				WHERE sp.SportType IN (147)
			END

			IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE TicketType = 7)
			BEGIN
				INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID,OddsType )  
				SELECT DISTINCT tbl.ResourceID, ISNULL(HomeValue,''), ISNULL(AwayValue,''), sp.BetType, sp.BetID, sp.pfID , sp.OddsType
				FROM (
					SELECT r.ResourceID, r.Custom1  AS HomeValue ,r.custom2 AS AwayValue 
					FROM DBPRO.bodb02.dbo.ResultDetail3rd r with(nolock)
						INNER JOIN @tmpMatchId m ON r.matchId = m.Matchid
				) AS tbl
					INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON	sp.ResourceID = tbl.ResourceId
					INNER JOIN #RecoverBet b on sp.BetType = b.bettype	AND (sp.BetID = 0 OR sp.BetID = b.betid ) 
				WHERE sp.SportType IN (134, 116)
			END

			UPDATE r SET 
				 r.actualPO = CASE
				   		WHEN m.modds >  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1  
																				   WHEN sr.oddstype = 1 THEN b.odds - 1 
																				   ELSE b.odds 
																				END)
				   		WHEN m.modds =  0.25 THEN b.actual_stake + b.stake * 0.5 * (CASE WHEN b.odds < 0 THEN 1  
																						 WHEN sr.oddstype = 1 THEN b.odds - 1 
																						 ELSE b.odds 
																					END)
				   		ELSE NULL
				    END 	
				, r.OddsType = sr.OddsType
			FROM	#RecoverBet r
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = r.TransId
			CROSS APPLY(
							SELECT TOP 1 pfID, HomeValue, AwayValue, OddsType
							FROM @tmpSelectedResources t
							WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
						) sr
					CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
			WHERE	r.TicketType IN (6,7)
					AND b.statusID <> 101
					AND b.SiteDBGroupID = @SiteDBGroupID
					AND r.Action = @Action_Recal

			-- check if winlost reaches the maxpayout
			IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
			BEGIN
				;WITH cteCustIds
				AS(
					SELECT DISTINCT custid, currency
					FROM	#RecoverBet t
					WHERE	modds >= 0.25
						AND  t.TicketType IN (6,7)
				)
				INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
				SELECT	t.custid, fc.MaxWinLimit
				FROM	CustDB.dbo.Customer c WITH(NOLOCK)
					INNER JOIN cteCustIds t
						ON t.custid = c.custid
					INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
						ON s.site = c.site
					INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
						ON s.siteid = fs.siteid
					INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
						ON	t.currency = fc.ExchangeId
							AND fc.SiteDBGroupId = @SiteDBGroupId

				IF @@ROWCOUNT > 0
				BEGIN
					UPDATE t 
						SET IsApplyMaxPO = 1
							,winlost = m.MaxWinLimit
					FROM	#RecoverBet t
						INNER JOIN	@tmpMaxWinLimit m
							ON t.CustId = m.CustId
					WHERE	t.actualPO > m.MaxWinLimit
						AND t.TicketType IN (6,7)

					SET @TotalTransMaxPO = @TotalTransMaxPO + @@ROWCOUNT
				END
					
			END

			WHILE (1=1)
			BEGIN
				SET @_sXML = NULL

				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId
				FROM @tmpMatchId m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

				--> Update Bettrans	to running
				SET @_xml = (
					SELECT transid '@q' -- transid			 
						 , creator '@cr' -- creator
					FROM #RecoverBet	
					WHERE TicketType IN (6,7) AND matchid = @matchId	 					 
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC dbo.Bet_ExecRep_05 
					  @IgnoreList 	= @IgnoreList
					, @updatetype 	= 6
					, @_sXML 		= @_sXML
					, @matchId = @matchId
			
				--> Re-cal	
				SET @_xml = (
					SELECT transid AS '@t'
						  ,modds AS '@m'
						  ,ISNULL(OddsType,0) AS '@ot'
						  ,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
						  ,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
						  ,IsApplyMaxPO AS '@iMPO'
					FROM #RecoverBet
					WHERE TicketType IN (6,7) AND matchid = @matchid
					  AND [Action] = @Action_Recal
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Recal = CONVERT(VARCHAR(MAX), @_xml)											
				
				IF ISNULL(@TicketInfos_Recal,'') <> ''
				BEGIN
					EXEC [dbo].[NAP_Admin_Calculate_OtherSports] 
								@matchid			 = @matchid 
							   ,@action				 = 'CAL'  
							   ,@strTransIds		 = @TicketInfos_Recal
							   ,@EventTable			 = 3
							   ,@Is3rd				 = 1 
							   ,@IsCalculateBalance  = 0
							   ,@CWLBettype			 = 0
							   ,@BalanceType		 = 0				
				END
				--> Refund		
				SET @_xml = (
					SELECT transid AS '@t'
						  ,modds AS '@m'
						  ,ISNULL(OddsType,0) AS '@ot'
					FROM #RecoverBet
					WHERE TicketType IN (6,7) AND matchid = @matchid 
					  AND [Action] = @Action_Refund
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Refund = CONVERT(VARCHAR(MAX), @_xml)											
				
				IF ISNULL(@TicketInfos_Refund,'') <> ''
				BEGIN
					EXEC [dbo].[NAP_Admin_Calculate_OtherSports] 
								@matchid			 = @matchid 
							   ,@action				 = 'REFUND'  
							   ,@strTransIds		 = @TicketInfos_Refund
							   ,@EventTable			 = 3
							   ,@Is3rd				 = 1 
							   ,@IsCalculateBalance  = 0
							   ,@CWLBettype			 = 0
							   ,@BalanceType		 = 0		
				END
			END
		END	

		--> Capture balance after
		INSERT INTO #afterUpd(custid										  
							, winlostdate
							, gametypeid
							, balance
							, winlost
							, TransId)
		SELECT	b.custid				  
			  , b.winlostdate
			  , b.bettype AS gametypeid
			  , (b.winlost - b.actual_stake + b.playercomm) AS balance 
			  , (CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END) AS winlost	
			  , b.TransId
		FROM bettrans b WITH (NOLOCK) 
			 INNER JOIN #RecoverBet t ON b.transid = t.TransId		

		INSERT INTO @afterUpd(custid, balance, balanceType)
		SELECT	CustID
			  , SUM (balance) AS balance 
			  , 4 AS balanceType
		FROM #afterUpd						 					 	  
		GROUP BY CustID

		--> INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			  @BeforeUpd = @beforeUpd
			, @AfterUpd	 = @afterUpd
		
		INSERT INTO #Balance (custid, balance, increased)
		SELECT b.custid, a.balance - b.balance, CASE WHEN a.balance > b.balance THEN 1 ELSE 0 END
		FROM @beforeUpd AS b
			INNER JOIN @afterUpd AS a ON b.custid = a.custid
		WHERE b.balance <> a.balance

		--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
		IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
		BEGIN
			INSERT INTO [dbo].[BalanceNegative]
						([ExecDate]
						,[MatchID]
						,[ActionID]
						,[GroupID]
						,[CustID]
						,[Balance]
						,[StatusID]
						,[Remark])
			SELECT	 GETDATE()
					,0
					,@ActionID
					,0		-- For Void/Recover
					,CustID
					,Balance
					,0
					,@spName
			FROM	#Balance
			WHERE	increased = 0
		END
		
		--> Build list of customer name with negative balance	: fix here				
		SET @CustIds = ''
		SELECT	@CustIds = @CustIds + CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + CONVERT(VARCHAR(20), custid)
		FROM #Balance
		WHERE Increased = 0
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT				

		DROP TABLE #Balance

		--> Insert data into pending balance game table
		INSERT INTO BalancePendingCreditGame (custid
											, winlostdate
											, balance
											, bettype
											, GameTypeID
											, RefID)
		SELECT a.custid
			 , a.winlostdate
			 , (a.winlost - b.winlost) AS Balance
			 , 1201 AS bettype
			 , a.gametypeid
			 , a.TransId
		FROM #beforeUpd b
			INNER JOIN #afterUpd a ON a.TransId = b.TransId						
		WHERE (a.winlost - b.winlost) > 0

		INSERT INTO BalancePendingDebitGame (custid
										   , winlostdate
										   , balance
										   , bettype
										   , GameTypeID
										   , RefID)
		SELECT a.custid
			 , a.winlostdate
			 , ABS(a.winlost - b.winlost) AS Balance
			 , 1201 AS bettype
			 , a.gametypeid
			 , a.TransId
		FROM #beforeUpd b
			INNER JOIN #afterUpd a ON a.TransId = b.TransId
		WHERE (a.winlost - b.winlost) < 0
		
		--> Delete zzzbettrans
		DELETE z
			OUTPUT deleted.transid, deleted.matchid, deleted.transdate, deleted.comstatus
			INTO @tmpTransInfo (transid, matchid, transdate, comstatus)
		FROM zzzbettrans z WITH(ROWLOCK, UPDLOCK)
			 INNER JOIN #RecoverBet t 
					 ON	z.transid = t.transid
						AND z.custid = t.custid
						AND z.matchid = t.matchid
						AND z.bettype = t.bettype

		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			INSERT INTO @tmpMatchidInfo (MatchId)
			SELECT DISTINCT MatchId FROM @tmpTransInfo

			WHILE (1=1)
			BEGIN
				UPDATE TOP(1)m
				SET IsFinish = 1, @matchid = MatchId 
				FROM @tmpMatchidInfo m
				WHERE IsFinish IS NULL

				IF @@ROWCOUNT = 0 BREAK;

				SET @TransInfo = COMPRESS((
				SELECT	matchid AS 'mid'
						, transId AS 't'
						, transdate AS 'td'
						, comstatus AS 'cst'
				FROM	@tmpTransInfo WHERE matchid = @MatchId 
				FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
				SELECT 'TVS', 'RecoverVS', 'zzzbettrans', 'D', @matchid, @TransInfo, 's', 1
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo

		END
		
		--> Release Concurrency process
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsExistVS				= 1
			, @isExistMatch				= 1
			, @isExistMatch3rd          = 1
			, @IsReleased				= 1	
		
		----------------Insert Max Payout Queue----------------
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL, @sporttype SMALLINT = NULL
		DECLARE @Match_tmp AS TABLE (matchId INT, sporttype SMALLINT, IsFinish BIT)

		INSERT INTO @Match_tmp (MatchId, sporttype)
		SELECT DISTINCT t.matchid, t.sporttype
		FROM #RecoverBet t

		WHILE (1=1)
		BEGIN
			SELECT @TransIds_MaxPO = '', @MatchId_MaxPO = NULL, @sporttype = NULL
		
			UPDATE TOP(1) mt SET mt.IsFinish = 1, @MatchId_MaxPO = mt.matchid, @sporttype = mt.sporttype
			FROM @Match_tmp mt
			WHERE mt.IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK

			SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
						,CASE 
							WHEN b.IsDeposit = 1 THEN 3 --deposit 
							WHEN s.SiteLabel = '789y' THEN 2 --789y
							ELSE 1 END AS '@sitetype'
						,b.TransId AS '@transid'
						,b.bettype AS '@bettype'
					FROM #RecoverBet b
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
					WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype
					FOR XML PATH('r'), ROOT('root')
				)

			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
				@MatchId = @MatchId_MaxPO
				,@sporttype = @sporttype
				,@TransidList = @TransIds_MaxPO
		END
		
		--Insert data for Max Payout NonSport
		WHILE (@TotalTransMaxPO > 0)
		BEGIN
			IF @TotalTransMaxPO > @batchPO
			BEGIN
				DELETE @tmpTransIDMaxPO

				DELETE TOP (@batchPO) t
					OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
					INTO @tmpTransIDMaxPO(custid, winlost, actualPO, transdate, bettype, transid)
				FROM	#RecoverBet t
				WHERE	IsApplyMaxPO = 1

				SET @TransInfoMaxPO = CAST((
										SELECT	TOP (@batchPO) CustId AS a1
												,178 AS a2 -- productid
												,0 AS a3 -- groupid
												,winlost AS a4 -- maxwinlimit
												,actualPO AS a6 -- winamt
												,255 AS a7 -- levelid
												,255 AS a8 -- actionid
												,@UserID AS a12 -- createdby
												,transdate AS a13 -- winlostdate
												,bettype AS a16
												,transid AS a17
										FROM	@tmpTransIDMaxPO
										FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
			END
			ELSE
			BEGIN
				SET @TransInfoMaxPO = CAST((
										SELECT	CustId AS a1
												,178 AS a2 -- productid
												,0 AS a3 -- groupid
												,winlost AS a4 -- maxwinlimit
												,actualPO AS a6 -- winamt
												,255 AS a7 -- levelid
												,255 AS a8 -- actionid
												,@UserID AS a12 -- createdby
												,transdate AS a13 -- winlostdate
												,bettype AS a16
												,transid AS a17
										FROM	#RecoverBet
										WHERE	IsApplyMaxPO = 1
										FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
			END

			SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO

			BEGIN TRY
				EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
					@XmlData = @TransInfoMaxPO
			END TRY
			BEGIN CATCH
				SELECT	 @ErrCode = ERROR_NUMBER()
						,@ErrMsg = ERROR_MESSAGE()				
			END CATCH
		END
		
		--> Return data to web	
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--> build data for @CompletedMatchIds					
		SET @CompletedMatchIds = ''
		
		;WITH CTE_CompletedMatch AS
		(
			SELECT DISTINCT matchid
			FROM #RecoverBet
			WHERE eventstatus = 'completed'
		)			
		SELECT @CompletedMatchIds = @CompletedMatchIds + CASE WHEN @CompletedMatchIds <> '' THEN ',' ELSE '' END + CAST(matchid AS VARCHAR(100))
		FROM CTE_CompletedMatch		
		
		--1. Return table validate
		SELECT @ErrCode AS ErrorCode
			  ,@ErrMsg AS ErrorMsg
			  ,@NegativeBalanceUsers AS NegativeBalanceUsers
			  ,@CompletedMatchIds AS CompletedMatchIds
				
		;WITH CTE_CustIdAll AS (
			SELECT DISTINCT t.custid
			FROM #RecoverBet b
			CROSS APPLY (
				VALUES (custid)
				      ,(creator)
				      ,(recommend)
				      ,(mrecommend)
				      ,(srecommend)
			) AS t (custid)
		)
		INSERT INTO #CTE_CustInfo (custid, username, username2, site, currency)
		SELECT ci.custid
			 , ci.username
			 , ci.username2
			 , ci.site
			 , ci.currency
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		

		SELECT  r.TransId,
				r.Stake,
				r.BetCheck,
				r.BetId,
				r.BetTeam,
				r.BetType,
				r.BetFrom,
				r.CurrencyCode,
				r.Hdp1,
				r.Hdp2,
				r.IsLiveIndicator,
				r.LiveAwayScore,
				r.LiveHomeScore,
				r.Odds,
				r.OddsType,
				r.RefNo,
				r.SportType,
				r.Status,
				r.TransDate,
				r.TransDesc,
				r.UserName,
				r.WinLost,
				T.GroupName,
				r.matchid,
				r.showtime,
				r.LeagueId,
				r.matchcode,
				r.HomeId,
				r.AwayId,
				r.modds AS MasterOdds,
				r.CustId AS UserId,
				r.recommend AS AgentId,
				ag.UserName AS AgentName,
				r.mrecommend AS MasterId,
				ma.UserName AS MasterName,
				r.srecommend AS SuperId,
				su.Username AS SuperName,
				ci.Site,
				ci.Site AS EmailGroup,
				CURRENT_TIMESTAMP AS [DateTime],
				@isITAdmin AS IsItSupport,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc
		FROM #RecoverBet r
			 INNER JOIN #CTE_CustInfo ci ON r.CustId = ci.custid
			 LEFT JOIN #CTE_CustInfo ag ON r.recommend = ag.custid
			 LEFT JOIN #CTE_CustInfo ma ON r.mrecommend = ma.custid
			 LEFT JOIN #CTE_CustInfo su ON r.srecommend = su.custid
			 CROSS APPLY (SELECT CASE 
									WHEN r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										 AND r.username <> '12EU'  
										 AND r.mrecommend NOT IN (105181, 118473, 105183)  
										 AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
										THEN 
											CASE WHEN r.IsDeposit = 0 THEN 'Credit'
												 WHEN r.IsDeposit = 1 THEN 'Deposit'
												 ELSE '' END
									ELSE '' END AS GroupName) AS T
		ORDER BY CASE
					WHEN T.GroupName = 'Credit'	 THEN 0
					WHEN T.GroupName = 'Deposit' THEN 1					
					ELSE 2				
				 END ASC					
	END TRY
	BEGIN CATCH	
		SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()
		
		IF @avaiableProcess = 1		
			--> Release Concurrency process			
			EXEC dbo.NAP_Admin_CheckingProcess
				  @IsExistVS				= 1
				, @isExistMatch				= 1
				, @isExistMatch3rd          = 1
				, @IsReleased				= 1	
		
		SELECT @ErrCode AS ErrorCode
			  ,@ErrMsg AS ErrorMsg
	END CATCH		
	
	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #ReCalMatchID_InspiredVS
	DROP TABLE #ReFundMatchID_InspiredVS
	DROP TABLE #RecoverBet
	DROP TABLE #beforeUpd
	DROP TABLE #afterUpd
	DROP TABLE #CTE_CustInfo

	SET NOCOUNT OFF	
END
GO