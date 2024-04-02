/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarBySubIds_Upd] 		
	@SubTransIds			VARCHAR(MAX),
	@UserName 				NVARCHAR(50),
    @Password				NVARCHAR(50),
    @UserID					INT,
    @IP						VARCHAR(15)		= '',
    @Reason					NVARCHAR(500)	= '',
	@ReasonSC				NVARCHAR(500)	= ''
AS
/*  
	Created by: 20170831@Kent  
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  				
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]			
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181207@Alan: Support Chinese Email [105976]
		- 20200929@Zane: Show Operator ID into void email notification - Fix bug cannot show bettype and deposit name [#141126]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's Explanation:				
		- @SubTransIds : TransIds of sub parlay tickets				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @avaiableProcess			BIT 
		  , @isITAdmin					BIT	  
		  , @CustIds					VARCHAR(MAX)
		  , @Movebetdate				DATETIME
		  , @spName						VARCHAR(500) = OBJECT_NAME(@@PROCID)

	DECLARE @_xml						XML		
		  , @_sXML						VARCHAR(MAX)
		  , @IgnoreList					VARCHAR(200)		  		  		  
		  , @strRefnos					VARCHAR(MAX)		  		  
		  , @matchid					INT
		  , @matchdate					DATETIME
		  , @countmatch					INT
		  , @i							INT
		  , @SubTickets_Count			INT
		  , @NegativeBalanceUsers	VARCHAR(MAX)	= ''
		  , @ErrMsg					NVARCHAR(200)	= ''
		  , @ErrCode				INT				= 0	
		  , @SiteDBGroupID		SMALLINT
		  , @Sporttype					SMALLINT
		  , @IsExistsVS2				BIT = 0
		  , @IsExistsVS4				BIT = 0

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)
		  
	SET @IgnoreList = 'DB04,DB042,DB043,DB044'		  	  		  			  
	
	CREATE TABLE #tmpBetDelete
	(
		Stake			MONEY,
		AwayId			INT,
		BetCheck		NVARCHAR(50),
		BetId			BIGINT,
		BetTeam			NVARCHAR(10),
		BetType			SMALLINT,
		CurrencyName	NVARCHAR(50),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		HomeId			INT,
		IsLiveIndicator BIT,
		LiveAwayScore	SMALLINT,
		LiveHomeScore	SMALLINT,
		Odds			MONEY,
		OddsType		INT,
		RefNo			BIGINT,
		SportType		SMALLINT,
		statusID		TINYINT,
		Status			NVARCHAR(10),
		statuswinlost	TINYINT,
		TransDate		DATETIME,
		TransDesc		NVARCHAR(1000),
		TransId			BIGINT,
		UserName		VARCHAR(30),
		WinLost			MONEY,
		IsDeposit		BIT,
		recommend		INT,
		mrecommend		INT,
		srecommend		INT,
		CustId			INT,
		IsNeutral		BIT,		
		showtime		NVARCHAR(20),
		LeagueId		INT,
		modds			SMALLMONEY,	
		SubStatus		NVARCHAR(10),
		SubTransId		BIGINT,
		SubBetCheck		NVARCHAR(50),
		SubBetTeam		NVARCHAR(10),
		SubBetType		SMALLINT,
		SubHdp1			SMALLMONEY,
		SubHdp2			SMALLMONEY,
		SubOdds			MONEY,	
		SubTransdesc	NVARCHAR(2000),	
		SubMatchid		INT,
		SubMatchdate	DATETIME,		
		BetFrom			NVARCHAR(4)
	)	
	CREATE INDEX IX_SubMatchid_SubMatchdate_RefNo ON #tmpBetDelete(SubMatchid, SubMatchdate, RefNo) INCLUDE(TransId)
	
	CREATE TABLE #tblSubTransIds (SubTransId BIGINT PRIMARY KEY)	
	
	CREATE TABLE #tmpBettransm
	(
		Status NVARCHAR(10),
		TransId BIGINT,
		BetCheck NVARCHAR(50),
		BetTeam NVARCHAR(10),
		BetType SMALLINT,
		Hdp1 SMALLMONEY,
		Hdp2 SMALLMONEY,
		Odds SMALLMONEY,
		transdesc NVARCHAR(1000),
		refno BIGINT,
		custid INT,
		matchid INT
	)	
	
	CREATE TABLE #tmpMatchInfos
	(
		RowNum INT IDENTITY(1, 1), 
		matchid INT, 
		matchdate DATETIME,
		RefNos VARCHAR(MAX),
		sporttype SMALLINT
	)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	DECLARE @beforeUpd TVP_BalanceChange
		  , @afterUpd  TVP_BalanceChange	
	
	SELECT @NegativeBalanceUsers = ''
		 , @ErrCode = 0
		 , @ErrMsg = ''
		 , @countmatch = 0
		 , @i = 0
		 , @SubTickets_Count = 0
		 , @avaiableProcess	= 1	
		 , @isITAdmin = 0		  
		 , @CustIds	= ''	 			 
	
	BEGIN TRY
		--> Check Password
		IF NOT EXISTS (SELECT 1  FROM custDB.dbo.customer WITH (NOLOCK) WHERE userpwd = @Password  AND custid = @UserId AND roleid>=5)  
		BEGIN  
			SELECT @ErrCode = 113
				 , @ErrMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!'

			SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers

			RETURN
		END	
			
		--> parse @SubTransIds
		INSERT INTO #tblSubTransIds(SubTransId)
		SELECT  DISTINCT value
		FROM	STRING_SPLIT(@SubTransIds, ',')	
			
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'	

			SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers

			RETURN
		END			
		
		--> Search Tickets
		-- get sub tickets
		INSERT INTO #tmpBettransm(
				Status
			   ,TransId
			   ,BetCheck
			   ,BetTeam
			   ,BetType
			   ,Hdp1
			   ,Hdp2
			   ,Odds
			   ,transdesc
			   ,refno
			   ,custid
			   ,matchid)
		SELECT bm.Status
			  ,bm.TransId
			  ,bm.BetCheck
			  ,bm.BetTeam
			  ,bm.BetType
			  ,bm.Hdp1
			  ,bm.Hdp2
			  ,bm.Odds
			  ,bm.transdesc
			  ,bm.refno
			  ,bm.custid
			  ,bm.matchid				
		FROM #tblSubTransIds t
			 INNER JOIN dbo.bettransm bm WITH (NOLOCK)
					 ON t.SubTransId = bm.transid
		WHERE bm.statusID NOT IN (101, 102) -- reject, void 
			AND bm.SiteDBGroupID = @SiteDBGroupID
		
		SET @SubTickets_Count = @@ROWCOUNT
		
		INSERT INTO #tmpBetDelete
				(Stake
				,AwayId
				,BetCheck
				,BetId
				,BetTeam
				,BetType
				,CurrencyName
				,Hdp1
				,Hdp2
				,HomeId
				,IsLiveIndicator
				,LiveAwayScore
				,LiveHomeScore
				,Odds
				,OddsType
				,RefNo
				,SportType
				,statusID
				,Status
				,statuswinlost
				,TransDate
				,TransDesc
				,TransId
				,UserName
				,WinLost
				,IsDeposit
				,recommend
				,mrecommend
				,srecommend
				,CustId
				,IsNeutral				   
				,showtime
				,LeagueId
				,modds  
				,SubStatus
				,SubTransId
				,SubBetCheck
				,SubBetTeam
				,SubBetType
				,SubHdp1
				,SubHdp2
				,SubOdds
				,SubTransdesc
				,SubMatchid
				,SubMatchdate  
				,BetFrom)			   
		SELECT  b.Stake
				,m.AwayId
				,b.BetCheck
				,b.BetId
				,b.BetTeam
				,b.BetType
				,b.CurrencyName
				,b.Hdp1
				,b.Hdp2
				,m.HomeId
				,b.LiveIndicator AS IsLiveIndicator
				,b.LiveAwayScore
				,b.LiveHomeScore
				,b.Odds
				,NULL AS OddsType
				,b.RefNo
				,m.SportType
				,b.statusID
				,b.Status
				,b.statuswinlost
				,b.TransDate
				,b.TransDesc
				,b.TransId
				,b.UserName
				,(b.winlost - b.actual_stake) AS WinLost
				,CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,b.CustId
				,ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral				   
				,ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime
				,m.leagueid
				,b.modds  
				,bm.Status AS SubStatus
				,bm.TransId AS SubTransId
				,bm.BetCheck AS SubBetCheck
				,bm.BetTeam AS SubBetTeam
				,bm.BetType AS SubBetType
				,bm.Hdp1 AS SubHdp1
				,bm.Hdp2 AS SubHdp2
				,bm.Odds AS SubOdds
				,bm.transdesc AS SubTransdesc
				,bm.matchid AS SubMatchid
				,m.eventdate AS SubMatchdate				
				,b.betfrom
		FROM (SELECT TOP (@SubTickets_Count) * 
			  FROM #tmpBettransm WITH (NOLOCK)) bm 
			 INNER JOIN bettrans b WITH (NOLOCK) 
			  		 ON b.refno = bm.refno 
					    AND b.custid = bm.custid
			 INNER JOIN match m WITH(NOLOCK)
					 ON bm.matchid = m.matchid			 
		WHERE b.matchid IN (2799, 10449)
		  AND b.bettype IN (2799, 10449)	
		  AND b.statusID NOT IN (101, 102) -- reject, void		
		OPTION(OPTIMIZE FOR (@SubTickets_Count = 1))			
			  
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'	

			SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers
			
			RETURN		  
		END
		
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

		IF EXISTS (SELECT TOP 1 1 FROM #tmpBetDelete WHERE SubMatchdate <= @Movebetdate)
		BEGIN
			SELECT @ErrCode = 99
				 , @ErrMsg = 'Match is under Movebet process, could not void ticket.'

			SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers

			RETURN	
		END

		--> Check Concurrency
		SELECT @IsExistsVS2 = CASE WHEN Sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END
			  ,@IsExistsVS4 = CASE WHEN Sporttype = 188 THEN 1 ELSE 0 END
		FROM #tmpBetDelete

		IF @IsExistsVS4 = 1
		BEGIN
			INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
			SELECT DISTINCT bm.matchid, bm.refno
			FROM #tmpBettransm bm
				INNER JOIN #tmpBetDelete b ON b.RefNo = bm.refno AND b.SportType = 188
		END

		EXEC [dbo].[NAP_Admin_CheckingProcess]
				@IsExistParlayVSBetradar = @IsExistsVS2		
				, @IsLockingByRefnoVS		= @IsExistsVS4
				, @spName		= @spName
				, @IsReleased	= 0
				, @AvaiableProcess = @AvaiableProcess OUTPUT
				, @ErrCode = @ErrCode OUTPUT
				, @ErrMsg	= @ErrMsg OUTPUT

		IF @ErrCode <> 0 OR @avaiableProcess = 0
		BEGIN
			SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers

			RETURN
		END
			
		--> get Match Infos
		INSERT INTO #tmpMatchInfos(matchid, matchdate, RefNos, sporttype)
		SELECT bd.SubMatchid, bd.SubMatchdate
			 , CAST((
					SELECT DISTINCT refno AS '@rn'
					FROM #tmpBetDelete
					WHERE SubMatchid = bd.SubMatchid
					  AND SubMatchdate = bd.SubMatchdate				
					FOR XML PATH('r'), ROOT('root'), TYPE
				) AS VARCHAR(MAX)) AS RefNos
			, SportType
		FROM #tmpBetDelete	bd
		GROUP BY bd.SubMatchid, bd.SubMatchdate, bd.SportType
		
		SET @countmatch = @@ROWCOUNT		

		--> Capture balance before update	
		INSERT INTO @beforeUpd(custid, balance, balanceType)
		SELECT	b.custid
				, SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
				, 4 AS balanceType
		FROM bettrans b WITH (ROWLOCK)								 	  
		WHERE transid IN (SELECT transid FROM #tmpBetDelete)
		GROUP BY b.CustID					
			
		--> Insert zzzbettransm				
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
					winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
					winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #tmpBetDelete AS r 
				ON	r.SubTransId = b.transid
						
				
		--> Call Re-Calc For Main Tickets				
		SET @i = 1
		WHILE @i <= @countmatch
		BEGIN
			SELECT @matchid = matchid
				 , @matchdate = matchdate
				 , @strRefnos = RefNos
				 , @Sporttype = sporttype
			FROM #tmpMatchInfos
			WHERE RowNum = @i	
			
			--> Update bettransm                             
			SET @_xml = (
				SELECT 
					 SubTransId '@t' -- transid
					,SubMatchdate '@d' -- winlostdate
					,0 '@w' -- statuswinlost
					,102 '@s' -- statusID
					,@UserID '@cr' -- creator						
				FROM #tmpBetDelete b WHERE b.SubMatchid = @matchid		 
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				  @IgnoreList 	= @IgnoreList
				, @updatetype 	= 5
				, @_sXML 		= @_sXML
				, @MatchId      = @MatchId
				
			IF @sporttype BETWEEN 190 AND 199 --VS2
			BEGIN
				EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main]
					  @MatchId			= @MatchId
					, @strRefnos 		= @strRefnos
					, @matchdate		= @matchdate
					, @IsBalance		= 0
					, @CWLBettype		= 1201
					, @ErrCode			= @ErrCode OUTPUT
					, @ErrMsg			= @ErrMsg OUTPUT
			END
			IF @sporttype = 188 --VS4
			BEGIN
				EXEC [dbo].[TicketVoiding_ReCalculate_ParlayVS_Update]
					  @MatchId			= @MatchId
					, @strRefnos 		= @strRefnos
					, @matchdate		= @matchdate
					, @IsBalance		= 0
					, @CWLBettype		= 1201
					, @ErrCode			= @ErrCode OUTPUT
					, @ErrMsg			= @ErrMsg OUTPUT
			END
			SET @i = @i + 1				
		END																										
					
		--> Capture balance after update	
		INSERT INTO @afterUpd(custid, balance, balanceType)
		SELECT	b.custid
				, SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
				, 4 AS balanceType
		FROM bettrans b WITH (ROWLOCK)			 					 	  
		WHERE transid IN (SELECT transid FROM #tmpBetDelete)				
		GROUP BY b.CustID
		
		--> INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			  @BeforeUpd = @beforeUpd
			, @AfterUpd	 = @afterUpd
		
		--> Release Concurrency process	
		EXEC [dbo].[NAP_Admin_CheckingProcess]
				@IsExistParlayVSBetradar = @IsExistsVS2		
				, @IsLockingByRefnoVS		= @IsExistsVS4		
				, @IsReleased	= 1 
		
		--> Get list of customer name with negative balance
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
			
		--> Return data to web
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--1.Return table validate
		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers
		
		SELECT  r.Stake,
				r.AwayId,
				r.BetCheck,
				r.BetId,
				r.BetTeam,
				r.BetType AS BetTypeId,				
				r.CurrencyName,
				r.Hdp1 AS Handicap1,
				r.Hdp2 AS Handicap2,
				r.HomeId,
				r.IsLiveIndicator AS IsLive,
				r.LiveAwayScore,
				r.LiveHomeScore,
				r.Odds,
				r.OddsType,
				r.RefNo,
				r.SportType AS SportTypeId,
				r.Status,
				r.TransDate,
				r.TransDesc,
				r.TransId,
				c.username,
				c.username2,
				r.WinLost,				
				r.IsNeutral,
				r.showtime,
				r.LeagueId,
				r.modds AS MasterOdds,
				r.SubMatchid AS matchid,
				r.SubStatus,
				r.SubTransId,
				r.SubBetCheck,
				r.SubBetTeam,
				r.SubBetType,
				r.SubHdp1,
				r.SubHdp2,
				r.SubOdds,
				r.SubTransdesc,	
				1 AS IsMixParlay,			
				r.CustId,
				r.recommend,
				ag.UserName AS AgUserName,
				r.mrecommend,
				ma.UserName AS MagUserName,
				r.srecommend,
				su.Username AS SagUserName,
				ag.Currency,
				ag.Site,
				su.Site AS EmailGroup,	
				@isITAdmin AS IsItSupport,
				r.BetFrom 
		FROM #tmpBetDelete r
				LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)
						ON r.custid = c.custid
				LEFT JOIN CustDB.dbo.Customer ag WITH(NOLOCK)
						ON r.recommend = ag.custid
				LEFT JOIN CustDB.dbo.Customer ma WITH(NOLOCK)
						ON r.mrecommend = ma.custid
				LEFT JOIN CustDB.dbo.Customer su WITH(NOLOCK)
						ON r.srecommend = su.custid 
	END TRY
	BEGIN CATCH	
		SELECT @ErrCode = 100, @ErrMsg = ERROR_MESSAGE()
		
		IF @avaiableProcess = 1
			--> Release Concurrency process	
			EXEC [dbo].[NAP_Admin_CheckingProcess]
					@IsExistParlayVSBetradar = @IsExistsVS2		
				, @IsLockingByRefnoVS		= @IsExistsVS4
				  , @IsReleased	= 1	

		SELECT @ErrCode AS ErrorCode
				, @ErrMsg AS ErrorMsg
				, @NegativeBalanceUsers AS NegativeBalanceUsers
	END CATCH			
		
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblSubTransIds
	DROP TABLE #tmpBetDelete
	DROP TABLE #tmpBettransm
	DROP TABLE #tmpMatchInfos
	SET NOCOUNT OFF
END
GO