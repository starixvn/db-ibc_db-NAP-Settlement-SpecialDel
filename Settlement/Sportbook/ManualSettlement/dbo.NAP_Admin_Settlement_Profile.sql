/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile]
	 @creator			INT
	,@MatchID			INT
	,@Action		  	VARCHAR(10)		= 'CAL'
	,@IP	 			VARCHAR(15)		= ''
	,@ErrCode			INT				= 0	OUTPUT
	,@ErrMsg 			NVARCHAR(200)	= '' OUTPUT
	,@SelectedResources VARCHAR(MAX)
AS
/*  Creator: 20180821@Vicky
	Task: Settlement for sport in profile
	DB: DBTXN/BODB02

	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190301@Sol:  New Formula for Comm [Redmine:#109007]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20190924@Sol: Incorporate BMAIO - modified sp to add oddstype [Redmine:#120324]

	Param's Explanation:
		* @SelectedResources= '<Resources>
									<Resource Id="M1" Home="1" Away="3" />
									<Resource Id="M2" Home="2" Away="4" />
							   </Resources>'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SkipBalanceUpdate  BIT
			,@start				DATETIME
			,@stop				DATETIME
			,@fth				INT
			,@fta				INT
			,@hth				INT
			,@hta				INT
			,@ActionID		  INT
			,@Remark			VARCHAR(500)
			,@LogData		   NVARCHAR(300)
			,@avaiableProcess	BIT
			,@xml				XML
			,@strResourceIds	VARCHAR(MAX)
			,@sportType 		INT
			,@existsFinalRound	BIT
			,@existsHTRound		BIT
			,@ticketCount		INT				= 0
			,@handle			INT
			,@TotalAccount		INT
			,@TotalAccount_BalanceUpdate INT
			,@batchNo			INT 			= 2000
			,@batchCount		INT		
			,@strTransIds		VARCHAR(MAX)	= ''
			,@ResultRemarkLog	VARCHAR(MAX)	= ''
			,@SelectedRID		VARCHAR(MAX)	= ''

  	--START Balance tables
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		   , @BalanceWalletAfter		TVP_BalanceWalletChange
	--END Balance tables

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	DECLARE @tmpResultDetail TABLE (ResourceId VARCHAR(20), bettype SMALLINT, betid BIGINT)
	CREATE TABLE #tmpTransID (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, isFinish BIT, srecommend INT, bettype SMALLINT)
	DECLARE @tmpTransIDBatch TABLE (TransID BIGINT, modds SMALLMONEY, OddsType SMALLINT, srecommend INT, bettype SMALLINT)
	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT, RoundID VARCHAR(10), OrdNo SMALLINT,
								  isFinal BIT, RoundName VARCHAR(20), GroupType VARCHAR(2), OddsType SMALLINT
								  ,PRIMARY KEY (BetType,BetID))
	----------------------------------------------------------------------------------------------------------------------

  	SELECT  @start = CURRENT_TIMESTAMP
		   ,@ActionID = CASE
						  WHEN @Action = 'CAL' THEN 100
						  WHEN @Action = 'UNDO' THEN 103
						  WHEN @Action = 'REFUND' THEN 109
						  WHEN @Action = 'CAL_EAR' THEN 189
						  WHEN @Action = 'UNDO_EAR' THEN 190
						  WHEN @Action = 'REFUND_EAR' THEN 191
						  ELSE 0
					   END
		   ,@SkipBalanceUpdate	 = 0

  	--get info of match
  	SELECT @fth			= finalhomescore
		  ,@fta			= finalawayscore
		  ,@hth			= hthomescore
		  ,@hta			= htawayscore
		  ,@sportType	= sportType
  	FROM	DBPRO.BODB02.dbo.match WITH (NOLOCK)
  	WHERE   matchid = @matchid

  	-- check and not allow attempt to settlement same game while it's still not finish
  	INSERT INTO #tblMatchProcess(matchid, KeyID)
  	SELECT	@matchid AS matchid ,1 AS KeyId
  	----------------------------------------------------------------------------------------------------------------------


	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch			= 1
		  , @avaiableProcess 	= @avaiableProcess OUTPUT
		  , @ErrCode			= @ErrCode OUTPUT
		  , @ErrMsg				= @ErrMsg OUTPUT

	--check error
	IF(@ErrCode <> 0 OR @avaiableProcess = 0)
	BEGIN
		SELECT   @ErrCode   = 1000000
				,@ErrMsg	= 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END


  	------------------------------------------parse XML and add more info-----------------------------------------
  	

	EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
	INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, RoundID, OrdNo, isFinal, RoundName, GroupType, OddsType)
	SELECT DISTINCT Id, Home, Away, sp.BetType, sp.BetID, sp.pfID, sp.RoundID, sp.OrdNo, sd.isFinal, sd.RoundName, sp.GroupType, sp.OddsType
	FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
														,Home VARCHAR(50)
														,Away VARCHAR(50)
										) AS tbl
		INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.Id
		LEFT JOIN dbo.f_Set_MajorRound(@Sporttype) sd ON sp.ResourceID = sd.ResourceID
	WHERE sp.SportType = @SportType 
	
	EXEC sp_xml_removedocument @handle
  	

  	SELECT   @SelectedRID   = (SELECT Bettype   AS '@bt'
									 ,BetID	AS '@b'
							  FROM @tmpSelectedRID
							  FOR XML PATH('r'), ROOT( 'root' ))  
	-------------------------------------------------------END parse XML----------------------------------------------------------------------
  	

  	--get transid
  	IF @Action LIKE 'CAL%'
  	BEGIN
		INSERT INTO #tmpTransID(TransID, modds, OddsType, srecommend, bettype)
	  	SELECT transid, m.modds, sr.OddsType, b.srecommend, b.bettype
	  	FROM bettrans b WITH (NOLOCK)
	  		CROSS APPLY(
	  						SELECT TOP 1 pfID, HomeValue, AwayValue, t.OddsType
	  						FROM @tmpSelectedRID t
	  						WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  					) sr
	  		CROSS APPLY dbo.f_Set_Calculate_modds(sr.pfID, b.betteam, b.hdp1, b.hdp2, sr.HomeValue, sr.AwayValue, b.livehomescore, b.liveawayscore) m
	  	WHERE b.matchid = @MatchId
	  		AND b.statusID NOT IN (101)
	END
	ELSE IF @action LIKE 'UNDO%'
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT transid
	  	FROM bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID)
	  	WHERE b.matchid = @MatchId
	  		AND	b.statusID NOT IN (0, 1, 101)
	END 
	ELSE IF @action LIKE 'REFUND%'
	BEGIN
		--get transid
		INSERT INTO #tmpTransID(TransID)
	  	SELECT transid
	  	FROM bettrans b WITH (NOLOCK)
	  		INNER JOIN @tmpSelectedRID t ON b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	  	WHERE b.matchid = @MatchId
	  		AND	b.statusID NOT IN (103, 101)
	END 
	
		
	---check FT round
	SET @existsFinalRound = 0
  	SELECT TOP 1 @existsFinalRound = 1
				,@fth = sr.HomeValue
				,@fta = sr.AwayValue
  	FROM @tmpSelectedRID sr
  	WHERE GroupType = 'FT' AND isFinal = 1 
  	
  	
  	---check HT round
  	SET @existsHTRound = 0
  	SELECT TOP 1 @existsHTRound = 1
				,@hth = sr.HomeValue
				,@hta = sr.AwayValue
  	FROM @tmpSelectedRID sr
  	WHERE GroupType = 'HT' AND isFinal = 1 

  	IF @existsFinalRound = 1
  	BEGIN
	  	IF @Action LIKE 'CAL%'
	  	BEGIN
			SELECT  @hth	= COALESCE (@hth, 0)
					,@hta   = COALESCE (@hta, 0)
					,@fth   = COALESCE (@fth, 0)
					,@fta   = COALESCE (@fta, 0)
		END
		
		IF @Action LIKE 'REFUND%'
	  	BEGIN
			SELECT  @hth	= COALESCE (@hth, 0)
					,@hta   = COALESCE (@hta, 0)
					,@fth   = COALESCE (@fth, 0)
					,@fta   = COALESCE (@fta, 0)
		END
		
		IF @Action LIKE 'UNDO%'
	  	BEGIN
			SELECT  @hth	= NULL
					,@hta   = NULL
					,@fth	= NULL
					,@fta	= NULL
		END
	END
  	
	-------------BEGIN TRY------------------------------------------
	BEGIN TRY

		IF @Action LIKE 'CAL%'
		BEGIN
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
						@Command				= 'profile'
						,@Action				= 'CAL'
						,@MatchID				= @matchid
						,@FTHome				= @fth
						,@FTAway				= @fta
						,@HTHome				= @hth
						,@HTAway				= @hta
						,@creator				= @creator
						,@IsFinalRound			= @existsFinalRound
						
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
						@action					= 'CAL'
						,@MatchID				= @MatchID
						,@creator				= @creator
						,@Sporttype				= @Sporttype
						,@SelectedRID   		= @SelectedResources
		END
		
		-------------------------------------------------------------
		---		CAPTURE value BALANCE before settlement		---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletBefore (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
						@MatchId 				  = @matchId
						,@sportType				  = @sportType
						,@Action 				  = @Action
						,@Mode 					  = 2
						,@SelectedRID			  = @SelectedRID
		SELECT @TotalAccount = @@ROWCOUNT
		

		------START UPDATE BETTRANS---------------------------------------------------------------------------
		WHILE 1=1
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(@batchNo) t
			SET isFinish = 1
			OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.srecommend, deleted.bettype
			INTO @tmpTransIDBatch(transid, modds, OddsType, srecommend, bettype)
			FROM #tmpTransID t 
			WHERE isFinish IS NULL

			SELECT @batchCount 	= @@ROWCOUNT
				  ,@ticketCount	+= @batchCount
			
			IF @batchCount = 0 BREAK

			--filter selectedRID by current Profile and BetType
			SET @strTransIds 		= (SELECT transid	AS '@t'
											   ,modds	AS '@m'
											   ,OddsType	AS '@ot'
											   ,srecommend AS '@sr'
											   ,bettype AS '@bt'
									   FROM @tmpTransIDBatch
									   FOR XML PATH('r'), ROOT( 'root' ))

			EXEC dbo.NAP_Admin_Calculate_Main
				@matchid	  		 = @matchid
			   ,@action				 = @action
			   ,@IsSettingByProfile  = 1
			   ,@strTransIds		 = @strTransIds
		END

		------END UPDATE BETTRANS---------------------------------------------------------------------------
			
		-------------------------------------------------------------
		---		 CAPTURE value BALANCE after settlement		---
		---------------------------VVVV------------------------------
		
		INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
					@MatchId		  	= @matchId
					,@sportType			= @sportType
					,@Action 			= @Action
					,@Mode 			  	= 2 --Used for Manual settle process
					,@SelectedRID		= @SelectedRID
	
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					@BalanceWalletBefore	= @BalanceWalletBefore
					,@BalanceWalletAfter	= @BalanceWalletAfter
					,@ActionId				= @ActionID
		------END UPDATE BETTRANS---------------------------------------------------------------------------
		
					
		IF @Action LIKE 'CAL%'
		BEGIN

			IF  @existsFinalRound = 1
			BEGIN				 
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid				= @matchid
							,@command				= 'C'
			END

		END-------------------end CAL
		ELSE IF @action LIKE 'UNDO%'
		BEGIN

			--update ResultDetail before settle Parlay
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
							@action  			= 'UNDO'
							,@matchid 			= @MatchId
							,@SelectedRID   	= @SelectedResources
							,@Sporttype			= @Sporttype
							,@creator 			= @creator
							
			EXEC dbo.NAP_Admin_Settlement_MP
							@matchid			= @matchid
							,@creator			= @creator
							,@action			= 'UNDO'
							,@SelectedResources = @SelectedResources
							,@IP				= @IP
			IF @existsFinalRound = 1
			BEGIN
				EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid			= @matchid
							,@command			= 'U'
							,@IsFinalRound		= @existsFinalRound
			END
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
							@Command			='profile'
							,@Action			='UNDO'
							,@MatchID			= @matchid
							,@creator			= @creator
							,@IsFinalRound		= @existsFinalRound
														
			IF @existsFinalRound = 1
			BEGIN
				EXEC DBACC.bodb02.dbo.NAP_Admin_Match_UpdateSaveBet
							@action				= 'UNDO'
							,@matchid			= @matchid
							,@IsFinalRound		= @existsFinalRound
			END
		END-------------------end UNDO
		ELSE IF @Action LIKE 'REFUND%'
		BEGIN
			
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Match_Update
							@matchid			= @matchid
							,@command			= 'profile'
							,@Action			= 'REFUND'
							,@FTHome			= @fth
							,@FTAway			= @fta
							,@HTHome			= @hth
							,@HTAway			= @hta
							,@IsFinalRound  	= @existsFinalRound
							
			EXEC DBPRO.BODB02.dbo.NAP_Admin_Result_Update_9001
							@action				= 'REFUND'
							,@MatchID			= @MatchID
							,@creator			= @creator
							,@Sporttype			= @Sporttype
							,@SelectedRID   	= @SelectedResources
							
			IF  @existsFinalRound = 1
			BEGIN
				  EXEC DBPRO.BODB02.dbo.NAP_updateMatch_remark
							@matchid			= @matchid
							,@command			= 'F'
							,@IsFinalRound		= @existsFinalRound

			END
		END------------end REFUND

		
	END TRY
	BEGIN CATCH
		  -------------------------------------------------------------
		  ---		 CAPTURE value BALANCE after settlement		---
		  ---------------------------VVVV------------------------------
		  
		  INSERT INTO @BalanceWalletAfter (matchid, custid, balanceType, WalletType, BonusID, balance)
		  EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
				  @MatchId 				= @matchId
				  , @sportType			= @sportType
				  , @Action 			= @Action
				  , @Mode 				= 2 --Used for Manual settle process
				  , @SelectedRID		= @SelectedRID
	
		  -- Compare and update pending balance with error case
		  EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @BalanceWalletBefore
				  , @BalanceWalletAfter	= @BalanceWalletAfter
				  , @ActionId			= @ActionID
		  
		  
		  SELECT	@ErrCode = 1001017
					,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
	
		  ------ releasing Settlement process
		  EXEC dbo.NAP_Admin_CheckingProcess
					  @isExistMatch		= 1
					  , @IsReleased		= 1
	
		  RETURN
	END CATCH


	SELECT @TotalAccount_BalanceUpdate = COUNT(DISTINCT a.custid)
	FROM @BalanceWalletAfter a
		INNER JOIN @BalanceWalletBefore b 
		ON	 a.matchid				= b.matchid
				AND a.custid		= b.custid
				AND a.balanceType	= b.balanceType
				AND a.walletType	= b.walletType
				AND a.bonusId		= b.bonusId
	WHERE a.balance <> b.balance
	
	
	-------------------------------------------------------------
	---					  WRITE LOG						---
	---------------------------VVVV------------------------------
	SELECT @stop = CURRENT_TIMESTAMP
	
	SELECT @ResultRemarkLog = @ResultRemarkLog + ',' +  ISNULL(RoundName,ResourceID) + 
			CASE WHEN HomeValue IS NOT NULL AND AwayValue IS NOT NULL THEN '(' + HomeValue + '-' + AwayValue + ')'
				 WHEN HomeValue IS NOT NULL AND AwayValue IS NULL THEN '(' + HomeValue + ')'
				 WHEN HomeValue IS NULL AND AwayValue IS NULL THEN ''
				 ELSE '' END
	FROM (
			SELECT DISTINCT ResourceID, HomeValue, AwayValue, RoundName, MAX(OrdNo) AS OrdNo
		  	FROM @tmpSelectedRID sr
		  	GROUP BY ResourceID, HomeValue, AwayValue, RoundName
  		) AS tbl1
	ORDER BY OrdNo

	SELECT @ResultRemarkLog =  CASE WHEN @Action LIKE 'CAL%' THEN 'Result:' ELSE 'Selected:' END + SUBSTRING(@ResultRemarkLog, 2, LEN(@ResultRemarkLog))
	 
	
	SELECT @logdata = 'NAP: Calculate (' + @action + ') for matchid:' + CAST(@matchid AS NVARCHAR(10))
							+ ' Result: ' + @SelectedResources + '<br/> '
							+ '(' + CAST(DATEDIFF(millisecond, @start, @stop) AS NVARCHAR(50)) + ' ms)'
						   
						   
	SELECT @Remark = @ResultRemarkLog + '<br/> ' 
						+ 'Duration:' + CAST(DATEDIFF(MILLISECOND, @start, @stop) AS NVARCHAR(50)) + ' ms' 
						+ '; TC:' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20)) 
						+ '; Bal:' + CAST(ISNULL(@TotalAccount_BalanceUpdate, 0) AS VARCHAR(20)) + '/' + CAST(IsNull(@TotalAccount, 0) AS VARCHAR(20))
				
				
				
	EXEC dbo.WriteLog_UserLog
				@UserID = @creator
				,@Doing = @logdata
				
	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@userid				= @creator
				,@matchid			= @MatchID
				,@actionid			= @ActionID
				,@finalhomescore	= @fth
				,@finalawayscore	= @fta
				,@hthomescore		= @hth
				,@htawayscore		= @hta
				,@GoalRecord		= NULL
				,@Remark			= @Remark
				,@ip				= @ip
	END TRY
	BEGIN CATCH
		SELECT @remark = @remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)
		EXEC bodb_CustomerLog.dbo.WriteLog_UserLog_Settle
				@UserID				= @creator
				,@MatchID			= @matchid
				,@actionid			= @actionid
				,@finalhomescore	= @fth
				,@finalawayscore	= @fta
				,@hthomescore		= @hth
				,@htawayscore		= @hta
				,@GoalRecord		= NULL
				,@betstatus			= NULL
				,@Remark			= @Remark
				,@IP				= @ip
	END CATCH
 

	----------------------------------- releasing Settlement process--------------------------------------------
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		  ,@IsReleased		= 1
END
GO