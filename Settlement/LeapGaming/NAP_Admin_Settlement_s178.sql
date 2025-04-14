/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE  NAP_Admin_Settlement_s178
	@AdminId			INT		
	,@MatchId			INT
	,@Action			VARCHAR(10)		
	,@SelectedResources	VARCHAR(MAX)
	,@IsReSettledTickets BIT			= 1
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Creator: 20230704@Louisa 
	Task: Virtual Leap Gaming - VS3
	DB: DBTXN/bodb02 
	
	Revisions:
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 - sporttype 178 [Redmine:#189854]
		- 20230905@Aries: Set Max Payout for Non-sports Products [Redmine:#193259]
		- 20231002@Louisa: Integrate new sporttype 179, new bettype for sporttype 178 [Redmine:#194655]
		- 20240118@Louisa: Integrate VS4 - Cock Fighting [Redmine: #199700]
		- 20250328@Louisa: extend data type of currency from tinyint to smallint [Redmine:#222173]
		- 20250408@Aries: Remove the redundant information from the alert when exceeded Max Payout of Virtual Sport [Redmine:#223116]
	Param's Explanation:
		@Action - CAL
				- REFUND

		 <Resources>
                <Resource Id="00" Home="1" Away="3" /> 
                <Resource Id="01" Home="1" Away="2" />
        </Resources>
 
*/

BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime				DATETIME
			,@EndTime				DATETIME
			,@avaiableProcess		BIT
			,@ActionId				INT
			,@batchCount			INT = 2000
			,@strTransIds			VARCHAR(MAX)  
			,@strRefnos				VARCHAR(MAX) = ''
			,@procName				SYSNAME
			,@remark				VARCHAR(200)
			,@IsCentral				BIT
			,@handle				INT
			,@matchdate 			SMALLDATETIME
			,@sporttype				TINYINT
			,@SiteDBGroupId			SMALLINT
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@TotalTransMaxPO		INT = 0
			,@batchPO				SMALLINT = 500
			,@ResourcesJson			VARCHAR(MAX) = ''
	
	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)
	DECLARE @tmpTransIDMaxPO TABLE (TransID BIGINT, custid INT, actualPO MONEY, winlost MONEY, transdate DATETIME, bettype SMALLINT )

	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, winlost MONEY, actualPO MONEY, IsApplyMaxPO BIT,OddsType SMALLINT) 
	DECLARE @tmpSelectedResources TABLE ( ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
										  BetType SMALLINT,OddsType SMALLINT,  BetID BIGINT, pfID SMALLINT ,PRIMARY KEY (BetType,BetID)
										  )

	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, isFinish BIT
		,custid INT, currency SMALLINT, actualPO MONEY, winlost MONEY, IsApplyMaxPO BIT
		,transdate DATETIME, bettype SMALLINT,OddsType SMALLINT
		,statusID	TINYINT
	)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT) 
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT @sporttype	= m.sporttype 
		  ,@matchdate	= CAST(eventdate AS DATE)
	FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

	SELECT @ActionID  = CASE @Action WHEN 'CAL' THEN CASE WHEN @sporttype IN (178, 179) THEN 81043
														 WHEN @sporttype = 188 THEN 81050
														 END
									WHEN 'REFUND' THEN CASE WHEN @sporttype IN (178, 179) THEN  81044
															WHEN @sporttype = 188 THEN 81051
															END
						END
			,@StartTime	= CURRENT_TIMESTAMP
			,@procName	= OBJECT_NAME(@@PROCID)
			,@SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())

	INSERT INTO #tblMatchProcess (matchid, KeyID)
	SELECT	@matchid AS matchid, 1 AS KeyID
	
	---- lock match single
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch			= 1
		  , @SPName				= @procName
		  , @avaiableProcess 	= @avaiableProcess OUTPUT
		  , @ErrCode			= @ErrCode OUTPUT
		  , @ErrMsg				= @ErrMsg OUTPUT
			
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN
		SELECT	@ErrCode 
				,@ErrMsg	
		RETURN
	END	
	----/ end check lock match single

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources

	INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, OddsType )  
	SELECT Id, ISNULL(Home,''), ISNULL(Away,''), sp.BetType, sp.BetID, sp.pfID , sp.OddsType
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
			ON	sp.ResourceID = tbl.Id
	WHERE sp.SportType = @sporttype

	EXEC sp_xml_removedocument @handle
    
	BEGIN TRY
		IF @Action = 'CAL'
		BEGIN
			INSERT INTO #tmpTransID (TransID, modds, custid, currency, actualPO, transdate, bettype,OddsType,statusID)
			SELECT	transid
				   ,m.modds
				   ,b.custid					
				   ,b.currency
				   ,CASE
				   		WHEN m.modds >  0.25 THEN b.actual_stake + b.stake * (CASE WHEN b.odds < 0 THEN 1  
																				   WHEN sr.oddstype = 1 THEN b.odds - 1 
																				   ELSE b.odds 
																				END)
				   		WHEN m.modds =  0.25 THEN b.actual_stake + b.stake * 0.5 * (CASE WHEN b.odds < 0 THEN 1  
																						 WHEN sr.oddstype = 1 THEN b.odds - 1 
																						 ELSE b.odds 
																					END)
				   		ELSE NULL
				    END actualPO		
				   ,b.transdate
				   ,b.bettype
				   ,sr.OddsType
				   ,b.statusID
			FROM	dbo.bettrans b WITH (NOLOCK)
			CROSS APPLY(
							SELECT TOP 1 pfID, HomeValue, AwayValue, OddsType
							FROM @tmpSelectedResources t
							WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
						) sr
					CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc, NULL) m
			WHERE	b.matchid = @MatchId
					AND b.statusID <> 101
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND 1 = CASE WHEN @IsReSettledTickets = 0 AND statusID IN (0,102) THEN 1
								 WHEN @IsReSettledTickets = 1 THEN 1
								 ELSE 0
							END

			-- check if winlost reaches the maxpayout
			IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
			BEGIN
				;WITH cteCustIds
				AS(
					SELECT DISTINCT custid, currency
					FROM	#tmpTransID t
					WHERE	modds >= 0.25						
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
					FROM	#tmpTransID t
						INNER JOIN	@tmpMaxWinLimit m
							ON t.CustId = m.CustId
					WHERE	t.actualPO > m.MaxWinLimit
						AND t.statusID != 102

					SET @TotalTransMaxPO = @@ROWCOUNT
				END
					
			END
		END

		IF @action = 'REFUND'  
		BEGIN
			INSERT INTO #tmpTransID(TransID)
	  		SELECT	transid
	  		FROM	dbo.bettrans b WITH (NOLOCK)
	  			INNER JOIN @tmpSelectedResources t 
					ON	b.BetType = t.BetType 
						AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  		WHERE	b.matchid = @MatchId
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	  				AND	b.statusID NOT IN (103, 101)
		END
	
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchCount) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.winlost, deleted.actualPO, deleted.IsApplyMaxPO,deleted.OddsType
			INTO @tmpTransIDBatch(transid, modds, winlost, actualPO, IsApplyMaxPO,OddsType)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds = (SELECT transid		AS '@t'
										,modds		AS '@m'
										,ISNULL(OddsType,0) AS '@ot'
										,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
										,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
										,IsApplyMaxPO AS '@iMPO'
								FROM @tmpTransIDBatch
								FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @MatchID 
			   ,@action				 = @Action  
			   ,@strTransIds		 = @strTransIds
			   ,@EventTable			 = 1
			   ,@Is3rd				 = 1 
			   ,@IsCalculateBalance  = 1
			   ,@CWLBettype			 = 1201
			   ,@BalanceType		 = 4

		END	
	END TRY
	BEGIN CATCH
		SELECT	@ErrCode = ERROR_NUMBER()
				,@ErrMsg = ERROR_MESSAGE()	
				
		EXEC dbo.NAP_Admin_CheckingProcess
				@isExistMatch 	= 1
				,@IsReleased	= 1

		RETURN

	END CATCH

	
	-- Releasing settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch 	= 1
		,@IsReleased	= 1

	WHILE (@TotalTransMaxPO > 0)
	BEGIN
		IF @TotalTransMaxPO > @batchPO
		BEGIN
			DELETE @tmpTransIDMaxPO

			DELETE TOP (@batchPO) t
				OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
				INTO @tmpTransIDMaxPO(custid, winlost, actualPO, transdate, bettype, transid)
			FROM	#tmpTransID t
			WHERE	IsApplyMaxPO = 1

			SET @TransInfoMaxPO = CAST((
									SELECT	TOP (@batchPO) CustId AS a1
											,@sporttype AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminId AS a12 -- createdby
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
											,@sporttype AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminId AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	#tmpTransID
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


	IF EXISTS ( SELECT TOP 1 1
				FROM dbo.bettransm bm WITH(ROWLOCK)
				WHERE matchid = @matchid
					AND statusID NOT IN(1, 101)
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
				)
	BEGIN
		SELECT @ResourcesJson = CONVERT(VARCHAR(MAX), ( SELECT r.HomeValue AS 'h', r.AwayValue AS 'a', r.pfID AS 'pfid', r.BetType AS 'bt', r.BetID AS 'bid'
															FROM @tmpSelectedResources r
															FOR JSON AUTO
														)
										)

		EXEC dbo.NAP_Admin_Settlement_MP_VS
			@AdminId			= @AdminId
			,@MatchId			= @MatchId
			,@SportType			= @sporttype
			,@ResourcesJson		= @ResourcesJson
			,@Action			= @Action
			,@ActionID			= @ActionID
			,@MatchDate			= @MatchDate
			,@ErrCode			= @ErrCode	OUTPUT
			,@ErrMsg			= @ErrMsg	OUTPUT
	END

END
GO