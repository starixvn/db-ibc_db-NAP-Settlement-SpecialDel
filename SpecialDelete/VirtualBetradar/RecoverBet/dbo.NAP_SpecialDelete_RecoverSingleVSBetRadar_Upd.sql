/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverSingleVSBetRadar_Upd]			
	@TransIds					VARCHAR(MAX),
    @UserID						INT,
    @IP							VARCHAR(15)
AS
/*  
	Created by: 20170607@Kent  
	Task: 
	DB: DBTXN/bodb02	    

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
		  , @avaiableProcess			  BIT	= 0
		  , @IsExistVSBetradar			  BIT = 0
		  , @IsExistInspiredVS			  BIT = 0
		  , @isITAdmin					  BIT	= 0
		  , @before_yesterday			  DATETIME
		  , @cnt_Ticket					  INT = 0
		  , @CustIds					  VARCHAR(MAX) = ''			  		 
		  , @i							  INT = 0
		  , @matchId					  INT
		  , @TicketType					  TINYINT		  
	
	DECLARE @cnt_RecalMatchInspiredVS	  INT = 0	
		  , @cnt_RefundMatchInspiredVS	  INT = 0		 
	
	DECLARE @IgnoreList				VARCHAR(200)  = ''
		  , @_xml					XML		
		  , @_sXML					VARCHAR(MAX)  = ''
		  , @TicketInfos_Recal 		VARCHAR(MAX) = ''
		  , @TicketInfos_Refund 	VARCHAR(MAX) = ''
		  , @CompletedMatchIds   VARCHAR(MAX)	= ''
		  , @NegativeBalanceUsers		VARCHAR(MAX)	= '' 
		  , @ErrMsg						NVARCHAR(200)	= ''
		  , @ErrCode					INT				= 0	
		  , @SiteDBGroupID		SMALLINT
		  , @transInfo				VARBINARY(MAX) 

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, transdate DATETIME, comstatus NVARCHAR(40) )
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
		  
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
		IsDeposit			BIT,
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
		SubStatus			NVARCHAR(10),
		SubTransId			BIGINT,
		SubBetCheck			NVARCHAR(50),
		SubBetTeam			NVARCHAR(10),
		SubBetType			SMALLINT,
		SubHdp1				SMALLMONEY,
		SubHdp2				SMALLMONEY,
		SubOdds				SMALLMONEY,
		SubCustId			INT,
		SubTransdesc		NVARCHAR(2000),		
		BetFrom				NVARCHAR(4),
		matchid				INT,
		[Action]			VARCHAR(100),
		TicketType			TINYINT -- 1 : VS Betradar, 2 : Inspired VS 180, 3 : Inspired VS 181
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
		winlost				MONEY		
	)
	
	CREATE TABLE #afterUpd	
	(
		custid				INT,
		winlostdate			SMALLDATETIME,
		gametypeid			SMALLINT,
		balance				MONEY,
		winlost				MONEY
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	DECLARE @beforeUpd 		TVP_BalanceChange		  
		  , @afterUpd 		TVP_BalanceChange		  		  		  		 		
	
	SELECT @before_yesterday = CONVERT(varchar(10), DATEADD(day, -2, GETDATE()), 120)	
		 , @CompletedMatchIds = ''		 
		 , @NegativeBalanceUsers = ''
		 , @ErrCode = 0
		 , @ErrMsg = ''
	
	BEGIN TRY	 
		--> parse @TransIds
		INSERT INTO #tblTransIds (transid)
		SELECT	t.value
		FROM STRING_SPLIT(@TransIds, ',') t					
		
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds
			
			RETURN
		END				 
		
		--> Search tickets			
		-- VS Betradar, Inspired VS 180				
		INSERT INTO #RecoverBet(
				Stake,
				AwayId,
				BetCheck,
				BetId,
				BetTeam,
				BetType,
				CurrencyCode,
				Hdp1,
				Hdp2,
				HomeId,
				IsLiveIndicator,
				LiveAwayScore,
				LiveHomeScore,
				Odds,
				OddsType,
				RefNo,
				SportType,
				Status,
				TransDate,
				TransDesc,
				TransId,
				UserName,
				WinLost,
				IsDeposit,
				recommend,
				mrecommend,
				srecommend,
				CustId,					
				eventdate,					
				showtime,
				creator,
				oddsid,
				LeagueId,
				matchcode,
				modds,
				SubStatus,
				SubTransId,
				SubBetCheck,
				SubBetTeam,
				SubBetType,
				SubHdp1,
				SubHdp2,
				SubOdds,
				SubTransdesc,
				BetFrom,
				matchid,					
				TicketType
		)
		SELECT  z.Stake,
				m.AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				m.HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				m.SportType,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				b.CustId,					
				m.eventdate,					
				ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime,
				z.creator,
				b.oddsid,
				m.leagueid,
				NULL AS matchcode,
				b.modds,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc,
				b.betfrom,
				b.matchid,					
				CASE 
					WHEN m.sporttype BETWEEN 190 AND 199 THEN 1 -- VS Betradar
					WHEN m.sporttype IN (180, 186) THEN 2 -- Inspired VS 180
					ELSE NULL
				END AS TicketType
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype
			 INNER JOIN dbo.match m WITH(NOLOCK)
					 ON m.matchid = b.matchid						 
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND z.winlostdate >= @before_yesterday
		  AND (
				m.sporttype BETWEEN 190 AND 199 -- VS Betradar
				OR m.sporttype IN (180, 186) -- Inspired VS 180
			  )
		  AND z.bettype NOT IN (2799)
		  AND z.SiteDBGroupID = @SiteDBGroupID
		  
		SET @cnt_Ticket = @cnt_Ticket + @@ROWCOUNT	
		
		-- Inspired VS 181
		INSERT INTO #RecoverBet(
				Stake,
				AwayId,
				BetCheck,
				BetId,
				BetTeam,
				BetType,
				CurrencyCode,
				Hdp1,
				Hdp2,
				HomeId,
				IsLiveIndicator,
				LiveAwayScore,
				LiveHomeScore,
				Odds,
				OddsType,
				RefNo,
				SportType,
				Status,
				TransDate,
				TransDesc,
				TransId,
				UserName,
				WinLost,
				IsDeposit,
				recommend,
				mrecommend,
				srecommend,
				CustId,					
				eventdate,					
				showtime,
				creator,
				oddsid,
				LeagueId,
				matchcode,
				modds,
				SubStatus,
				SubTransId,
				SubBetCheck,
				SubBetTeam,
				SubBetType,
				SubHdp1,
				SubHdp2,
				SubOdds,
				SubTransdesc,
				BetFrom,
				matchid,				
				TicketType
		)
		SELECT  z.Stake,
				0 AS AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				o.RacerID AS HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				r.SportType,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				b.CustId,					
				o.eventdate,					
				ISNULL(CONVERT(NVARCHAR(20), r.EventTime, 113), '') AS showtime,
				z.creator,
				b.oddsid,
				r.LeagueID,
				CONVERT(NVARCHAR(50), o.RacerNum) AS matchcode,
				b.modds,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc,
				b.betfrom,
				b.matchid,			
				3 AS TicketType -- Inspired VS 181
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype
			 INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
					 ON b.oddsid = o.Orid
			 INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					 ON r.EventID = o.EventID						 
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND z.winlostdate >= @before_yesterday
		  AND r.sporttype BETWEEN 181 AND 185 -- Inspired VS 181	
		  AND z.SiteDBGroupID = @SiteDBGroupID
		  
		SET @cnt_Ticket = @cnt_Ticket + @@ROWCOUNT		  			  			
			
		IF @cnt_Ticket = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'	

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds
			
			RETURN
		END				
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
		
		IF EXISTS ( SELECT TOP 1 1 FROM #RecoverBet WHERE eventdate <= @Movebetdate )
		BEGIN
			SELECT @ErrCode = 112
				 , @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds

			RETURN	
		END
		
		--> Check Concurrency				
		SELECT @isExistMatch	  = MAX(CASE WHEN TicketType IN (1, 2) THEN 1 ELSE 0 END)
			 , @IsExistVS		  = MAX(CASE WHEN TicketType = 3 THEN 1 ELSE 0 END)			 
			 , @IsExistVSBetradar = MAX(CASE WHEN TicketType = 1 THEN 1 ELSE 0 END)
			 , @IsExistInspiredVS = MAX(CASE WHEN TicketType IN (2, 3) THEN 1 ELSE 0 END)
		FROM #RecoverBet
			
		INSERT INTO #tblMatchProcess (matchid, KeyID)
		SELECT DISTINCT 
				matchid
			  , CASE 
					WHEN TicketType IN (1, 2) THEN 1 -- VS Betradar, Inspired VS 180
					ELSE 4 -- Inspired VS 181
				END AS KeyId
		FROM #RecoverBet
			
		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMatch				= @isExistMatch								
			, @spName					= @spName
			, @IsExistVS				= @IsExistVS
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT																		
		
		IF @ErrCode <> 0 OR @avaiableProcess = 0
		BEGIN
			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds

			RETURN
		END
						
		--> update [Action] to do on each searched tickets
		UPDATE #RecoverBet
		SET [Action] = CASE
							WHEN m.eventstatus = 'completed'
									THEN CASE
											WHEN m.betstatus LIKE '%' + 'Refund' + '%' THEN @Action_Refund
											ELSE @Action_Recal
										 END
							ELSE NULL
					   END
		  , eventstatus = m.eventstatus
		FROM #RecoverBet t
			 CROSS APPLY (
							SELECT TOP 1 eventstatus, betstatus
							FROM dbo.match m WITH(NOLOCK)
							WHERE m.matchid = t.matchid
							  AND t.TicketType IN (1, 2)
							UNION ALL
							SELECT TOP 1 r.eventstatus, r.betstatus
							FROM dbo.VSOutright o WITH (NOLOCK)											 
								 INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
										 ON r.EventID = o.EventID
							WHERE t.oddsid = o.Orid
							  AND t.TicketType = 3											 
						 ) AS m						 							 																								
		
		--> Capture balance before
		INSERT INTO #beforeUpd(custid										  
							 , winlostdate
							 , gametypeid
							 , balance
							 , winlost)
		SELECT	b.custid				  
			  , b.winlostdate
			  , b.bettype AS gametypeid
			  , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
			  , SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END) AS winlost				  
		FROM bettrans b WITH (NOLOCK) 
			 INNER JOIN #RecoverBet t 
					 ON	b.transid = t.TransId								 				 	  
		GROUP BY b.CustID, b.winlostdate, b.bettype

		INSERT INTO @beforeUpd(custid, balance, balanceType)
		SELECT	CustID
			  , SUM (balance) AS balance 
			  , 4 AS balanceType
		FROM #beforeUpd						 					 	  
		GROUP BY CustID
		
		DECLARE @tmpMatchId TABLE (matchId INT, Sporttype SMALLINT, IsFinish BIT)
		IF @IsExistVSBetradar = 1
		BEGIN	
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT b.MatchId
			FROM #RecoverBet b
			WHERE b.TicketType = 1

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
					WHERE TicketType = 1	AND matchid = @matchId	 					 
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC dbo.Bet_ExecRep_05 
					  @IgnoreList 	= @IgnoreList
					, @updatetype 	= 6
					, @_sXML 		= @_sXML
					, @matchId = @matchId
			END									
													
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
			DELETE @tmpMatchId
			INSERT INTO @tmpMatchId (MatchId)
			SELECT DISTINCT b.MatchId
			FROM #RecoverBet b
			WHERE b.TicketType IN (2, 3)

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
					WHERE TicketType IN (2, 3)	 AND matchid = @matchId		 					 
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
		
				EXEC dbo.Bet_ExecRep_05 
					  @IgnoreList 	= @IgnoreList
					, @updatetype 	= 6
					, @_sXML 		= @_sXML
					, @matchId		= @matchId
			END			

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
		
		--> Capture balance after
		INSERT INTO #afterUpd(custid										  
							, winlostdate
							, gametypeid
							, balance
							, winlost)
		SELECT	b.custid				  
			  , b.winlostdate
			  , b.bettype AS gametypeid
			  , SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
			  , SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END) AS winlost				  
		FROM bettrans b WITH (NOLOCK) 
			 INNER JOIN #RecoverBet t 
					 ON	b.transid = t.TransId								 				 	  
		GROUP BY b.CustID, b.winlostdate, b.bettype

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
		
		--> Insert data into pending balance game table
		INSERT INTO BalancePendingCreditGame (custid
											, winlostdate
											, balance
											, bettype
											, GameTypeID)
		SELECT a.custid
			 , a.winlostdate
			 , (a.winlost - b.winlost) AS Balance
			 , 1201 AS bettype
			 , a.gametypeid
		FROM #beforeUpd b
			INNER JOIN #afterUpd a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid						
		WHERE (a.winlost - b.winlost) > 0

		INSERT INTO BalancePendingDebitGame (custid
										   , winlostdate
										   , balance
										   , bettype
										   , GameTypeID)
		SELECT a.custid
			 , a.winlostdate
			 , ABS(a.winlost - b.winlost) AS Balance
			 , 1201 AS bettype
			 , a.gametypeid
		FROM #beforeUpd b
			INNER JOIN #afterUpd a 
				ON	a.custid = b.custid
					AND a.winlostdate = b.winlostdate
					AND a.gametypeid = b.gametypeid
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
							WHEN dp.custid IS NOT NULL THEN 3 --deposit 
							WHEN s.SiteLabel = '789y' THEN 2 --789y
							ELSE 1 END AS '@sitetype'
						,b.TransId AS '@transid'
						,b.bettype AS '@bettype'
					FROM #RecoverBet b
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
						LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
					WHERE b.matchid = @MatchId_MaxPO AND b.sporttype = @sporttype
					FOR XML PATH('r'), ROOT('root')
				)

			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Recover
				@MatchId = @MatchId_MaxPO
				,@sporttype = @sporttype
				,@TransidList = @TransIds_MaxPO
		END
		
		--> Build list of customer name with negative balance	: fix here				
		SET @NegativeBalanceUsers = ''				
		
		SELECT @CustIds = @CustIds +
						  CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + 
						  CONVERT(VARCHAR(20), b.custid)
		FROM @beforeUpd b
			 INNER JOIN	@afterUpd a 	
					 ON a.custid = b.custid
		WHERE b.balance > a.balance	
		
		EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
			@CustIds = @CustIds,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT							
		
		--> build data for @CompletedMatchIds					
		SET @CompletedMatchIds = ''
		
		;WITH CTE_CompletedMatch AS
		(
			SELECT DISTINCT matchid
			FROM #RecoverBet
			WHERE eventstatus = 'completed'
		)			
		SELECT @CompletedMatchIds = @CompletedMatchIds
									+ CASE WHEN @CompletedMatchIds <> '' THEN ',' ELSE '' END
									+ CAST(matchid AS VARCHAR(100))
		FROM CTE_CompletedMatch							
		
		--> Return data to web	
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--1. Return table validate
		SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds
				
		SELECT  r.Stake,
				r.AwayId,
				r.BetCheck,
				r.BetId,
				r.BetTeam,
				r.BetType,
				r.CurrencyCode,
				r.Hdp1,
				r.Hdp2,
				r.HomeId,
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
				r.TransId,
				r.UserName,
				r.WinLost,
				T.GroupName,
				r.showtime,
				r.LeagueId,
				r.matchcode,
				r.modds,
				r.matchid,
				r.SubStatus,
				r.SubTransId,
				r.SubBetCheck,
				r.SubBetTeam,
				r.SubBetType,
				r.SubHdp1,
				r.SubHdp2,
				r.SubOdds,
				r.SubTransdesc,
				r.CustId AS UserId,
				r.recommend AS AgentId,
				ag.UserName AS AgentName,
				r.mrecommend AS MasterId,
				ma.UserName AS MasterName,
				r.srecommend AS SuperId,
				su.Username AS SuperName,
				ag.Site,
				ag.Site AS EmailGroup,
				CURRENT_TIMESTAMP AS [DateTime],
				@isITAdmin AS IsItSupport,
				r.BetFrom 
		FROM #RecoverBet r
			 LEFT JOIN CustDB.dbo.Customer ag WITH(NOLOCK)
					 ON r.recommend = ag.custid
			 LEFT JOIN CustDB.dbo.Customer ma WITH(NOLOCK)
					 ON r.mrecommend = ma.custid
			 LEFT JOIN CustDB.dbo.Customer su WITH(NOLOCK)
					 ON r.srecommend = su.custid
			 CROSS APPLY (SELECT CASE 
									WHEN r.IsDeposit = 0  
										 AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										 AND r.username <> '12EU'  
										 AND r.mrecommend NOT IN (105181, 118473, 105183)  
										 AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
												THEN 'Credit'
									WHEN r.IsDeposit = 1  
										 AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										 AND r.username <> '12EU'  
										 AND r.mrecommend NOT IN (105181, 118473, 105183) 
										 AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
												THEN 'Deposit'																				
									ELSE ''							
								 END AS GroupName) AS T
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
				, @IsReleased				= 1	
		
		SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@CompletedMatchIds AS CompletedMatchIds
	END CATCH		
	
	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #ReCalMatchID_InspiredVS
	DROP TABLE #ReFundMatchID_InspiredVS
	DROP TABLE #RecoverBet
	DROP TABLE #beforeUpd
	DROP TABLE #afterUpd

	SET NOCOUNT OFF	
END
GO