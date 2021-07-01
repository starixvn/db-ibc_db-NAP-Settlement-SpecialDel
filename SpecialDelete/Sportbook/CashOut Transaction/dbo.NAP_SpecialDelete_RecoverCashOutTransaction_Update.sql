/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverCashOutTransaction_Update]
	@TransIds			VARCHAR(MAX),
	@UserId				INT,
	@IP					VARCHAR(50)		= '',
	@ErrCode			INT				= 0		OUTPUT,
	@ErrMsg				NVARCHAR(200)	= ''	OUTPUT,
	@InvalidTransIds	VARCHAR(MAX)	= ''	OUTPUT	
AS
/*
    Created by: Kent
	Date: 20170403
	Original: 
	Task: Recover CashOut transaction
	DB: DBTXN/BODB02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]		
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]	
		
	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON		
	
	DECLARE @LogData			NVARCHAR(500)			
		  , @avaiableProcess 	BIT = 0
		  , @isITAdmin			BIT = 0
		  , @Movebetdate		DATETIME

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
	DECLARE @before_yesterday DATETIME		  		  
		  
	CREATE TABLE #tblTransIds (transid BIGINT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	
	CREATE TABLE #SpecialDeleteBets (		
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				MONEY,
		OddsType			INT,		
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,		
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,		
		RefNo				BIGINT,		
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		MainStatusId		TINYINT,		
		MainStatus			NVARCHAR(10),
		MainStatusWinlost	TINYINT,
		MainRuben			TINYINT,
		MainTransId			BIGINT,		
		UserName			VARCHAR(30),		
		TransDate			DATETIME,		
		OriginalBetType		SMALLINT,
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,		
		BetFrom				NVARCHAR(1),
		matchid				INT,
		awinlost			MONEY,		
		CurrencyName		NVARCHAR(50),		
		actual_stake		MONEY,				
		MainActualStake		MONEY,
		MainMOdds			SMALLMONEY,			
		WinLost				MONEY,
		Status				NVARCHAR(10),
		zzzCreator			INT,		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME		
	)			
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange
	
	CREATE TABLE #CashOutSubTicket
	(
		transid				BIGINT PRIMARY KEY,
		refno				BIGINT,
		bettype				SMALLINT,
		custid				INT,
		matchid				INT,
		awinlost			MONEY,
		Stake				MONEY,
		MainTransId			BIGINT,
		MainStatusId		TINYINT,		
		MainActualStake		MONEY,
		MainMOdds			SMALLMONEY,
		MainBettype			SMALLINT,
		zzzCreator			INT,
		actual_stake		MONEY
	) -- store 911,912,913,cash-out bet ticket
	
	CREATE TABLE #CashOutMainTicket
	(
		transid			BIGINT PRIMARY KEY,		
		bettype			SMALLINT,
		statusId		TINYINT,
		modds			SMALLMONEY,		
		Status			NVARCHAR(10),
		StatusWinlost	TINYINT,
		ruben			TINYINT,				
		Sum_Stake		MONEY		
	) -- store main cash-out
	
	CREATE TABLE #tblCustCashOut912 
	(
		custid INT, 
		matchid INT
	) --store Cash-Out's custid
	
	CREATE TABLE #Invalid911TransIds
	(
		transid	BIGINT
	)
	
	SELECT @ErrCode	= 0
		 , @ErrMsg = ''
		 , @InvalidTransIds	= ''
	
	SELECT @before_yesterday = CONVERT(varchar(10), DATEADD(day, -2, GETDATE()), 120)
	
	--> parse @TransIds
	INSERT INTO #tblTransIds (transid)
	SELECT	t.val
	FROM dbo.f_SplitString(@TransIds, ',') t					
	OPTION (maxrecursion 0)			
	
	--> get 911	
	INSERT INTO #SpecialDeleteBets(					
					TransId,
					BetType,
					BetTeam,
					Stake,
					Odds,
					OddsType,					
					Hdp1,
					Hdp2,					
					IsLiveIndicator,
					LiveHomeScore,
					LiveAwayScore,					
					RefNo,										
					BetCheck,
					TransDesc,
					MainStatusId,					
					MainStatus,
					MainStatusWinlost,
					MainRuben,
					MainTransId,					
					UserName,						
					TransDate,						
					OriginalBetType,
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,					
					betfrom,
					matchid,
					awinlost,					
					MainActualStake,
					MainMOdds,										
					CurrencyName,					
					actual_stake,					
					WinLost,
					Status,
					zzzCreator,					
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode,
					EventDate
		)	
	SELECT 	sub.TransId,
			sub.BetType,
			main.BetTeam,
			sub.Stake,
			main.Odds,
			main.OddsType,			
			main.Hdp1,
			main.Hdp2,			
			main.liveindicator AS IsLiveIndicator,
			main.LiveHomeScore,
			main.LiveAwayScore,			
			sub.RefNo,						
			main.BetCheck,
			main.TransDesc,
			main.statusID AS MainStatusId,			
			main.status AS MainStatus,
			main.statuswinlost AS MainStatusWinlost,
			main.ruben AS MainRuben,
			main.transid AS MainTransId,			
			sub.UserName,				
			sub.TransDate,				
			main.bettype AS OriginalBetType,
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			main.recommend,			
			main.betfrom,
			sub.matchid,
			sub.awinlost,			
			main.actual_stake AS MainActualStake,
			main.modds AS MainMOdds,						
			main.CurrencyName,			
			sub.actual_stake,			
			z.winlost - sub.actual_stake as Winlost,
			z.Status,
			z.creator AS zzzCreator,			
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.eventdate
	FROM dbo.zzzbettrans z WITH(NOLOCK)
		 INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			     ON	z.transid = sub.transid
					AND z.bettype = sub.bettype
					AND z.matchid = sub.matchid	
					AND z.custid = sub.custid			
		 INNER JOIN dbo.match m WITH(NOLOCK)
				 ON m.matchid = z.matchid
		 INNER JOIN dbo.bettrans main WITH(NOLOCK)
				 ON main.transid = sub.refno
					AND main.custid = sub.custid
					AND main.matchid = sub.matchid				    
	WHERE sub.transid IN (SELECT t.transid FROM #tblTransIds t)
	  AND main.winlostdate >= @before_yesterday						
	  AND sub.bettype = 911			
	  AND main.statusID <> 102
	  AND sub.statusID = 102
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS ( SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE EventDate <= @Movebetdate )
	BEGIN
		SELECT @ErrCode = 100
			 , @ErrMsg = 'Match is under Movebet process, could not recover ticket.'

		RETURN	
	END
	
	--> check sum invalid		
	DELETE sd
	OUTPUT deleted.TransId INTO #Invalid911TransIds(transid)
	FROM #SpecialDeleteBets sd
		 INNER JOIN (
						SELECT Refno
						FROM #SpecialDeleteBets
						GROUP BY Refno, MainActualStake
						HAVING MainActualStake < SUM(actual_stake)
					) AS t
				 ON sd.Refno = t.Refno
				 	
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid, refno)
	SELECT transid, RefNo
	FROM #SpecialDeleteBets	
	
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
		  @Mode = '911'
		, @Action = 'Recover'
		, @IsReleased = 0
	
	DELETE bd
	FROM #SpecialDeleteBets bd
		 INNER JOIN #tblCashOutProcess rp
				 ON bd.transid = rp.transid					
					AND rp.IsAvailable = 0
	
	-- return invalid transId
	SELECT @InvalidTransIds = @InvalidTransIds
							+ CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END
							+ CAST(T.transid AS VARCHAR(50))
	FROM (
			SELECT transid
			FROM #Invalid911TransIds
			UNION ALL
			SELECT transid
			FROM #tblCashOutProcess
			WHERE IsAvailable = 0
		 ) AS T				 						
	
	--> check no data
	IF (NOT EXISTS( SELECT 1 FROM #SpecialDeleteBets))
	BEGIN
		IF @InvalidTransIds = ''		
			SELECT @ErrMsg = 'No ticket found.'
				 , @ErrCode  = 101				
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = '911'
			  , @Action = 'Recover' 
			  , @IsReleased = 1
		
		RETURN
	END
	
	--> check and not allow attempt to void tickets of this match while it's being calculated
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		 , 1 AS KeyID
	FROM #SpecialDeleteBets		
		
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = '911' 
			  , @Action = 'Recover'
			  , @IsReleased = 1
		
		RETURN
	END	
	
	--> copy 911 to #CashOutSubTicket
	INSERT INTO #CashOutSubTicket(transid
								, refno
								, bettype
								, custid
								, matchid
								, awinlost
								, Stake
								, MainTransId
								, MainStatusId								
								, MainActualStake
								, MainMOdds	
								, MainBettype							
								, zzzCreator
								, actual_stake)
	SELECT TransId
		 , RefNo
		 , BetType
		 , custid
		 , matchid
		 , awinlost	
		 , Stake
		 , MainTransId
		 , MainStatusId		 
		 , MainActualStake
		 , MainMOdds
		 , OriginalBetType		 
		 , zzzCreator
		 , actual_stake
	FROM #SpecialDeleteBets			 	 		

	--> get main cash-out	
	INSERT INTO #CashOutMainTicket(transid, bettype, statusId, modds
								 , Status, StatusWinlost, Ruben
								 , Sum_Stake)
	SELECT Refno AS transid, OriginalBetType AS bettype, MainStatusId AS statusId, MainMOdds AS modds
		 , MainStatus AS Status, MainStatusWinlost AS StatusWinlost, MainRuben AS Ruben	     
		 , SUM(stake) AS Sum_Stake
	FROM #SpecialDeleteBets		
	GROUP BY Refno, OriginalBetType, MainStatusId, MainMOdds
		   , MainStatus, MainStatusWinlost, MainRuben
	
	--> get 912,913,cash-out bet ticket
	INSERT INTO #SpecialDeleteBets(					
				TransId,
				BetType,
				WinLost,
				Status,
				RefNo,
				TransDate,
				OriginalBetType,
				custid,
				zzzCreator,				
				BetTeam,
				Stake,
				Odds,
				OddsType,				
				Hdp1,
				Hdp2,				
				IsLiveIndicator,
				LiveHomeScore,
				LiveAwayScore,																	
				BetCheck,
				TransDesc,
				MainTransId,
				MainStatusId,
				UserName,				
				ExtraInfo,
				BetdaqId,				
				recommend,
				betfrom,
				matchid,
				awinlost,				
				MainActualStake,
				MainMOdds,								
				CurrencyName,				
				actual_stake,				
				HomeId,
				AwayId,
				LeagueId,
				SportTypeId,
				IsNeutral,
				MatchCode,
				EventDate
			)
	OUTPUT inserted.TransId
		 , inserted.RefNo
		 , inserted.BetType
		 , inserted.custid
		 , inserted.matchid
		 , inserted.awinlost	
		 , inserted.Stake
		 , inserted.MainTransId
		 , inserted.MainStatusId		
		 , inserted.MainActualStake
		 , inserted.MainMOdds
		 , inserted.OriginalBetType		 
		 , inserted.zzzCreator
		 , inserted.actual_stake
			INTO #CashOutSubTicket(transid
								 , refno
								 , bettype
								 , custid
								 , matchid
								 , awinlost
								 , Stake
								 , MainTransId
								 , MainStatusId								 
								 , MainActualStake
								 , MainMOdds
								 , MainBettype								 
								 , zzzCreator
								 , actual_stake) 
	SELECT  sub.TransId,
			sub.BetType,
			z.winlost - sub.actual_stake as Winlost,
			z.Status,
			sub.RefNo,
			sub.TransDate,				
			sub911.OriginalBetType,
			sub.custid,
			z.creator AS zzzCreator,			
			sub911.BetTeam,
			sub.Stake,
			sub911.Odds,
			sub911.OddsType,			
			sub911.Hdp1,
			sub911.Hdp2,			
			sub911.IsLiveIndicator,
			sub911.LiveHomeScore,
			sub911.LiveAwayScore,												
			sub911.BetCheck,
			sub911.TransDesc,
			sub911.MainTransId,
			sub911.MainStatusId,
			sub.UserName,							
			sub.ExtraInfo,
			sub.BetdaqId,			
			sub.recommend,
			sub.betfrom,
			sub.matchid,
			sub.awinlost,			
			sub911.MainActualStake,
			sub911.MainMOdds,						
			sub.CurrencyName,			
			sub.actual_stake,			
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.eventdate	
	FROM #SpecialDeleteBets sub911 WITH(NOLOCK)
		 CROSS APPLY (SELECT sub.*
					  FROM dbo.bettrans sub WITH(NOLOCK)
					  WHERE sub911.transid = sub.refno
					    AND sub911.matchid = sub.matchid				        
						AND sub.bettype IN (sub911.OriginalBetType, 912, 913)) AS sub
		 INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				 ON z.transid = sub.transid
					AND z.bettype = sub.bettype
					AND z.matchid = sub.matchid
					AND z.custid = sub.custid				
		 INNER JOIN dbo.match m WITH(NOLOCK)
				 ON m.matchid = z.matchid															
	
	--> insert #tblCustCashOut912
	INSERT INTO #tblCustCashOut912(custid, matchid)
	SELECT DISTINCT custid, matchid
	FROM #CashOutSubTicket
	WHERE bettype = 912
	
	--> capture before
	INSERT INTO @BeforeUpd (custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		-- main cash-out + 911,912,913,cash-out bet ticket
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN (SELECT transid FROM #CashOutMainTicket
						UNION ALL
						SELECT transid FROM #CashOutSubTicket) s
			ON s.transId = b.transid
		UNION ALL		
		-- cash-out summary 914
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tblCustCashOut912 temp
			ON b.matchid 	= temp.matchid 
			AND b.custid 	= temp.custid
		WHERE b.bettype 	= 914
	) AS temp
	GROUP BY temp.custid							
	
	DECLARE @statusid TINYINT
	--> update SOLD tickets (911)
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusid = b.statusID = CASE
									WHEN sub911.MainStatusId = 103 THEN 103
									WHEN sub912.actual_stake < b.actual_stake THEN 113
									WHEN sub912.actual_stake > b.actual_stake THEN 112
									ELSE 111
									END
		,b.status = CASE 
						WHEN @statusid = 103 THEN 'Refund'
						WHEN @statusid = 113 THEN 'LOSE'
						WHEN @statusid = 112 THEN 'WON'
						ELSE 'DRAW'
						END										
		,b.winlost = CASE WHEN @statusid = 103 THEN b.actual_stake ELSE sub912.actual_stake END
		,b.awinlost = CASE WHEN @statusid = 103 THEN 0 ELSE b.actual_stake - sub912.actual_stake END
		,b.mwinlost = 0
		,b.swinlost = 0
		,b.playercomm = 0
		,b.comm = 0
		,b.acomm = 0
		,b.scomm = 0 
		,b.statuswinlost = CASE WHEN @statusid = 103 THEN 0 ELSE NULL END
		,b.ruben = 1
		,b.creator = sub911.zzzCreator
	FROM dbo.bettrans b
		 INNER JOIN #CashOutSubTicket sub911
				 ON b.transid = sub911.transid
					AND sub911.bettype = 911
		 INNER JOIN #CashOutSubTicket sub912
				 ON sub911.transid = sub912.refno
					AND sub912.bettype = 912
	
	--> update BOUGHT tickets (912)
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusid = b.statusID = CASE
									WHEN sub912.MainStatusId = 103 THEN 103
									WHEN sub911.actual_stake < b.actual_stake THEN 113
									WHEN sub911.actual_stake > b.actual_stake THEN 112
									ELSE 111
									END
		,b.status = CASE 
						WHEN @statusid = 103 THEN 'Refund'
						WHEN @statusid = 113 THEN 'LOSE'
						WHEN @statusid = 112 THEN 'WON'
						ELSE 'DRAW'
						END										
		,b.winlost = CASE WHEN @statusid = 103 THEN b.actual_stake ELSE sub911.actual_stake END
		,b.awinlost = CASE WHEN @statusid = 103 THEN 0 ELSE b.actual_stake - sub911.actual_stake END
		,b.mwinlost = 0
		,b.swinlost = 0
		,b.playercomm = 0
		,b.comm = 0
		,b.acomm = 0
		,b.scomm = 0 
		,b.statuswinlost = CASE WHEN @statusid = 103 THEN 0 ELSE NULL END
		,b.ruben = 1
		,b.creator = sub912.zzzCreator 
	FROM dbo.bettrans b
		 INNER JOIN #CashOutSubTicket sub912
				 ON b.transid = sub912.transid
					AND sub912.bettype = 912
		 INNER JOIN #CashOutSubTicket sub911
				 ON sub912.refno = sub911.transid
					AND sub911.bettype = 911								 						 								 
	
	--> update COMM tickets (913)
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusid = b.statusID = CASE WHEN sub913.MainStatusId = 103 THEN 103 ELSE 113 END
		,b.status = CASE WHEN @statusid = 103 THEN 'Refund'	ELSE 'LOSE' END		
		,b.winlost = CASE WHEN @statusid = 103 THEN b.actual_stake ELSE sub912.actual_stake * b.odds END
		,b.awinlost = CASE WHEN @statusid = 103 THEN 0 ELSE b.discount * sub912.actual_stake END
		,b.mwinlost = 0
		,b.swinlost = 0
		,b.playercomm = 0
		,b.comm = 0
		,b.acomm = 0
		,b.scomm = 0
		,b.statuswinlost = CASE WHEN @statusid = 103 THEN 0 ELSE NULL END
		,b.ruben = 1
		,b.creator = sub913.zzzCreator		
	FROM dbo.bettrans b
		 INNER JOIN #CashOutSubTicket sub913
				 ON b.transid = sub913.transid
					AND sub913.bettype = 913
		 INNER JOIN #CashOutSubTicket sub912 
				 ON sub913.refno = sub912.refno 
					AND sub912.bettype = 912		 									
						    
	--> update cash-out bet ticket
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET statusID = t_main.statusID
	  , status = t_main.status
	  , statuswinlost = t_main.statuswinlost						
	  , ruben = t_main.ruben				
	  , creator = t.zzzCreator
	  , modds = t_main.modds	  	  
	FROM dbo.bettrans b 
		INNER JOIN #CashOutSubTicket AS t
			    ON b.transid = t.transId
				   AND t.bettype NOT IN (911,912,913)
		INNER JOIN #CashOutMainTicket AS t_main
				ON t.MainTransId = t_main.transid
				
	--> re-calculate stake, re-settle for main cash-out + update cash-out bet ticket			
	;WITH CTE_main_cashoutticket AS
	(
		SELECT transid
			 , 1 AS TicketType
			 , statusID AS MainStatusId			 
			 , modds
			 , Sum_Stake							 
		FROM #CashOutMainTicket
		UNION ALL
		SELECT transid
			 , 2 AS TicketType
			 , MainStatusId			 
			 , MainMOdds AS modds
			 , NULL AS Sum_Stake							  
		FROM #CashOutSubTicket
		WHERE bettype NOT IN (911,912,913)
	)
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET stake = TRef.stake
	  , actual_stake = TRef.actual_stake
	  , betdaqid = CASE t.TicketType WHEN 1 THEN 0 WHEN 2 THEN b.betdaqid END
	  
	  , winlost = TCal.winlost
	  , awinlost = TCal.awinlost
	  , mWinLost = TCal.mWinLost
	  , swinlost = TCal.swinlost
	  
	  , playercomm = TCal.playercomm
	  , comm = TCal.comm
	  , acomm = TCal.acomm
	  , scomm = TCal.scomm
	FROM dbo.bettrans b 
		INNER JOIN CTE_main_cashoutticket AS t
			    ON b.transid = t.transId	    			
		OUTER APPLY (
						SELECT CASE t.TicketType
									WHEN 1 THEN b.stake - t.Sum_Stake 
									WHEN 2 THEN b.stake
							   END AS stake
							 , CASE t.TicketType
									WHEN 1 THEN CASE
													WHEN b.odds < 0 THEN (b.stake - t.Sum_Stake) * abs(b.odds)
													ELSE (b.stake - t.Sum_Stake)
												END
									WHEN 2 THEN b.actual_stake 
							   END AS actual_stake
							   
							 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 0 ELSE 1 END AS CommWinRate
							 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 2 ELSE 1 END AS CommLostRate
							 
							 , CASE 
									WHEN b.odds<0 THEN 1 
									ELSE (CASE 
											WHEN b.bettype in (SELECT f.BetType 
															   FROM [dbo].[f_Set_GetCashOutBettypes]() f
															   WHERE f.IsDecimalOnly = 1) 
													THEN b.odds-1 
											ELSE b.odds 
										  END) 
								END AS odds
					) AS TRef		
		OUTER APPLY (SELECT CASE 
								WHEN b.statusId = 0 THEN 0
								WHEN b.statusId = 103 THEN TRef.actual_stake 								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds
																			WHEN t.modds =  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds * 0.5
																			WHEN t.modds =  0	 THEN TRef.actual_stake	
																			WHEN t.modds = -0.25 THEN TRef.actual_stake * 0.5
																			WHEN t.modds < -0.25 THEN 0
																	  END 								
								ELSE b.winlost 
							END AS winlost
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25 THEN TRef.stake * TRef.odds * -b.apositiontaking
																			WHEN t.modds =  0.25 THEN TRef.stake * TRef.odds * -b.apositiontaking * 0.5
																			WHEN t.modds =  0	 THEN 0	
																			WHEN t.modds = -0.25 THEN TRef.actual_stake * b.apositiontaking * 0.5
																			WHEN t.modds < -0.25 THEN TRef.actual_stake * b.apositiontaking
																	  END								
								ELSE b.awinlost 
							END AS awinlost
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.stake * TRef.odds * -b.mpositiontaking
																			WHEN t.modds =  0.25  THEN TRef.stake * TRef.odds * -b.mpositiontaking * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.actual_stake * b.mpositiontaking * 0.5
																			WHEN t.modds < -0.25  THEN TRef.actual_stake * b.mpositiontaking
																	  END								
								ELSE b.mWinLost 
							END AS mWinLost
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.stake * TRef.odds * -b.spositiontaking
																			WHEN t.modds =  0.25  THEN TRef.stake * TRef.odds * -b.spositiontaking * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.actual_stake * b.spositiontaking * 0.5
																			WHEN t.modds < -0.25  THEN TRef.actual_stake * b.spositiontaking
																	  END								
								ELSE b.swinlost 
							END AS swinlost
						  
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake
																			WHEN t.modds =  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake * 0.5
																			WHEN t.modds < -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake
																	  END								
								ELSE b.playercomm 
							END AS playercomm
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.commWinRate * b.discount * TRef.stake * (1-b.apositiontaking)
																			WHEN t.modds =  0.25  THEN TRef.commWinRate * b.discount * TRef.stake * (1-b.apositiontaking) * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.commLostRate * b.discount * TRef.stake * (1-b.apositiontaking) * 0.5
																			WHEN t.modds < -0.25  THEN TRef.commLostRate * b.discount * TRef.stake * (1-b.apositiontaking)
																	  END								
								ELSE b.comm 
							END AS comm
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.commWinRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking))
																			WHEN t.modds =  0.25  THEN TRef.commWinRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.commLostRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN t.modds < -0.25  THEN TRef.commLostRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking))
																	  END								
								ELSE b.acomm 
							END AS acomm
						  , CASE 
								WHEN b.statusId IN (0, 103) THEN 0								
								WHEN b.statusId IN (111,112,113) THEN CASE
																			WHEN t.modds >  0.25  THEN TRef.commWinRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
																			WHEN t.modds =  0.25  THEN TRef.commWinRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN t.modds =  0	  THEN 0	
																			WHEN t.modds = -0.25  THEN TRef.commLostRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN t.modds < -0.25  THEN TRef.commLostRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
																	  END								
								ELSE b.scomm 
							END AS scomm) AS TCal														    														
	
	--> Pre-CAL 914
	BEGIN TRY
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))
		INSERT INTO @TempData(MatchId, CustIds)
		SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
							   FROM #tblCustCashOut912 tt 
							   where tt.MatchId = t.MatchId
							   FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
		FROM #tblCustCashOut912 t
		GROUP BY MatchId
		
		DECLARE @RowId INT, @MatchIdTmp INT, @CustIds VARCHAR(MAX)
		SELECT @RowId = 1
		WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
		BEGIN
			SELECT @MatchIdTmp = MatchId
				 , @CustIds = CustIds
			FROM @TempData t 
			WHERE RowId = @RowId
			
			EXEC dbo.NAP_Admin_Calculate_914 
				  @MatchId 	= @MatchIdTmp
				, @Action 	= 'VOID'
				, @CustIds 	= @CustIds
				
			SET @RowId = @RowId + 1
		END
		
	END TRY 
	BEGIN CATCH
		SELECT	@ErrCode = 914
			  , @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
	END CATCH
	
	--> capture after
	INSERT INTO @AfterUpd(custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		-- main cash-out + 911,912,913,cash-out bet ticket
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN (SELECT transid FROM #CashOutMainTicket
						UNION ALL
						SELECT transid FROM #CashOutSubTicket) s
			ON s.transId = b.transid
		UNION ALL		
		-- cash-out summary 914
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tblCustCashOut912 temp
			ON b.matchid 	= temp.matchid 
			AND b.custid 	= temp.custid
		WHERE b.bettype 	= 914
	) AS temp
	GROUP BY temp.custid
	
	--> compare BALANCE
	EXEC [dbo].[NAP_Admin_BalancePendingIns]
		@BeforeUpd	 = @beforeUpd
		, @AfterUpd	 = @afterUpd
	
	--> update bettradesellingcancelled
	CREATE TABLE #CustList
	(
		custid INT PRIMARY KEY,
		Balance MONEY
	)
	
	INSERT INTO #CustList(custid, Balance)
	SELECT T.custid, SUM(T.Balance)
	FROM
	(
		SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
		FROM	dbo.bettrans b WITH(NOLOCK)
			LEFT JOIN dbo.translog tl WITH(NOLOCK)
				ON	b.refno = tl.translogid
					AND b.matchid = tl.eventID
		WHERE	b.custid IN (SELECT custid FROM #CashOutSubTicket)
				AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))				
		UNION ALL 
		SELECT	tl.custid, 0 - tl.actual_stake + 0 AS Balance 
		FROM	dbo.translog tl WITH(NOLOCK)
		WHERE	tl.custid IN (SELECT custid FROM #CashOutSubTicket)
				AND tl.statusID IN (0, 1)				
		UNION ALL
		SELECT	custid, winlost - actual_stake + playercomm AS Balance
		FROM	dbo.bettransRnG WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM #CashOutSubTicket)
				AND IsSum=0				
		UNION ALL
		SELECT	custid, winlost - actual_stake + playercomm AS Balance
		FROM	dbo.bettransLC WITH(NOLOCK)
		WHERE	custid IN (SELECT custid FROM #CashOutSubTicket) 
				AND IsSum=0	
		UNION ALL
		SELECT bal.CustId, (Credit - Debit) AS Balance
		FROM dbo.BalNetPosition bal WITH(NOLOCK)
			INNER JOIN #CashOutSubTicket d 
					 ON bal.CustId = d.CustId 
						AND bal.MatchId = d.MatchId 
						AND bal.Bettype = d.bettype	
		UNION ALL
		SELECT DISTINCT c.CustId, c.Credit AS Balance
		FROM DBCUST.custDB.dbo.custInfo c WITH(NOLOCK)						
			 INNER JOIN #CashOutSubTicket d 
					 ON c.CustId = d.CustId
	) T
	GROUP BY T.custid
	
	UPDATE btsc
		SET Remark = 'SB recover ticket'
			,BTBuyBack = tmpsub.awinlost - sub.awinlost
			,AfterBalance = tcust.Balance
			,Cancelled = 0
			,ChangeDate = CURRENT_TIMESTAMP
	FROM	dbo.BetTradeSellingCancelled btsc WITH(ROWLOCK, UPDLOCK)
		INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)
			ON bts.TradeID = btsc.TradeID
		INNER JOIN #CashOutSubTicket tmpsub 
			ON bts.TicketID = tmpsub.refno
			   AND bts.SoldTicketID = tmpsub.transid
			   AND tmpsub.bettype = 911 
		INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			ON tmpsub.transid = sub.transid
		INNER JOIN #CustList tcust
			ON tmpsub.custid = tcust.custid
	
	--> delete zzzbettrans
	DELETE z		
	FROM dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
		 INNER JOIN #CashOutSubTicket t
				 ON z.transid = t.transid
					AND z.custid = t.custid
					AND z.matchid = t.matchid
					AND z.bettype = t.bettype
	
	--> write log								 
	SELECT @LogData = 'Recover CashOut transactions have transid: ' + @TransIds + ' IP: ' + @Ip
	EXEC WriteLog_UserLog 
		 @UserId = @UserId,
		 @Doing = @LogData 
	
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		, @IsReleased		= 1	
		
	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = '911' 
		  , @Action = 'Recover'
		  , @IsReleased = 1		
	
	--> output data
	-- CHECK IT GROUP or NOT ?  
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0) 
		
	SELECT  d.TransId,
			d.BetType,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,			
			d.Hdp1,
			d.Hdp2,			
			d.IsLiveIndicator,
			d.LiveHomeScore,
			d.LiveAwayScore,			
			d.RefNo,					
			d.BetCheck,
			d.TransDesc,
			d.MainStatusId,
			d.UserName,				
			d.TransDate,
			c.Site AS GroupName,
			d.OriginalBetType,
			d.ExtraInfo,
			d.BetdaqId,			
			CURRENT_TIMESTAMP AS [DateTime],
			d.CurrencyName AS CurrencyCode,		
			@isITAdmin AS IsItSupport,
			d.BetFrom,			
			d.WinLost,
			d.Status,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode
	FROM #SpecialDeleteBets d
		 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
			     ON d.recommend = c.custid
	WHERE d.BetType NOT IN (912,913)			     		 
	ORDER BY c.site ASC
		   , CASE WHEN d.BetType = 911 THEN d.TransId ELSE d.RefNo END
		   , d.TransId			
	
	SET NOCOUNT OFF
END
GO