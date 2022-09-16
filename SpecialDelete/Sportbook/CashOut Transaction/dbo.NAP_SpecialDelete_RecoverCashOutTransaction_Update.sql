/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverCashOutTransaction_Update]
(
	@TransIds			VARCHAR(MAX),
	@UserId				INT,
	@IP					VARCHAR(50)		= ''
)
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
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]	
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220118@July: HotFix - Recover Cash Out Transaction NOT CALC PlayerComm for tickets double Comm [Redmine: #167687]
		- 20220303@Max: [TVS] Update Virtual Setting when Cancel CO and some enhancements [Redmine: #169237]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220531@July: [TVS] Send data to Jacktime for Cashout Basketball [Redmine: #173389]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's Explanation:
	
*/
BEGIN	
	SET NOCOUNT ON		
	
	DECLARE @LogData			NVARCHAR(500)			
		  , @avaiableProcess 	BIT = 0
		  , @isITAdmin			BIT = 0
		  , @Movebetdate		DATETIME
		  , @FCUpdateTime		DATETIME2
		  , @ErrCode			INT				= 0		
		  , @ErrMsg				NVARCHAR(200)	= ''	
		  , @InvalidTransIds	VARCHAR(MAX)	= ''	
		  , @SiteDBGroupID		SMALLINT
		  , @transInfo XML 
		  , @MatchId			INT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	  		  
		   ,@spName VARCHAR(500) = OBJECT_NAME(@@PROCID)

	CREATE TABLE #tblTransIds (transid BIGINT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tmpKeyId (KeyId INT)
	CREATE TABLE #CashOutExtraInfo (TransId BIGINT, changetime DATETIME, winlost MONEY, actionid TINYINT)
	
	CREATE TABLE #SpecialDeleteBets (		
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				SMALLMONEY,
		OddsType			INT,		
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,		
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,		
		RefNo				BIGINT,		
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		StatusId		    TINYINT,		
		Status			    NVARCHAR(10),
		StatusWinlost	    TINYINT,
		Ruben			    TINYINT,	
		UserName			VARCHAR(30),		
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,		
		BetFrom				NVARCHAR(3),
		matchid				INT,
		awinlost			MONEY,		
		CurrencyName		NVARCHAR(50),		
		actual_stake		MONEY,				
		MOdds			SMALLMONEY,			
		WinLost				MONEY,
		zzzCreator			INT,		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		zzzstatus			NVARCHAR(10),
		zzzwinlost			MONEY,
		KeyId				INT,
		SiteDBGroupID		SMALLINT
	)			
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange

	DECLARE @tmpTransInfo TABLE (transId BIGINT, matchId INT, stake MONEY
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT, ruben TINYINT
		,FcUpdateTime DATETIME2,creator INT, betdaqid BIGINT, virtualrate FLOAT
		,modds SMALLMONEY, transdate DATETIME, comstatus NVARCHAR(40) 
	)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
		
	SELECT @ErrCode	= 0
		 , @ErrMsg = ''
		 , @InvalidTransIds	= ''
	
	--> parse @TransIds
	INSERT INTO #tblTransIds (transid)
	SELECT	t.value
	FROM STRING_SPLIT(@TransIds, ',') t							
	
	INSERT INTO #tmpKeyId (KeyId)
	SELECT MAX(z.keyid)
	FROM zzzbettrans z WITH (NOLOCK)
	WHERE	z.transid IN (SELECT transid FROM #tblTransIds)							
		AND z.comstatus = 'CO'
	GROUP BY z.transid
	
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
					StatusId,					
					Status,
					StatusWinlost,
					Ruben,				
					UserName,						
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,					
					betfrom,
					matchid,
					awinlost,					
					MOdds,										
					CurrencyName,					
					actual_stake,					
					WinLost,
					zzzCreator,					
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode,
					EventDate,
					zzzstatus,
					zzzwinlost,
					KeyId,
					SiteDBGroupID
		)	
	SELECT 	sub.TransId,
			sub.BetType,
			sub.BetTeam,
			sub.Stake,
			sub.Odds,
			sub.OddsType,			
			sub.Hdp1,
			sub.Hdp2,			
			sub.liveindicator AS IsLiveIndicator,
			sub.LiveHomeScore,
			sub.LiveAwayScore,			
			sub.RefNo,						
			sub.BetCheck,
			sub.TransDesc,
			sub.statusID,			
			sub.status,
			sub.statuswinlost ,
			sub.ruben ,		
			sub.UserName,				
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			sub.recommend,			
			sub.betfrom,
			sub.matchid,
			sub.awinlost,			
			sub.modds,						
			sub.CurrencyName,			
			sub.actual_stake,			
			z.winlost - sub.actual_stake as Winlost,
			z.creator AS zzzCreator,			
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.eventdate,
			z.status,
			z.winlost,
			z.keyid,
			sub.SiteDBGroupID
	FROM dbo.zzzbettrans z WITH(NOLOCK)
		 INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			     ON	z.transid = sub.transid		
		 INNER JOIN dbo.match m WITH(NOLOCK)
				 ON m.matchid = z.matchid			    
	WHERE z.keyid IN (SELECT t.KeyId FROM #tmpKeyId t)					
	  AND z.comstatus = 'CO'
	  AND sub.SiteDBGroupID = @SiteDBGroupID
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS ( SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE EventDate <= @Movebetdate )
	BEGIN
		SELECT @ErrCode = 112
			 , @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds 
		
		RETURN	
	END

	--> check no data
	IF (NOT EXISTS( SELECT 1 FROM #SpecialDeleteBets))
	BEGIN
		IF @InvalidTransIds = ''		
			SELECT @ErrMsg = 'No ticket found.'
				 , @ErrCode  = 119	
				 
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds

		RETURN
	END
	
	--> check and not allow attempt to void tickets of this match while it's being calculated
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		 , 1 AS KeyID
	FROM #SpecialDeleteBets		
		
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds

		RETURN
	END	
	
	--> capture before
	INSERT INTO @BeforeUpd (custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		-- main cash-out ticket
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets s
			ON s.transId = b.transid
	) AS temp
	GROUP BY temp.custid							
	
	SET @FCUpdateTime = SYSDATETIME()
	--> update cash-out bet ticket, re-calculate stake, re-settle for main cash-out + update cash-out bet ticket			
	;WITH CTE_main_cashoutticket AS
	(
		SELECT transid
			 , 1 AS TicketType
			 , statusID AS MainStatusId			 
			 , modds
			 , Stake	
			 , zzzwinlost AS winlost
			 , zzzstatus AS status
			 , CASE WHEN zzzstatus = 'WON' THEN '112' 
										WHEN zzzstatus = 'LOSE' THEN '113' 
										WHEN zzzstatus = 'DRAW' THEN '111' 
									END AS statusid
			 , zzzCreator AS creator
		FROM #SpecialDeleteBets
	)
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET status = t.status
	  , statusID = t.statusid
	 -- , statuswinlost = t.StatusWinlost
	  , stake = TRef.stake
	  --, actual_stake = TRef.actual_stake
	  
	  , winlost = t.winlost
	  , awinlost = TCal.awinlost
	  , mWinLost = TCal.mWinLost
	  , swinlost = TCal.swinlost
	  
	  , playercomm = TCal.playercomm
	  , comm = TCal.comm
	  , acomm = TCal.acomm
	  , scomm = TCal.scomm

	  , ruben = 1
	  , creator = t.creator
	  , modds = t.MOdds
	  , betdaqid = -2
	  , virtualrate = actualrate
	  , FcUpdateTime = @FCUpdateTime
	  OUTPUT inserted.TransId, inserted.matchid, inserted.status, inserted.statusID, inserted.stake, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost
		, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm, inserted.ruben, inserted.creator, inserted.modds, inserted.betdaqid, inserted.virtualrate, inserted.FcUpdateTime
		INTO @tmpTransInfo (transId, matchId, Status, StatusID, stake, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm
			, ruben, creator, modds, betdaqid, virtualrate, FcUpdateTime)
	FROM dbo.bettrans b 
		INNER JOIN CTE_main_cashoutticket AS t
			    ON b.transid = t.transId	    			
		OUTER APPLY (
						SELECT b.stake
							 , CASE t.TicketType
									WHEN 1 THEN CASE
													WHEN b.odds < 0 THEN (b.stake) * abs(b.odds)
													ELSE (b.stake)
												END
									WHEN 2 THEN b.actual_stake 
							   END AS actual_stake
							 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 0 ELSE 1 END AS CommWinRate
							 , CASE b.comstatus WHEN '0' THEN 1	WHEN '1' THEN 2 ELSE 1 END AS CommLostRate
					) AS TRef		
		OUTER APPLY (SELECT t.winlost AS winlost
							 , CASE
									
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN ABS(t.winlost - b.actual_stake) * -b.apositiontaking
									WHEN t.statusID = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.apositiontaking
								END AS awinlost
							, CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN ABS(t.winlost - b.actual_stake) * -b.mpositiontaking
									WHEN t.statusID = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.mpositiontaking
								END AS mWinLost
							, CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN ABS(t.winlost - b.actual_stake) * -b.spositiontaking
									WHEN t.statusID = 111 THEN 0
									ELSE ABS(t.winlost - b.actual_stake) * b.spositiontaking
								END AS swinlost
							  , CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									WHEN t.statusID = 111 THEN TRef.CommWinRate * b.stake * b.playerdiscount
									ELSE TRef.CommLostRate * b.stake * b.playerdiscount
								END AS playercomm
							, CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									WHEN t.statusID = 111 THEN TRef.CommWinRate * b.stake * b.discount * (1-apositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.discount * (1-apositiontaking)
								END AS comm
							,CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									WHEN t.statusID = 111 THEN TRef.CommWinRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.adiscount * (1-apositiontaking - mpositiontaking)
								END AS acomm
							,CASE
									WHEN t.statusID = 103 THEN 0
									WHEN t.statusID = 112 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									WHEN t.statusID = 111 THEN TRef.CommWinRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
									ELSE TRef.CommLostRate * b.stake * b.sdiscount * (1-apositiontaking - mpositiontaking - spositiontaking)
								END AS scomm
						) AS TCal	

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
			SET @transInfo = (
				SELECT	b.transId AS '@t'
						, b.status AS '@s'
						, b.statusID AS '@sid'	
						, b.stake AS '@stake'
						, b.winlost AS '@w'
						, b.awinlost AS '@aw'
						, b.mwinlost AS '@mw'
						, b.swinlost AS '@sw'
						, b.playercomm AS '@pc'
						, b.comm AS '@c'
						, b.acomm AS '@ac'
						, b.scomm AS '@sc'					
						, b.ruben AS '@r'
						, b.creator AS '@cr'
						, b.modds AS '@m'
						, b.betdaqid AS '@bdaq'
						, b.virtualrate AS '@v'
						, b.FcUpdateTime AS '@rut'
				FROM	@tmpTransInfo b WHERE b.matchId = @MatchId
				FOR XML PATH('r'),ROOT('root'), TYPE)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
			SELECT 'TVS', 'Recover_CO', 'bettrans', 'U', @matchid, @transInfo
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
	END
	
	--> capture after
	INSERT INTO @AfterUpd(custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		-- main cash-out ticket
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets s
			ON s.transId = b.transid
	) AS temp
	GROUP BY temp.custid
	
	--> compare BALANCE
	EXEC [dbo].[NAP_Admin_BalancePendingIns]
		@BeforeUpd	 = @beforeUpd
		, @AfterUpd	 = @afterUpd
	
	--> delete zzzbettrans
	DELETE z OUTPUT deleted.transid, deleted.matchid, deleted.transdate, deleted.comstatus INTO @tmpTransInfo (transId, matchId, transdate, comstatus)	
	FROM dbo.zzzbettrans z WITH(ROWLOCK, UPDLOCK)
		 INNER JOIN #SpecialDeleteBets t
				 ON z.transid = t.transid
					AND z.keyid = t.KeyId
	
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

			SET @TransInfo = (
			SELECT	matchid AS '@mid'
					, transId AS '@t'
					, transdate AS '@td'
					, comstatus AS '@cst'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR XML PATH('r'),ROOT('root'), TYPE)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
			SELECT 'TVS', 'Recover_CO', 'zzzbettrans', 'D', @matchid, @TransInfo 
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
	END

	
	--Update CashoutSelling
	INSERT INTO #CashOutExtraInfo (TransId, changetime, winlost, actionid)
	SELECT s.TransId, @FCUpdateTime, b.winlost, 8
	FROM #SpecialDeleteBets s
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.TransId

	UPDATE s
	SET s.CashOutStatus = 4
		, s.CashoutExtraInfo = REPLACE(s.CashoutExtraInfo, '</root>', c.CashOutExtraInfo) + '</root>'
	    , s.ChangeDate = CONVERT(DATETIME,@FCUpdateTime)
	FROM dbo.CashOutSelling s WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (
				SELECT N'<r ct=''' + CONVERT(VARCHAR(30),t.changetime,21) + ''' s=''' + CONVERT(varchar(20),t.actionid) + ''' w='''+ convert(varchar(20),t.winlost) +'''/>' AS CashOutExtraInfo
				FROM #CashOutExtraInfo t
				WHERE t.TransId = s.TransID
			)c
	
	--> write log								 
	SELECT @LogData = 'Recover CashOut transactions have transid: ' + @TransIds + ' IP: ' + @Ip
	EXEC WriteLog_UserLog 
		 @UserId = @UserId,
		 @Doing = @LogData 
	
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		, @IsReleased		= 1	
		
	--> output data
	-- CHECK IT GROUP or NOT ?  
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0) 

	--1. Output table validate
	SELECT @ErrCode AS ErrorCode
		, @ErrMsg AS ErrorMsg
		, @InvalidTransIds AS InvalidTransIds
		
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
			d.StatusId,
			d.UserName,				
			c.Site AS GroupName,
			d.ExtraInfo,
			d.BetdaqId,			
			CURRENT_TIMESTAMP AS [DateTime],
			d.CurrencyName AS CurrencyCode,		
			@isITAdmin AS IsItSupport,
			d.BetFrom,			
			d.WinLost,
			d.zzzstatus AS status,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode,
			d.actual_stake AS ActualStake,
			d.custid,
			d.SiteDBGroupID
	FROM #SpecialDeleteBets d
		 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
			     ON d.recommend = c.custid
	WHERE d.BetType NOT IN (912,913)			     		 
	ORDER BY c.site ASC
		   , CASE WHEN d.BetType = 911 THEN d.TransId ELSE d.RefNo END
		   , d.TransId			
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblTransIds

	SET NOCOUNT OFF
END
GO