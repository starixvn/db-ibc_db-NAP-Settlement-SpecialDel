/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Update]
	 @TransIds			VARCHAR(MAX)	= ''
	
	,@UserName 			NVARCHAR(50)
    ,@UserPassword		NVARCHAR(50)
    ,@UserID			INT
    ,@IP				VARCHAR(15)		= ''
    ,@Reason			NVARCHAR(500)	= ''
	,@ReasonSC			NVARCHAR(500)	= ''
    
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@InvalidTransIds	VARCHAR(MAX)	= ''	OUTPUT	
	
AS
/*
    Created by: Kent
	Date: 20170403
	Original: 
	Task: Delete Cash-out transaction
	DB: DBTXN/BODB02

	Revisions:
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]	
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181207@Alan: Support Chinese Email [105976]
		- 20190731@Raymond.Le: Return column for display Deposit name in Email [Redmine: #117896]

*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @LogData			NVARCHAR(500)
		  , @avaiableProcess 	BIT = 0
		  , @isITAdmin			BIT = 0
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
		  
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
		WinLost				MONEY,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Status				NVARCHAR(10),
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		RefNo				BIGINT,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		MainStatusId		TINYINT,
		UserName			VARCHAR(30),
		UserName2			VARCHAR(50),
		TransDate			DATETIME,
		OriginalBetType		SMALLINT,
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		mrecommend			INT,
		srecommend			INT,
		matchid				INT,
		awinlost			MONEY,
		CurrencyName		NVARCHAR(50),
		BetFrom				NVARCHAR(1),
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50)
	)
	CREATE INDEX IDX_SpecialDeleteBets_RefNo_OriginalBetType_matchid_custid	
	ON #SpecialDeleteBets(RefNo, OriginalBetType, matchid, custid) INCLUDE(stake)
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange
	
	CREATE TABLE #CashOutSubTicket
	(
		transid			BIGINT,
		refno			BIGINT,
		bettype			SMALLINT,
		custid			INT,
		matchid			INT,
		awinlost		MONEY,
		Stake			MONEY,
		MainStatusId	TINYINT,
		MainBettype		SMALLINT
	) -- store 911,912,913,cash-out bet ticket
	CREATE INDEX IDX_CashOutSubTicket_bettype_custid_matchid ON #CashOutSubTicket(bettype, custid, matchid)
	CREATE INDEX IDX_CashOutSubTicket_transid ON #CashOutSubTicket(transid)
	
	CREATE TABLE #CashOutMainTicket
	(
		transid			BIGINT PRIMARY KEY,	
		bettype			SMALLINT,
		Sum_Stake		MONEY,
		Sum_ActualStake	MONEY,
		IsVoidedAll		BIT	
	) -- store main cash-out
	
	CREATE TABLE #tblCustCashOut912 
	(
		custid INT, 
		matchid INT,
		CONSTRAINT PK_tblCustCashOut912 PRIMARY KEY(matchid, custid)
	) --store Cash-Out's custid	

	CREATE TABLE #tblCustInfo (
		custid INT,
		username NVARCHAR(30),
		username2 NVARCHAR(50),
		currency TINYINT,
		[site] VARCHAR(10)		
	)
	
	SELECT @ErrCode	= 0
		 , @ErrMsg = ''
		 , @InvalidTransIds	= ''	
	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @LogData ='Fail to void Cash-Out transaction bet for betlist: ' + cast(@TransIds AS VARCHAR(8000)) + ' - Username: ' + @username + ' - reason: ' + @reason + + ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) 
		
		EXEC WriteLog_UserLog 
			@UserID = @UserID, 
			@Doing	= @LogData
			
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			 , @ErrCode  = 101
		
		RETURN
	END		
	
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
					WinLost,
					Hdp1,
					Hdp2,
					Status,
					IsLiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					RefNo,
					BetCheck,
					TransDesc,
					MainStatusId,
					UserName,
					TransDate,
					OriginalBetType,
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,
					mrecommend,
					srecommend,
					matchid,
					awinlost,
					betfrom,
					CurrencyName,
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode)
	SELECT 	sub.TransId,
			sub.BetType,
			main.BetTeam,
			sub.Stake,
			main.Odds,
			main.OddsType,
			sub.WinLost - sub.Actual_Stake AS WinLost,
			main.Hdp1,
			main.Hdp2,
			sub.Status,
			main.liveindicator AS IsLiveIndicator,
			main.LiveHomeScore,
			main.LiveAwayScore,
			sub.RefNo,
			main.BetCheck,
			main.TransDesc,
			main.statusID AS MainStatusId,
			sub.UserName,
			sub.TransDate,
			main.bettype AS OriginalBetType,
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			main.recommend,
			main.mrecommend,
			main.srecommend,
			sub.matchid,
			sub.awinlost,
			main.betfrom,
			main.CurrencyName,
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode
	FROM dbo.bettrans sub WITH(NOLOCK)
		 INNER JOIN dbo.bettrans main WITH(NOLOCK)
			     ON	main.transid = sub.refno
					AND main.custid = sub.custid
					AND main.matchid = sub.matchid
		 INNER JOIN dbo.match m WITH(NOLOCK) 
				 ON m.matchid = sub.matchid
	WHERE	sub.transid IN (SELECT t.transid FROM #tblTransIds t)
			AND sub.bettype = 911 -- SOLD tickets
			AND sub.statusID IN (103, 111, 112, 113)
			AND main.statusID IN (0, 103, 111, 112, 113) -- unsettled or refunded, DRAW, WON, LOSE
			AND main.betdaqid = 0
			AND charindex ('p25',main.extrainfo)> 0
	
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid, refno)
	SELECT transid, RefNo
	FROM #SpecialDeleteBets	
	
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
		  @Mode = '911'
		, @Action = 'Void'
		, @IsReleased = 0
	
	DELETE bd
	FROM #SpecialDeleteBets bd
		 INNER JOIN #tblCashOutProcess rp
				 ON bd.transid = rp.transid
					AND rp.IsAvailable = 0
					
	-- return invalid transId	
	SELECT @InvalidTransIds = @InvalidTransIds + CAST(transid AS VARCHAR(20)) + ','		
	FROM #tblCashOutProcess
	WHERE IsAvailable = 0
	
	--> check no data
	IF (NOT EXISTS( SELECT 1 FROM #SpecialDeleteBets))
	BEGIN
		IF @InvalidTransIds = ''		
			SELECT @ErrMsg = 'No ticket found.'
				 , @ErrCode  = 101
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = '911' 
			  , @Action = 'Void'
			  , @IsReleased = 1	
		
		RETURN
	END
	
	--> check and not allow attempt to void tickets of this match while it's being calculated
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid, 1 AS KeyID
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
			  , @Action = 'Void'
			  , @IsReleased = 1	
		
		RETURN
	END	
	
	--> copy 911 into #CashOutSubTicket
	INSERT INTO #CashOutSubTicket(transid
								, refno
								, bettype
								, custid
								, matchid
								, awinlost
								, Stake
								, MainStatusId
								, MainBettype)
	SELECT TransId
		 , RefNo
		 , BetType
		 , custid
		 , matchid
		 , awinlost	
		 , Stake
		 , MainStatusId
		 , OriginalBetType	
	FROM #SpecialDeleteBets
				
	--> get main cash-out			 
	INSERT INTO #CashOutMainTicket(transid, bettype, Sum_Stake, IsVoidedAll)
	SELECT d.RefNo AS transid, d.OriginalBetType AS bettype
		 , SUM(d.stake) AS Sum_Stake
		 , CASE
				WHEN COUNT(*) = (SELECT COUNT(*)
								 FROM bettrans (NOLOCK)
								 WHERE refno = d.RefNo
								   AND matchid = d.matchid
								   AND custid = d.custid
								   AND bettype = 911
								   AND statusID IN (103, 111, 112, 113))
						THEN 1
				ELSE 0
		   END AS IsVoidedAll
	FROM #SpecialDeleteBets d	
	GROUP BY d.RefNo, d.OriginalBetType, d.matchid, d.custid
	
	DROP INDEX IDX_SpecialDeleteBets_RefNo_OriginalBetType_matchid_custid ON #SpecialDeleteBets	
	
	--> get 912,913,cash-out bet ticket
	INSERT INTO #SpecialDeleteBets(
					TransId,
					BetType,
					BetTeam,
					Stake,
					Odds,
					OddsType,
					WinLost,
					Hdp1,
					Hdp2,
					Status,
					IsLiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					RefNo,
					BetCheck,
					TransDesc,
					MainStatusId,
					UserName,
					TransDate,
					OriginalBetType,
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,
					mrecommend,
					srecommend,
					matchid,
					awinlost,
					betfrom,
					CurrencyName,
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode)
	OUTPUT inserted.TransId
		 , inserted.RefNo
		 , inserted.BetType
		 , inserted.custid
		 , inserted.matchid
		 , inserted.awinlost	
		 , inserted.Stake
		 , inserted.MainStatusId
		 , inserted.OriginalBetType		 	 
			INTO #CashOutSubTicket(transid
								 , refno
								 , bettype
								 , custid
								 , matchid
								 , awinlost
								 , Stake
								 , MainStatusId
								 , MainBettype)
	SELECT  b.TransId,
			b.BetType,
			sub911.BetTeam,
			b.Stake,
			sub911.Odds,
			sub911.OddsType,
			b.WinLost - b.Actual_Stake AS WinLost,
			sub911.Hdp1,
			sub911.Hdp2,
			b.Status,
			sub911.IsLiveIndicator,
			sub911.LiveHomeScore,
			sub911.LiveAwayScore,
			b.RefNo,
			sub911.BetCheck,
			sub911.TransDesc,
			sub911.MainStatusId,
			b.UserName,
			b.TransDate,
			sub911.OriginalBetType,
			b.ExtraInfo,
			b.BetdaqId,
			b.custid,
			b.recommend,
			b.mrecommend,
			b.srecommend,
			b.matchid,
			b.awinlost,
			b.betfrom,
			b.CurrencyName,
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode
	FROM #SpecialDeleteBets sub911 WITH(NOLOCK)
		 CROSS APPLY (SELECT b.*
					  FROM dbo.bettrans b WITH(NOLOCK)
					  WHERE	sub911.transid = b.refno
						AND sub911.matchid = b.matchid
						AND b.bettype IN (sub911.OriginalBetType, 912, 913)) AS b
		 INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
	
	--> insert #tblCustCashOut912
	INSERT INTO #tblCustCashOut912(custid, matchid)
	SELECT DISTINCT custid, matchid
	FROM #CashOutSubTicket
	WHERE bettype = 912
	
	--> backup 911,912,913,cash-out bet ticket
	INSERT INTO dbo.zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
				winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
				winlostdate,betfrom,betcheck,checktime,matchid, bettype)
	SELECT  b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
			b.winlostdate, b.betfrom, @session AS betcheck, b.checktime, b.matchid, b.bettype
	FROM	dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #CashOutSubTicket s
			ON	s.transId = b.transid
	
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
			INNER JOIN (SELECT transid from #CashOutMainTicket
						UNION ALL
						SELECT transid from #CashOutSubTicket) s
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
	
	--> update status 911, 912, 913, cash-out bet ticket
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET		b.winlost = b.actual_stake
			,b.awinlost = 0
			,b.mwinlost = 0
			,b.swinlost = 0
			,b.playercomm = 0
			,b.comm = 0
			,b.acomm = 0
			,b.scomm = 0
			,b.status = 'Void'
			,b.statusID = 102
			,b.statuswinlost = 6
			,b.ruben = 1
			,b.creator = @UserId
	FROM	dbo.bettrans b 
		INNER JOIN #CashOutSubTicket s
			ON	b.transid = s.transId
	
	--> re-calculate stake, re-settle for main cash-out
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET stake = TRef.stake
	  , actual_stake = TRef.actual_stake
	  , betdaqid = CASE
						WHEN main.IsVoidedAll = 1 THEN -1
						ELSE b.betdaqid
				   END
	  
	  , winlost = TCal.winlost
	  , awinlost = TCal.awinlost
	  , mWinLost = TCal.mWinLost
	  , swinlost = TCal.swinlost
	  
	  , playercomm = TCal.playercomm
	  , comm = TCal.comm
	  , acomm = TCal.acomm
	  , scomm = TCal.scomm
	FROM	dbo.bettrans b 
		INNER JOIN #CashOutMainTicket main
			ON	b.transid = main.transId		
		OUTER APPLY (
						SELECT  CASE
									WHEN main.IsVoidedAll = 1
										THEN CAST(b.ExtraInfo AS XML).value('(/p25/@s)[1]', 'money')
									ELSE main.Sum_Stake + b.stake 
								END AS stake
							  , CASE
									WHEN main.IsVoidedAll = 1
										THEN CAST(b.ExtraInfo AS XML).value('(/p25/@a)[1]', 'money')
									ELSE CASE
											WHEN b.odds < 0 THEN (main.Sum_Stake + b.stake) * abs(b.odds)
											ELSE (main.Sum_Stake + b.stake)
										 END
								END AS actual_stake
								
							  , CASE b.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
									WHEN '0' THEN 1
									WHEN '1' THEN 0 
									ELSE 1 
								END AS commWinRate
							  , CASE b.comstatus
									WHEN '0' THEN 1
									WHEN '1' THEN 2 
									ELSE 1 
								END AS commLostRate --'s','m'
								
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
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds
																			WHEN b.modds =  0.25 THEN TRef.actual_stake + TRef.stake * TRef.odds * 0.5
																			WHEN b.modds =  0	 THEN TRef.actual_stake	
																			WHEN b.modds = -0.25 THEN TRef.actual_stake * 0.5
																			WHEN b.modds < -0.25 THEN 0
																	  END 
								WHEN b.statusID IN (103) THEN TRef.actual_stake 
								ELSE b.winlost 
							END AS winlost
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25 THEN TRef.stake * TRef.odds * -b.apositiontaking
																			WHEN b.modds =  0.25 THEN TRef.stake * TRef.odds * -b.apositiontaking * 0.5
																			WHEN b.modds =  0	 THEN 0	
																			WHEN b.modds = -0.25 THEN TRef.actual_stake * b.apositiontaking * 0.5
																			WHEN b.modds < -0.25 THEN TRef.actual_stake * b.apositiontaking
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.awinlost 
							END AS awinlost
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.stake * TRef.odds * -b.mpositiontaking
																			WHEN b.modds =  0.25  THEN TRef.stake * TRef.odds * -b.mpositiontaking * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.actual_stake * b.mpositiontaking * 0.5
																			WHEN b.modds < -0.25  THEN TRef.actual_stake * b.mpositiontaking
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.mWinLost 
							END AS mWinLost
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.stake * TRef.odds * -b.spositiontaking
																			WHEN b.modds =  0.25  THEN TRef.stake * TRef.odds * -b.spositiontaking * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.actual_stake * b.spositiontaking * 0.5
																			WHEN b.modds < -0.25  THEN TRef.actual_stake * b.spositiontaking
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.swinlost 
							END AS swinlost
						  
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake
																			WHEN b.modds =  0.25  THEN TRef.commWinRate * b.playerdiscount * TRef.stake * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake * 0.5
																			WHEN b.modds < -0.25  THEN TRef.commLostRate * b.playerdiscount * TRef.stake
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.playercomm 
							END AS playercomm
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.commWinRate * b.discount * TRef.stake * (1-b.apositiontaking)
																			WHEN b.modds =  0.25  THEN TRef.commWinRate * b.discount * TRef.stake * (1-b.apositiontaking) * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.commLostRate * b.discount * TRef.stake * (1-b.apositiontaking) * 0.5
																			WHEN b.modds < -0.25  THEN TRef.commLostRate * b.discount * TRef.stake * (1-b.apositiontaking)
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.comm 
							END AS comm
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.commWinRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking))
																			WHEN b.modds =  0.25  THEN TRef.commWinRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.commLostRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN b.modds < -0.25  THEN TRef.commLostRate * b.adiscount * TRef.stake * (1-(b.mpositiontaking+b.apositiontaking))
																	  END 
								WHEN b.statusID IN (103) THEN 0 
								ELSE b.acomm 
							END AS acomm
						  , CASE 
								WHEN b.statusID IN (111,112,113) THEN CASE
																			WHEN b.modds >  0.25  THEN TRef.commWinRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
																			WHEN b.modds =  0.25  THEN TRef.commWinRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN b.modds =  0	  THEN 0	
																			WHEN b.modds = -0.25  THEN TRef.commLostRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking)) * 0.5
																			WHEN b.modds < -0.25  THEN TRef.commLostRate * b.sdiscount * TRef.stake * (1-(b.spositiontaking+b.mpositiontaking+b.apositiontaking))
																	  END 
								WHEN b.statusID IN (103) THEN 0 
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
			INNER JOIN (SELECT transid from #CashOutMainTicket
						UNION ALL
						SELECT transid from #CashOutSubTicket) s
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
	
	;WITH CTE_Source AS
	(
		SELECT	bts.TradeID AS TradeID
				,bts.TicketID AS [TicketID]					
				,'SB void ticket due to ' + @Reason AS [Remark]
				,tmpsub.awinlost AS [BTBuyBack]
				,0 AS [BTComission]
				,tcust.Balance AS [AfterBalance]
				,'SB' AS [Owner]
				,1 AS [Cancelled]
				,CURRENT_TIMESTAMP AS [ChangeDate]
				,CURRENT_TIMESTAMP AS [CreateDate]
		FROM #CashOutSubTicket tmpsub						 											 
			 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
					 ON bts.TicketID = tmpsub.refno
						AND bts.SoldTicketID = tmpsub.transid	
			 INNER JOIN #CustList tcust
					 ON tmpsub.custid = tcust.custid						 							
		WHERE tmpsub.BetType IN (911)		  
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
	
	--> update totalbets
	DECLARE @Total TABLE (oddsid INT, HomeTotal MONEY, AwayTotal MONEY)
	INSERT INTO @Total
		SELECT oddsid,
			SUM(CASE WHEN betteam='h' THEN (CASE WHEN ABS(odds) > 1 THEN ABS(odds) 
					 ELSE 1 END * b.stake * e.actualrate * (1-b.tpositiontaking)) ELSE 0 END) homeTotal,
			SUM(CASE WHEN betteam='a' THEN (CASE WHEN ABS(odds) > 1 THEN ABS(odds) 
					 ELSE 1 END * b.stake * e.actualrate * (1-b.tpositiontaking)) ELSE 0 END) awayTotal
		FROM bettrans b WITH (nolock)
			INNER JOIN custDB.dbo.exchange e WITH (nolock) ON b.currency = e.exchangeid
		WHERE bettype IN (1,3,7,8) AND ruben = 0 AND oddsid <> 0 AND matchid IN (SELECT matchid FROM #tblMatchProcess)
		GROUP BY oddsid

	UPDATE odds WITH (rowlock, updlock)
	SET hometotal = t.HomeTotal, awaytotal = t.AwayTotal
	FROM @Total t WHERE odds.oddsid = t.oddsid AND odds.matchid IN (SELECT matchid FROM #tblMatchProcess)
	
	--> write log								 
	DECLARE @strMatch VARCHAR(100) = ''
	
	SELECT  @strMatch = @strMatch + CAST(matchid AS VARCHAR(15)) + ','
	FROM	#tblMatchProcess
	
	SELECT @LogData ='Void CashOut transaction for matchid : ' + @strMatch + ' - Username: ' + @username
					+ ' - reason: ' + @reason + ' - ' + @ReasonSC + ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)),SPACE(1)) 
		
	EXEC WriteLog_UserLog 
		@UserID = @UserID, 
		@Doing	= @LogData
		
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
		
	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = '911'
		  , @Action = 'Void' 
		  , @IsReleased = 1
	
	--> output data
	-- CHECK IT GROUP or NOT ?   
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
	
	--- Return all additional information for mailing 
	;WITH CTE_CustIdAll AS (
		SELECT DISTINCT t.custid
		FROM #SpecialDeleteBets b
		CROSS APPLY (
			VALUES (custid)
			,(recommend)
			,(mrecommend)
			,(srecommend)
		) AS t (custid)
	)
	INSERT INTO #tblCustInfo (
		custid
		,username
		,username2
		,site
		,currency
	)
	SELECT ci.custid
		,ci.username
		,ci.username2
		,ci.site
		,ci.currency
	FROM CustDB.dbo.Customer AS ci WITH (NOLOCK)
	INNER JOIN CTE_CustIdAll AS ca ON ci.custid = ca.custid		
	
	SELECT	d.TransId,
			d.BetType AS BetTypeId,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,
			d.WinLost,
			d.Hdp1 AS Handicap1,
			d.Hdp2 AS Handicap2,
			d.Status,
			d.IsLiveIndicator AS IsLive,
			d.LiveHomeScore,
			d.LiveAwayScore,
			d.RefNo,
			d.BetCheck,
			d.TransDesc,
			d.MainStatusId,
			d.UserName,
			ci.username2,
			d.TransDate,
			d.OriginalBetType,
			d.ExtraInfo,
			d.BetdaqId,
			-----------------------------	
			d.custid,
			d.recommend,
			ag.UserName AS AgUserName,
			d.mrecommend,
			ma.UserName AS MagUserName,
			d.srecommend,  
			su.Username AS SagUserName, 
			-----------------------------
			ag.Site,
			CASE 
				WHEN d.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE ag.Site 
			END AS EmailGroup, 
			ag.currency,
			d.CurrencyName, 				
			@isITAdmin AS IsITSupport,
			d.BetFrom,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode 
	FROM #SpecialDeleteBets AS d
	LEFT JOIN #tblCustInfo AS ci ON d.custid = ci.custid
	LEFT JOIN #tblCustInfo AS ag ON d.recommend = ag.custid	
	LEFT JOIN #tblCustInfo AS ma ON d.mrecommend = ma.custid
	LEFT JOIN #tblCustInfo AS su ON d.srecommend = su.custid
	WHERE d.BetType NOT IN (912,913)
	ORDER BY ag.site ASC
		   , CASE WHEN d.BetType = 911 THEN d.TransId ELSE d.RefNo END
		   , d.TransId
		   		
	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblCashOutProcess
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #CashOutSubTicket
	DROP TABLE #CashOutMainTicket
	DROP TABLE #tblCustCashOut912
	DROP TABLE #tblCustInfo
	DROP TABLE #CustList

	SET NOCOUNT OFF
END
GO