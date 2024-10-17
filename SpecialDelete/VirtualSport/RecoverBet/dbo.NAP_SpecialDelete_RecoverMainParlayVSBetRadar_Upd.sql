/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverMainParlayVSBetRadar_Upd] 
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
		- 20180305@Helen: Betradar VS2 - [Redmine:90153]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]

	Param's Explanation:		
		- @TransIds : Main transids.
*/
BEGIN
	SET NOCOUNT ON		
	
	DECLARE @IsExistParlayVSBetradar	BIT = 0		  
		  , @avaiableProcess			BIT	= 0
		  , @isITAdmin					BIT	= 0
		  , @before_yesterday			DATETIME
		  , @CustIds					VARCHAR(MAX) = ''			  		  	    
		  , @Movebetdate				DATETIME
		  , @spName						VARCHAR(500) = OBJECT_NAME(@@PROCID)

	DECLARE @IgnoreList					VARCHAR(200)  = ''
		  , @_xml						XML		
		  , @_sXML						VARCHAR(MAX)  = ''	
		  , @strRefnos					VARCHAR(MAX) = ''
		  , @i							INT
		  , @cnt_match					INT		  
		  , @matchId					INT
		  , @matchdate					DATETIME
		  , @ReCalculatedMainTransIds   VARCHAR(MAX)	= ''
		  , @NegativeBalanceUsers		VARCHAR(MAX)	= '' 
		  , @ErrMsg						NVARCHAR(200)	= ''
		  , @ErrCode					INT				= 0	
		  , @SiteDBGroupID				SMALLINT
		  , @transInfo					VARBINARY(MAX) 
		  , @IsExistsVS2				BIT = 0
		  , @IsExistsVS					BIT = 0
		  , @bettype					SMALLINT
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
		eventstatus			NVARCHAR(100),
		eventdate			DATETIME,
		betstatus			NVARCHAR(100),				
		showtime			NVARCHAR(20),
		creator				INT,
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
		matchid				INT				
	)
	
	CREATE TABLE #MatchInfo
	(
		RowNum		INT IDENTITY(1, 1),
		matchid		INT,
		matchdate 	SMALLDATETIME
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	DECLARE @beforeUpd		 TVP_BalanceChange
		  , @afterUpd		 TVP_BalanceChange		  		
	
	SELECT @before_yesterday = CONVERT(varchar(10), DATEADD(day, -2, GETDATE()), 120)		 
		 , @ReCalculatedMainTransIds = '' 
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
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

			RETURN
		END 
		
		--> Search tickets		
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
				creator,
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
				betfrom,
				matchid,
				eventdate
			)
		SELECT  z.Stake,
				NULL AS AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				NULL AS HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				NULL AS SportType,
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
				z.creator,
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
				b.winlostdate AS eventdate -- parlay eventdate: get winlostdate
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
				INNER JOIN dbo.bettrans b WITH (NOLOCK)
						ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype			 
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)		
			AND z.winlostdate >= @before_yesterday
			AND z.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1))
			AND z.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1))	
			AND z.SiteDBGroupID = @SiteDBGroupID
				
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

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
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

			RETURN	
		END
			
		--> Check Concurrency
		SELECT @IsExistsVS2 = CASE WHEN z.bettype = 2799 THEN 1 ELSE 0 END
			  ,@IsExistsVS = CASE WHEN z.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1) AND Bettype <> 2799) THEN 1 ELSE 0 END
		FROM #RecoverBet z

		IF @IsExistsVS = 1
		BEGIN
			INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
			SELECT bettype, refno
			FROM #RecoverBet
			WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1) AND Bettype <> 2799)
		END
				
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsExistParlayVSBetradar	= @IsExistsVS2	
			, @IsLockingByRefnoVS		= @IsExistsVS
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF @ErrCode <> 0 OR @avaiableProcess = 0
		BEGIN
			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

			RETURN
		END
		
		--> Capture balance before update	
		INSERT INTO @beforeUpd(custid, balance, balanceType)
		SELECT	b.custid
				, SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
				, 4 AS balanceType
		FROM bettrans b WITH (NOLOCK) 
				INNER JOIN #RecoverBet t 
						ON	b.transid = t.TransId					 	  
		GROUP BY b.CustID						
		
		IF @IsExistsVS2 = 1
		BEGIN
			SET @bettype = 2799

			--> Update Bettrans	to running
			SET @_xml = (
				SELECT t.transid '@q' -- transid			 
						, t.creator '@cr' -- creator			 
				FROM #RecoverBet t					 
				WHERE t.BetType = @bettype
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				  @IgnoreList 	= @IgnoreList
				, @updatetype 	= 6
				, @_sXML 		= @_sXML
				, @matchId		= 2799
			
			--> get match list
			INSERT INTO #MatchInfo(matchid, matchdate)
			SELECT bm.matchid
					, m.eventdate AS matchdate		
			FROM bettransm bm (NOLOCK)
					INNER JOIN #RecoverBet t
							ON bm.refno = t.refno
					INNER JOIN match m (NOLOCK)
							ON bm.matchid = m.matchid
			WHERE t.BetType = @bettype
			GROUP BY bm.matchid, m.eventdate
			
			SET @cnt_match = @@ROWCOUNT
		
			--> re-cal main tickets
			SELECT @strRefnos = CAST((
					SELECT refno AS '@rn'
					FROM #RecoverBet				
					WHERE bettype = @bettype
					FOR XML PATH('r'), ROOT('root'), TYPE
			) AS VARCHAR(MAX))						 
						 
			SET @i = 1
			WHILE @i <= @cnt_match
			BEGIN
				SELECT @matchId = matchid, @matchdate = matchdate
				FROM #MatchInfo
				WHERE RowNum = @i
			
				EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main]
					 @MatchId			= @matchId
					,@strRefnos 		= @strRefnos
					,@matchdate			= @matchdate
					,@IsBalance			= 0
					,@CWLBettype		= 1201
					,@ErrCode			= @ErrCode OUTPUT
					,@ErrMsg			= @ErrMsg OUTPUT
			
				SET @i = @i + 1
			END	
			DELETE FROM #MatchInfo
		END
		IF @IsExistsVS = 1
		BEGIN
			--VS4
			--> Update Bettrans	to running
			SET @_xml = (
				SELECT t.transid '@q' -- transid			 
						, t.creator '@cr' -- creator			 
				FROM #RecoverBet t					 
				WHERE t.BetType = 10449
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				  @IgnoreList 	= @IgnoreList
				, @updatetype 	= 6
				, @_sXML 		= @_sXML
				, @matchId		= 10449

			--VS5
			--> Update Bettrans	to running
			SET @_xml = (
				SELECT t.transid '@q' -- transid			 
						, t.creator '@cr' -- creator			 
				FROM #RecoverBet t					 
				WHERE t.BetType = 11099
				FOR XML PATH('r'), ROOT('root'), TYPE
			) 
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
			
			EXEC dbo.Bet_ExecRep_05 
				  @IgnoreList 	= @IgnoreList
				, @updatetype 	= 6
				, @_sXML 		= @_sXML
				, @matchId		= 11099
			
			--> get match list
			INSERT INTO #MatchInfo(matchid, matchdate)
			SELECT bm.matchid
					, m.eventdate AS matchdate		
			FROM bettransm bm (NOLOCK)
					INNER JOIN #RecoverBet t
							ON bm.refno = t.refno
					CROSS APPLY (
						SELECT m.homeid, m.awayid, m.sporttype, m.leagueid, m.IsNeutral, m.kickofftime, m.matchcode, m.eventdate
						FROM match m WITH (NOLOCK)
						WHERE m.matchid = bm.matchid
						UNION 
						SELECT m.homeid, m.awayid, m.sporttype, m.League3rdId, 0, '', m.matchcode, m.EventDate
						FROM Match3rd m WITH (NOLOCK)
						WHERE m.Match3rdId = bm.matchid
					 )m	
			WHERE t.BetType IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1) AND Bettype <> 2799)
			GROUP BY bm.matchid, m.eventdate
			
			SET @cnt_match = @@ROWCOUNT
		
			--> re-cal main tickets
			SELECT @strRefnos = CAST((
					SELECT refno AS '@rn'
					FROM #RecoverBet				
					WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1) AND Bettype <> 2799)
					FOR XML PATH('r'), ROOT('root'), TYPE
			) AS VARCHAR(MAX))						 
						 
			SET @i = 1
			WHILE @i <= @cnt_match
			BEGIN
				SELECT @matchId = matchid, @matchdate = matchdate
				FROM #MatchInfo
				WHERE RowNum = @i
			
				EXEC [dbo].[TicketVoiding_ReCalculate_ParlayVS_Update]
					 @MatchId			= @matchId
					,@strRefnos 		= @strRefnos
					,@matchdate			= @matchdate
					,@IsBalance			= 0
					,@CWLBettype		= 1201
					,@ErrCode			= @ErrCode OUTPUT
					,@ErrMsg			= @ErrMsg OUTPUT
			
				SET @i = @i + 1
			END																			
		END

		--> Capture balance after update	
		INSERT INTO @afterUpd(custid, balance, balanceType)
		SELECT	b.custid
				, SUM (b.winlost - b.actual_stake + b.playercomm) AS balance 
				, 4 AS balanceType
		FROM bettrans b WITH (NOLOCK) 
				INNER JOIN #RecoverBet t 
						ON	b.transid = t.TransId					 	  
		GROUP BY b.CustID
		
		--> INSERT data into pending balance table   
		EXEC [dbo].[NAP_Admin_BalancePendingIns]
			  @BeforeUpd = @beforeUpd
			, @AfterUpd	 = @afterUpd

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
				SELECT 'TVS', 'RecoverVS', 'zzzbettrans', 'D', @matchid, @TransInfo, 'p', 1
			END

			DELETE FROM @tmpTransInfo
			DELETE FROM @tmpMatchidInfo

		END
			
		--> Release Concurrency process
		EXEC dbo.NAP_Admin_CheckingProcess
				 @IsExistParlayVSBetradar	= @IsExistsVS2	
			, @IsLockingByRefnoVS		= @IsExistsVS		
			, @IsReleased				= 1	
			
		--> Build list of customer name with negative balance
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
			
		--> build data for @ReCalculatedMainTransIds
		SET @ReCalculatedMainTransIds = ''
			
		SELECT @ReCalculatedMainTransIds = @ReCalculatedMainTransIds
											+ CASE WHEN @ReCalculatedMainTransIds <> '' THEN ',' ELSE '' END
											+ CAST(t.Transid AS VARCHAR(100))
		FROM #RecoverBet t
			 INNER JOIN bettrans b (NOLOCK)
					 ON t.TransId = b.transid
		WHERE b.statusID IN (111, 112, 113, 103)					 
			
		--> Return data to web
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		
		--1. Return table validate
		SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds
					
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
				r.modds AS MasterOdds,
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
				   @IsExistParlayVSBetradar	= @IsExistsVS2	
				, @IsLockingByRefnoVS		= @IsExistsVS		
				, @IsReleased				= 1	

		SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds
	END CATCH		
	
	SET NOCOUNT OFF	
	
	DROP TABLE #MatchInfo
	DROP TABLE #RecoverBet
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransIds
END
GO