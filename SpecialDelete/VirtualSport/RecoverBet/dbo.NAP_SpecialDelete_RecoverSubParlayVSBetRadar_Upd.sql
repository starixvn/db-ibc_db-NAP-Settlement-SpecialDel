/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverSubParlayVSBetRadar_Upd] 
	@MatchId					INT,		
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
		
	Param's Explanation:		
		- @TransIds : Main transids.
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Action_Recal				VARCHAR(100)  = 'Re-Cal'
		  , @Action_Refund				VARCHAR(100)  = 'Refund'		  
		  , @Movebetdate				DATETIME
		  , @spName						VARCHAR(500) = OBJECT_NAME(@@PROCID)

	DECLARE @IsExistParlayVSBetradar	BIT = 0		  
		  , @avaiableProcess			BIT	= 0
		  , @isITAdmin					BIT	= 0
		  , @before_yesterday			DATETIME
		  , @CustIds					VARCHAR(MAX) = ''
	
	DECLARE @IgnoreList					VARCHAR(200)  = ''
		  , @_xml						XML		
		  , @_sXML						VARCHAR(MAX)  = ''	
		  , @strRefnos					VARCHAR(MAX) = ''		 	  
		  , @matchdate					DATETIME
		  , @eventstatus				NVARCHAR(100)
		  , @betstatus					NVARCHAR(100)
		  , @TicketInfos_Recal 			VARCHAR(MAX) = ''
		  , @ReCalculatedMainTransIds   VARCHAR(MAX)	= ''
		  , @NegativeBalanceUsers		VARCHAR(MAX)	= '' 
		  , @ErrMsg						NVARCHAR(200)	= ''
		  , @ErrCode					INT				= 0	
		  , @SiteDBGroupID				SMALLINT
		  , @transInfo					VARBINARY(MAX) 
		  , @IsExistsVS2				BIT = 0
		  , @IsExistsVS4				BIT = 0

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT)
		  
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
		showtime			NVARCHAR(20),
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
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	
	DECLARE @beforeUpd TVP_BalanceChange
		  , @afterUpd  TVP_BalanceChange
	
	SELECT @before_yesterday = CONVERT(varchar(10), DATEADD(day, -2, GETDATE()), 120)			 
		 , @ReCalculatedMainTransIds = '' 
		 , @NegativeBalanceUsers = ''
		 , @ErrCode = 0
		 , @ErrMsg = ''
	
	BEGIN TRY
		--> get match info
		SELECT @matchdate = eventdate
				, @eventstatus = eventstatus
				, @betstatus = betstatus
		FROM dbo.match (NOLOCK)
		WHERE matchid = @MatchId
			 
		/*Modify the way to get move bet date*/
		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
		
		IF @matchdate <= @Movebetdate
		BEGIN
			SELECT @ErrCode = 112
				 , @ErrMsg = 'Could not recover some tickets due to Movebet process. Please try Search again.'

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

			RETURN	
		END

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
				showtime,
				LeagueId,
				modds,	
				SubStatus,
				SubTransId,
				SubBetCheck,
				SubBetTeam,
				SubBetType,
				SubHdp1,
				SubHdp2,
				SubOdds,
				SubCustId,	
				SubTransdesc,				
				betfrom,
				matchid)
		SELECT  b.Stake,
				m.AwayId,
				b.BetCheck,
				b.BetId,
				b.BetTeam,
				b.BetType,
				b.CurrencyName AS CurrencyCode,
				b.Hdp1,
				b.Hdp2,
				m.HomeId,
				b.liveindicator AS IsLiveIndicator,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				NULL AS OddsType,
				b.RefNo,
				m.SportType,
				b.Status,
				b.TransDate,
				b.TransDesc,
				b.TransId,
				b.UserName,
				b.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				b.CustId,											
				ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime,
				m.leagueid,
				b.modds,	
				bm.Status AS SubStatus,
				bm.TransId AS SubTransId,
				bm.BetCheck AS SubBetCheck,
				bm.BetTeam AS SubBetTeam,
				bm.BetType AS SubBetType,
				bm.Hdp1 AS SubHdp1,
				bm.Hdp2 AS SubHdp2,
				bm.Odds AS SubOdds,
				bm.custid AS SubCustId,
				bm.transdesc AS SubTransdesc,				
				b.betfrom,
				bm.matchid
		FROM dbo.bettrans b WITH (NOLOCK)
				INNER JOIN bettransm bm WITH (NOLOCK)
						ON b.refno = bm.refno				
				INNER JOIN dbo.Match m WITH(NOLOCK)
						ON	m.matchid = bm.matchid
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
			AND bm.matchid = @MatchId	
			AND bm.winlostdate >= @before_yesterday
			AND b.bettype IN (2799, 10449)
			AND b.matchid IN (2799, 10449)
			AND bm.statusid = 102
			AND b.statusID NOT IN (101, 102) -- reject, void
			AND b.SiteDBGroupID = @SiteDBGroupID
				
		IF @@ROWCOUNT = 0
		BEGIN
			SELECT @ErrCode = 99, @ErrMsg = 'No ticket found.'

			SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds

			RETURN
		END

		--> Check Concurrency
		
		SELECT @IsExistsVS2 = CASE WHEN b.SportType BETWEEN 190 AND 199 THEN 1 ELSE 0 END
			  ,@IsExistsVS4 = CASE WHEN b.SportType = 188 THEN 1 ELSE 0 END
		FROM #RecoverBet b

		IF @IsExistsVS4 = 1
		BEGIN
			INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
			SELECT @MatchId, refno
			FROM #RecoverBet
			WHERE SportType = 188
		END
				
		EXEC dbo.NAP_Admin_CheckingProcess
			  @IsExistParlayVSBetradar	= @IsExistsVS2		
			, @IsLockingByRefnoVS		= @IsExistsVS4
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
			
		--> update bettransm to running + rec-cal sub tickets / refund sub tickets 
		IF @eventstatus = 'completed'
			AND @betstatus LIKE '%' + 'Refund' + '%'
		BEGIN
			--> refund sub
			SET @_xml = (
				SELECT 
						SubTransId '@t' -- transid
					,@matchdate '@d' -- winlostdate
					,0 '@w' -- statuswinlost
					,103 '@s' -- statusID
					,SubCustId '@cr' -- creator			
				FROM #RecoverBet					 		
				FOR XML PATH('r'), ROOT('root'), TYPE
			)		
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
				
			EXEC dbo.Bet_ExecRep_05 
					@IgnoreList 	= @IgnoreList
				  , @updatetype 	= 5
				  , @_sXML 			= @_sXML
		END
		ELSE
		BEGIN
			--> Update Bettransm to running
			SET @_xml = (
				SELECT 
					 SubTransId '@t' -- transid
					,NULL '@d' -- winlostdate
					,NULL '@w' -- statuswinlost
					,0 '@s' -- statusID
					,SubCustId '@cr' -- creator			
				FROM #RecoverBet					 		
				FOR XML PATH('r'), ROOT('root'), TYPE
			)		
			SELECT @_sXML = CONVERT(VARCHAR(MAX), @_xml)
				
			EXEC dbo.Bet_ExecRep_05 
					@IgnoreList 	= @IgnoreList
					, @updatetype 	= 5
					, @_sXML 		= @_sXML
					, @MatchId      = @MatchId
					
			IF @eventstatus = 'completed'
			BEGIN
				--> re-cal sub
				SET @_xml = (
					SELECT Matchid '@m' 
						 , SubTransId '@t'
					FROM #RecoverBet						
					FOR XML PATH('r'), ROOT('root'), TYPE
				) 
				SELECT @TicketInfos_Recal = CONVERT(VARCHAR(MAX), @_xml)
				
				IF @IsExistsVS2 = 1
				BEGIN
					EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay] 
							@mode = 'RECOVER'
							, @TicketInfos = @TicketInfos_Recal
							, @ErrCode = @ErrCode OUTPUT
							, @ErrMsg = @ErrMsg OUTPUT
				END
				IF @IsExistsVS4 = 1
				BEGIN
					EXEC [dbo].[TicketVoiding_ReCalculate_ParlayVS_Update] 
							  @mode = 'RECOVER'
							, @TicketInfos = @TicketInfos_Recal
							, @ErrCode = @ErrCode OUTPUT
							, @ErrMsg = @ErrMsg OUTPUT
				END
			END					
		END							
			
		--> re-cal main
		SELECT @strRefnos = CAST((
			SELECT refno AS '@rn'
			FROM #RecoverBet				
			FOR XML PATH('r'), ROOT('root'), TYPE
		) AS VARCHAR(MAX))	
		
		IF @IsExistsVS2 = 1
		BEGIN				
			EXEC [dbo].[NAP_Admin_Calculate_VS_BetRadar_Parlay_Main]
				 @MatchId			= @matchId
				,@strRefnos 		= @strRefnos
				,@matchdate			= @matchdate
				,@IsBalance			= 0
				,@CWLBettype		= 1201
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT		
		END
		IF @IsExistsVS4 = 1
		BEGIN
			EXEC [dbo].[TicketVoiding_ReCalculate_ParlayVS_Update]
					 @MatchId			= @matchId
					,@strRefnos 		= @strRefnos
					,@matchdate			= @matchdate
					,@IsBalance			= 0
					,@CWLBettype		= 1201
					,@ErrCode			= @ErrCode OUTPUT
					,@ErrMsg			= @ErrMsg OUTPUT
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

		--> Delete zzzbettransm
		DELETE z
			OUTPUT deleted.transid, deleted.matchid
			INTO @tmpTransInfo (transid, matchid)
		FROM zzzbettransm z WITH(ROWLOCK, UPDLOCK)
				INNER JOIN #RecoverBet t 
						ON	z.transid = t.SubTransId
						AND z.custid = t.SubCustId
						AND z.matchid = @Matchid
						AND z.bettype = t.SubBetType
		
		IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN			
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType, EventTable)
			SELECT 'TVS', 'RecoverVS', 'zzzbettransm', 'D', @matchid, @TransInfo, 'p', 1
		END
			
		--> Release Concurrency process
		EXEC dbo.NAP_Admin_CheckingProcess
				@IsExistParlayVSBetradar	= @IsExistsVS2
			, @IsLockingByRefnoVS		= @IsExistsVS4
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
											+ CAST(t.TransId AS VARCHAR(100))
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
				  @IsExistParlayVSBetradar	= @IsExistsVS2
				, @IsLockingByRefnoVS		= @IsExistsVS4
				, @IsReleased				= 1	

		SELECT @ErrCode AS ErrorCode
				,@ErrMsg AS ErrorMsg
				,@NegativeBalanceUsers AS NegativeBalanceUsers
				,@ReCalculatedMainTransIds AS ReCalculatedMainTransIds
	END CATCH		
	
	DROP TABLE #tblMatchParlayProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #tblTransIds
	DROP TABLE #RecoverBet

	SET NOCOUNT OFF		
END
GO