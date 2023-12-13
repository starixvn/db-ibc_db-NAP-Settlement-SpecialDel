/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Profile_Instant]
	 @MatchID					INT 
	,@AdminId 					INT
	,@Action					VARCHAR(20)		= 'CAL'
	,@SelectedResources			VARCHAR(MAX)
	,@IP						VARCHAR(15)
	,@IsReSettledTickets		BIT				= 0
	,@DeterminedType			TINYINT			= 0
	,@hth						INT				= NULL
	,@hta						INT				= NULL
	,@fth						INT				= NULL
	,@fta						INT				= NULL
	,@BroadcastSessionId		VARCHAR(50)		= NULL
	,@ErrCode					INT				= 0		OUTPUT
	,@ErrMsg					NVARCHAR(200)	= ''	OUTPUT
	
AS
/*    
	Creator: 20230515@Aries
    Task: Apply Settle Determined for Basketball
    DB: DBTXN/BODB02
	Original:

    Revisions:
		- 20230515@Aries: Created [Redmine:#175202]
		- 20230817@Kathy: Write log [Redmine:#192311]
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		- 20230921@Kathy: change the way to write log for single ticket [Redmine:#193125]
		- 20231213@Aries: Enhance Recalculation and Instant Settle for Basketball [Redmine:#198283]

    Param's Explanation:
        - @Action: 'CAL', 'CAL-INST'
        - @SelectedResources: <Resources><Resource Id="01" Home="35" Away="45"/></Resources>
    
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE  @SportType						SMALLINT		
		    ,@ActionId						INT		
			,@IsInstant						BIT = 0

			,@Start							DATETIME
			,@Stop							DATETIME

			,@fthSDT						INT
			,@ftaSDT						INT
			,@hthSDT						INT
			,@htaSDT						INT
			,@HTDone						BIT 
			,@FTDone						BIT 

            ,@IsCentral						BIT
		    ,@AvaiableProcess				BIT

		    ,@Handle						INT
            ,@DummyResourceIds				VARCHAR(MAX) 
            ,@DummyResourceResults			VARCHAR(MAX)
            ,@SelectedResourceParlay		VARCHAR(MAX) 
            ,@StrTransIds					VARCHAR(MAX) = ''
			,@StrUndoTransIds				VARCHAR(MAX) = ''

		    ,@SPName						SYSNAME	= OBJECT_NAME(@@procid)
		    ,@TicketCount					INT = 0
	        ,@BatchNo						INT = 2000
            ,@BatchCount					INT	
			,@Remark						VARCHAR(MAX) = ''
			,@RemarkSDT						VARCHAR(MAX) = ''
			,@Selected						VARCHAR(MAX) = ''
            
		    ,@TotalSubParlay				INT
		    ,@ThresholdRefno				INT 
		    ,@LockedByRefno					BIT

		    ,@SqlCommand					VARCHAR(MAX)

			,@ResultTable					TINYINT
			,@BroadcastSessionIdInstant		VARCHAR(50)		= @BroadcastSessionId + '_instant'
			,@SiteDBGroupId					TINYINT

			,@HTHome_Inst					INT
			,@HTAway_Inst					INT
			,@FTHome_Inst					INT
			,@FTAway_Inst					INT
		
	DECLARE @tmpSelectedRID TABLE(BetType SMALLINT, BetID BIGINT,SDTResourceId VARCHAR(20),RefResourceID VARCHAR(20),ResourceID VARCHAR(20), SDTpfId SMALLINT, HomeValue VARCHAR(2000), AwayValue VARCHAR(2000), OddsType TINYINT, isCalculated BIT, MinusValue SMALLMONEY   DEFAULT(0),IsInstHTFT BIT, PRIMARY KEY (BetType,BetID))	
    DECLARE @tmpResources TABLE(SDTResourceId VARCHAR(20),HomeValue VARCHAR(2000),AwayValue VARCHAR(2000))
	DECLARE @tmpParlayAffectedBettypes TABLE (BetType SMALLINT, TotalTicket INT)	

    DECLARE @tmpTransIDBatch TABLE (TransID BIGINT,CustID INT, modds SMALLMONEY, OddsType SMALLINT, srecommend INT, bettype SMALLINT, IsMarked	BIT, winlost MONEY, statuswinlost TINYINT, IsUndo BIT)
	DECLARE @tmpCashoutTransId AS TABLE (TransId BIGINT,modds SMALLMONEY, winlost MONEY, statuswinlost TINYINT, currentstatuswinlost TINYINT, IsUndo BIT)

	CREATE TABLE #tmpTransSDT (TransID BIGINT,CustID INT, modds SMALLMONEY DEFAULT 0, OddsType SMALLINT, srecommend INT,bettype SMALLINT, IsMarked BIT, IsUndo BIT , BetdaqId BIGINT, currentStatuswinlost TINYINT,betteam VARCHAR(20),hdp1 SMALLMONEY,IsInstHTFT BIT)
	CREATE CLUSTERED INDEX IX_tmpTransSDT_modds ON #tmpTransSDT (modds);

    CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	

    SELECT  @ActionID = CASE WHEN @Action = 'CAL' THEN 100
							 WHEN @Action = 'CAL-INST' THEN 81042
						END
		   ,@IsInstant = IIF(@Action = 'CAL-INST',1,0)
		   ,@Start = CURRENT_TIMESTAMP

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT	 @SportType = m.sporttype			
	FROM	dbo.match AS m WITH(NOLOCK)
	WHERE	m.matchid = @MatchID

	SELECT	@ResultTable = ResultTable
	FROM	dbo.SettlementResultTableSetting WITH(NOLOCK)
	WHERE	Sporttype = @Sporttype

	EXEC sp_xml_preparedocument @Handle OUTPUT, @SelectedResources
	INSERT INTO @tmpResources (SDTResourceId, HomeValue, AwayValue)
	SELECT	Id
           ,ISNULL(Home,'')
           ,ISNULL(Away,'')
	FROM OPENXML(@Handle,'Resources/Resource',1) WITH(Id VARCHAR(20),Home VARCHAR(2000),Away VARCHAR(2000)) AS tbl
	EXEC sp_xml_removedocument @Handle

	IF @DeterminedType = 0
	BEGIN
		RETURN
	END 

	EXEC DBPRO.bodb02.dbo.NAP_Set_HoldSettingChecking
		 @MatchID	= @MatchID
		,@ErrCode	= @ErrCode OUTPUT
		,@ErrMsg	= @ErrMsg OUTPUT

	IF ISNULL(@ErrCode,0) <> 0
	BEGIN
	    SELECT	 @ErrCode 
				,@ErrMsg 
	    RETURN
	END

	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT @MatchID AS matchid
		,1 AS KeyId
			
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		 @isExistMatch		= 1
		,@AvaiableProcess 	= @AvaiableProcess OUTPUT
		,@ErrCode			= @ErrCode OUTPUT
		,@ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @AvaiableProcess = 0) 
    BEGIN 
        RETURN
    END
	
	BEGIN TRY
		INSERT INTO @tmpSelectedRID(Bettype,BetID, SDTResourceId,RefResourceID,ResourceID, SDTpfId, OddsType, IsInstHTFT)
		SELECT DISTINCT s.BetType,s.BetID, s.SDTResourceId,s.RefResourceID,s.ResourceID, s.SDTpfId, ISNULL(s.OddsType,0), IIF(ResourceID IN ('00','01') AND s.SDTInstant IS NOT NULL,1,0)
		FROM	dbo.SettlementSpecialBettypeProfile AS s WITH(NOLOCK)
		WHERE	s.SportType = @SportType
			AND 1 = CASE WHEN @IsInstant = 0 AND ISNULL(s.DeterminedType,0) & @DeterminedType > 0 THEN 1
						 WHEN @IsInstant = 1 AND ISNULL(s.SDTInstant,0) & @DeterminedType > 0 THEN 1
						 ELSE 0
					END
			
		SELECT	@DummyResourceIds = STRING_AGG(CAST(tbl.SDTResourceId AS VARCHAR(MAX)), ',')
		FROM (SELECT DISTINCT SDTResourceId FROM @tmpSelectedRID) AS tbl
			
		EXEC dbo.NAP_Set_DummyResourceResult
			 @MatchID               = @MatchID
			,@SportType             = @SportType
			,@IsDetermined          = 1
			,@WebResourceResult     = @SelectedResources
			,@DummyResourceIds      = @DummyResourceIds
			,@DummyResourceResults  = @DummyResourceResults OUTPUT

		EXEC sp_xml_preparedocument @Handle OUTPUT, @DummyResourceResults
		UPDATE bt
		SET  bt.HomeValue = tbl.Home
			,bt.AwayValue = tbl.Away
			,bt.isCalculated = tbl.isCal
			,bt.MinusValue = IIF(@IsInstant = 1 AND @SportType = 2, 6, 0)
		FROM @tmpSelectedRID AS bt
			INNER JOIN OPENXML(@Handle,'root/r',1) WITH( Id VARCHAR(20),Home VARCHAR(2000),Away VARCHAR(2000),isCal BIT) AS tbl ON tbl.Id = bt.SDTResourceId
		EXEC sp_xml_removedocument @Handle

		SELECT TOP 1 @HTDone = isCalculated
		FROM @tmpSelectedRID
		WHERE SDTResourceId  = '01'

		SELECT TOP 1 @FTDone = isCalculated
		FROM @tmpSelectedRID
		WHERE SDTResourceId  = '00'

		UPDATE @tmpSelectedRID
		SET isCalculated = IIF(RefResourceID = '00',@FTDone,@HTDone)
		WHERE RefResourceID  IN ('00','01')

		SELECT	 @fthSDT = ISNULL(SUM(CASE WHEN tbl.SDTResourceId = '00' THEN tbl.HomeValue ELSE 0 END), 0)
				,@ftaSDT = ISNULL(SUM(CASE WHEN tbl.SDTResourceId = '00' THEN tbl.AwayValue ELSE 0 END), 0)
				,@hthSDT = ISNULL(SUM(CASE WHEN tbl.SDTResourceId = '01' THEN tbl.HomeValue ELSE 0 END), 0)
				,@htaSDT = ISNULL(SUM(CASE WHEN tbl.SDTResourceId = '01' THEN tbl.AwayValue ELSE 0 END), 0)
		FROM (SELECT DISTINCT SDTResourceId,HomeValue,AwayValue
              FROM @tmpSelectedRID
              WHERE SDTResourceId IN ('01', '00')) AS tbl

	    INSERT INTO #tmpTransSDT(TransID, CustID, modds, OddsType, srecommend, bettype, IsMarked,BetdaqId, currentStatuswinlost,betteam,hdp1,IsInstHTFT)
	    SELECT	b.transid
	    	   ,b.CustID
	    	   ,m.modds
	    	   ,sr.OddsType
	    	   ,b.srecommend
	    	   ,b.bettype
	    	   ,CASE WHEN mt.TransId IS NOT NULL THEN 1 ELSE 0 END AS IsMarked
			   ,ISNULL(b.betdaqid,0)
			   ,b.statuswinlost
			   ,b.betteam
			   ,b.hdp1
			   ,sr.IsInstHTFT
	    FROM bettrans AS b WITH (NOLOCK)
	    	OUTER APPLY (
	    					SELECT TOP (1) t.TransId
	    					FROM	dbo.MarkedTransaction AS t WITH(NOLOCK)
	    					WHERE	t.TransId = b.transId
	    	) AS mt
	    	CROSS APPLY(
	    					SELECT TOP 1 t.SDTpfId, t.HomeValue,t. AwayValue, t.OddsType, t.isCalculated, t.MinusValue, t.IsInstHTFT
	    					FROM @tmpSelectedRID AS t
	    					WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
	    				) AS sr
	    	CROSS APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, b.betteam, b.hdp1, sr.HomeValue, sr.AwayValue, b.transdesc,sr.MinusValue) AS m
	    WHERE b.matchid = @MatchId
	    	AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			AND b.statusID NOT IN (1,101)
			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND ISNULL(b.betdaqid,0) = -2 AND ISNULL(b.statuswinlost,'') = ''  AND m.modds IS NOT NULL THEN 1
						 WHEN @IsReSettledTickets = 1 AND ISNULL(b.betdaqid,0) = -2 AND ISNULL(b.statuswinlost,'') != '' AND m.modds IS NULL  AND sr.isCalculated = 0 THEN 1
						 WHEN @IsReSettledTickets = 0 AND b.statusID IN (0,102) AND m.modds IS NOT NULL THEN 1
						 WHEN @IsReSettledTickets = 1 AND m.modds IS NOT NULL THEN 1
						 WHEN @IsReSettledTickets = 1 AND m.modds IS NULL AND (b.statusID IN (111,112,113) OR  ISNULL(b.statuswinlost,'') != '') AND sr.isCalculated = 0 THEN 1
						 ELSE 0
					END
		
		IF @Action = 'CAL' AND @IsReSettledTickets = 1 AND EXISTS (SELECT TOP 1 1 FROM #tmpTransSDT WHERE modds IS NULL AND IsInstHTFT = 1)
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoInstantOS_LastResultSel 
				  @MatchId	= @matchid 
				 ,@HTHome	= @HTHome_Inst OUTPUT
				 ,@HTAway	= @HTAway_Inst OUTPUT
				 ,@FTHome	= @FTHome_Inst OUTPUT
				 ,@FTAway	= @FTAway_Inst OUTPUT

			IF @HTHome_Inst IS NOT NULL OR @HTAway_Inst IS NOT NULL OR @FTHome_Inst IS NOT NULL OR @FTAway_Inst IS NOT NULL
			BEGIN
				DELETE b
				FROM #tmpTransSDT AS b
					CROSS APPLY(
	    						SELECT TOP 1 
									   t.SDTpfId
									  ,CAST((IIF(ResourceID = '00', ISNULL(@FTHome_Inst,0), ISNULL(@HTHome_Inst,0)) +  CAST(t.HomeValue  AS INT)) AS VARCHAR(2000)) AS HomeValue
									  ,CAST((IIF(ResourceID = '00', ISNULL(@FTAway_Inst,0), ISNULL(@HTAway_Inst,0)) +  CAST(t.AwayValue  AS INT)) AS VARCHAR(2000)) AS AwayValue
									  ,6 AS MinusValue
	    						FROM @tmpSelectedRID AS t
	    						WHERE b.BetType = t.BetType AND t.BetID = 0
	    					) AS sr
					CROSS APPLY dbo.f_Set_SDT_OS_modds(sr.SDTpfId, b.betteam, b.hdp1, sr.HomeValue, sr.AwayValue, NULL,sr.MinusValue) AS m
				WHERE b.modds IS NULL 
					AND b.IsInstHTFT = 1
					AND m.modds IS NOT NULL
			END
		END

		DELETE 
		FROM #tmpTransSDT
		OUTPUT deleted.TransID
			  ,deleted.modds
			  ,CASE WHEN deleted.modds > 0.25	THEN 2
				    WHEN deleted.modds = 0.25	THEN 1
				    WHEN deleted.modds = 0		THEN 0
				    WHEN deleted.modds = -0.25	THEN 3
					WHEN deleted.modds IS NULL	THEN NULL
				    ELSE 4
			   END
			  ,deleted.currentStatuswinlost
		INTO @tmpCashoutTransId(TransId,modds, statuswinlost, currentstatuswinlost)
		WHERE BetdaqId = -2

	    WHILE 1=1
	    BEGIN
	    	DELETE @tmpTransIDBatch
	    
	    	DELETE TOP(@BatchNo) t
	    	OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.srecommend, deleted.bettype, deleted.IsMarked
	    	INTO @tmpTransIDBatch(TransID, modds, OddsType, srecommend, bettype, IsMarked)
	    	FROM #tmpTransSDT AS t 

	    	SELECT @BatchCount 	= @@ROWCOUNT
	    		  ,@ticketCount	+= @BatchCount
	    
	    	IF @BatchCount = 0 BREAK

	    	--filter selectedRID by current Profile and BetType
	    	SET @StrTransIds = (SELECT transid		AS '@t'
	    					 		  ,modds		AS '@m'
	    					 		  ,OddsType		AS '@ot'
	    					 		  ,srecommend	AS '@sr'
	    					 		  ,bettype		AS '@bt'
	    					 		  ,IsMarked		AS '@im'
	    					    FROM @tmpTransIDBatch
							    WHERE modds IS NOT NULL
	    					    FOR XML PATH('r'), ROOT( 'root' ))

	    	EXEC dbo.NAP_Admin_Calculate_Main
	    		@MatchId	  		 = @MatchId
	    	   ,@Action				 = 'CAL'
	    	   ,@ActionID			 = @ActionID
	    	   ,@IsSettingByProfile  = 1
	    	   ,@StrTransIds		 = @StrTransIds
	    	   ,@IsCalculateBalance	 = 1
	    	   ,@ErrCode			 = @ErrCode OUTPUT
	    	   ,@ErrMessage			 = @ErrMsg OUTPUT

			IF @IsReSettledTickets = 1 
			BEGIN
				SET @StrUndoTransIds = (SELECT transid AS '@t' FROM @tmpTransIDBatch WHERE modds IS NULL FOR XML PATH('r'), ROOT( 'root' ))
				IF ISNULL(@StrUndoTransIds, '') != ''
				BEGIN
					EXEC dbo.NAP_Admin_Calculate_Main
	    				@MatchId	  		 = @MatchId
	    			   ,@Action				 = 'UNDO'
	    			   ,@ActionID			 = 103
	    			   ,@IsSettingByProfile  = 1
	    			   ,@StrTransIds		 = @StrUndoTransIds
	    			   ,@IsCalculateBalance	 = 1
	    			   ,@ErrCode			 = @ErrCode OUTPUT
	    			   ,@ErrMessage			 = @ErrMsg OUTPUT
				END
			END

	    	IF @ErrCode > 0 
	    	BEGIN
	    		EXEC dbo.NAP_Admin_CheckingProcess   
	    				@isExistMatch		= 1
	    				,@IsReleased		= 1
	    		RETURN
	    	END
	    END

		IF @sportType = 2 AND EXISTS (SELECT TOP 1 1 FROM @tmpCashoutTransId)
		BEGIN
			UPDATE t 
			SET winlost = c.Winlost
			FROM	@tmpCashoutTransId t
				INNER JOIN dbo.CashOutSelling c WITH(NOLOCK) ON t.TransId = c.TransID

			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
				SET @strTransIds = ''

				DELETE 	TOP (2000)
				FROM @tmpCashoutTransId
				OUTPUT deleted.TransId, deleted.modds, deleted.statuswinlost, deleted.winlost INTO @tmpTransIDBatch(TransID,modds, statuswinlost, winlost)

				IF @@ROWCOUNT = 0 BREAK

				SET @strTransIds = (SELECT transid	AS '@t'
										  ,winlost	AS '@w'	
										  ,statuswinlost AS '@s'
									FROM @tmpTransIDBatch
									WHERE modds IS NOT NULL
									FOR XML PATH('r'), ROOT( 'root' ))

				IF ISNULL(@strTransIds, '') != '' 
				BEGIN
					EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		 = @matchid
					   ,@action				 = 'CAL'
					   ,@ActionID			 = @ActionID
					   ,@mode				 = 'CAL'
					   ,@IsSettingByProfile  = 1
					   ,@sportType			 = @sportType
					   ,@CashoutVersion		 = 2 
					   ,@strTransIds		 = @strTransIds
					   ,@IsCalculateBalance	 = 1
					   ,@ErrCode			 = @ErrCode OUTPUT
					   ,@ErrMessage			 = @ErrMsg OUTPUT
				END

				IF @IsReSettledTickets = 1 
				BEGIN
					SET @StrUndoTransIds = (SELECT transid	AS '@t'
												  ,winlost	AS '@w'	
												  ,statuswinlost AS '@s'
											FROM @tmpTransIDBatch
											WHERE modds IS NULL
											FOR XML PATH('r'), ROOT( 'root' ))

					IF ISNULL(@StrUndoTransIds, '') != ''
					BEGIN
						EXEC dbo.NAP_Admin_Calculate_Main
							@matchid	  		 = @matchid
						   ,@action				 = 'CAL'
						   ,@ActionID			 = @ActionID
						   ,@mode				 = 'UNDO'
						   ,@IsSettingByProfile  = 1
						   ,@sportType			 = @sportType
						   ,@CashoutVersion		 = 2 
						   ,@strTransIds		 = @StrUndoTransIds
						   ,@IsCalculateBalance	 = 1
						   ,@ErrCode			 = @ErrCode OUTPUT
						   ,@ErrMessage			 = @ErrMsg OUTPUT
					END
				END

				IF @ErrCode > 0 
				BEGIN
					EXEC dbo.NAP_Admin_CheckingProcess   
							 @isExistMatch		= 1
							,@IsReleased		= 1
					RETURN
				END
			END	
		END	

    END TRY
    BEGIN CATCH
		SELECT   @ErrMsg =  ERROR_MESSAGE() 
				,@ErrCode = ERROR_NUMBER()

		EXEC dbo.NAP_Admin_CheckingProcess
				  @isExistMatch		= 1
				  , @IsReleased		= 1

	    RETURN
    END CATCH

	EXEC dbo.NAP_Admin_CheckingProcess
			@isExistMatch	= 1
		   ,@IsReleased		= 1

	SELECT @Stop = CURRENT_TIMESTAMP

	IF @SportType = 2 AND (@DeterminedType & 8 = 8 OR  @DeterminedType & 16 = 16) AND @DeterminedType & 1 = 0
	BEGIN
		SET @RemarkSDT = @RemarkSDT + 'SDT_HT(' + CAST(@hthSDT AS VARCHAR(50)) + '-' + CAST(@htaSDT AS VARCHAR(50)) + '), '
	END

	SET @RemarkSDT = @RemarkSDT + 'SDT_FT(' + CAST(@fthSDT AS VARCHAR(50)) + '-' + CAST(@ftaSDT AS VARCHAR(50)) + ')'

	
	BEGIN
		IF @IsInstant = 1
		BEGIN
			EXEC DBPRO.bodb02.dbo.NAP_Set_AutoPayoutResultOS_Update 
				 @MatchId 			= @matchid
				,@SelectedResources = @SelectedResources
				,@StatusId 			= 2
				,@UserId			= @AdminId
				,@SourceID			= 98
		END

		SELECT @Selected = STRING_AGG (SDTResourceId + '(' + HomeValue + '-' + AwayValue  + ')',', ')
		FROM @tmpResources
		WHERE	HomeValue != ''
            AND AwayValue != ''

		SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())
		SELECT @Remark = '<distinct>'
							+ CASE WHEN ISNULL(@Selected,'') <> '' THEN '<r n="Selected" v="' + @Selected + '"/>' ELSE '' END
							+ CASE WHEN ISNULL(@RemarkSDT,'') <> '' THEN  '<r n="SDT" v="' + @RemarkSDT + '"/>' ELSE '' END
						+ '</distinct>'
						+ '<root>'
							+ '<r t="n" n="SiteDB" v="' + CAST(ISNULL(@SiteDBGroupId, 0) AS VARCHAR)  + '"/>'
							+ '<r t="dmin" n="StartTime" v="' + CONVERT(VARCHAR, @start, 120)  + '"/>'			
							+ '<r t="dmax" n="EndTime" v="' + CONVERT(VARCHAR, GETDATE(), 120) + '"/>'	
							+ '<r t="s" n="TC" v="' + CAST(ISNULL(@ticketCount, 0) AS VARCHAR(20))  + '"/>'							
						+ '</root>'

		EXEC bodb_CustomerLog.dbo.WriteLog_SSB_UserLog_Settle
				 @userid			= @AdminId
				,@matchid			= @MatchId
				,@actionid			= @ActionID
				,@finalhomescore	= @fth
				,@finalawayscore	= @fta
				,@hthomescore		= @hth
				,@htawayscore		= @hta
				,@Remark			= @Remark
				,@ip				= @IP
				,@BroadcastSessionId = @BroadcastSessionIdInstant	
		
	END

	INSERT INTO @tmpParlayAffectedBettypes(bettype, totalticket)
	SELECT 	bm.bettype, COUNT(1) AS totalticket
	FROM	dbo.bettransm AS bm WITH(NOLOCK)
	WHERE	bm.matchid = @MatchID		
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND 1 = CASE WHEN @IsReSettledTickets = 0 AND bm.statusID IN (0,102) THEN 1
						 WHEN @IsReSettledTickets = 1 THEN 1
						 ELSE 0
					END
			AND EXISTS (SELECT TOP 1 1 FROM @tmpSelectedRID t WHERE t.Bettype = bm.bettype)
	GROUP BY bm.bettype

	SELECT	@TotalSubParlay = SUM(totalticket)
	FROM	@tmpParlayAffectedBettypes

	IF @TotalSubParlay > 0
	BEGIN	
		SELECT @SelectedResourceParlay = CAST(( SELECT @Selected + '; SDT: ' + @RemarkSDT  AS '@RemarkSDT',  (SELECT SDTResourceID		AS '@Id'
																				 		    ,bettype			AS '@Bettype'
																						    ,SDTpfId			AS '@SDTpfId'
																						    ,HomeValue			AS '@Home'
																						    ,AwayValue			AS '@Away'
																							,isCalculated		AS '@IsCalculated'
																							,MinusValue			AS '@MinusValue'
																						    ,@DeterminedType	AS '@DeterminedType'																							
																					   FROM	@tmpSelectedRID AS s
																					   WHERE EXISTS (SELECT 1 FROM @tmpParlayAffectedBettypes AS p WHERE p.BetType = s.BetType)
																					   FOR XML PATH ('Resource'), TYPE)
												FOR XML PATH ('Resources')) AS VARCHAR(MAX))
	
		EXEC dbo.NAP_Set_GlobalSettingSel 
			 @LockName = 'ParlayRefno'
			,@ThreadHold = @ThresholdRefno OUTPUT

		IF @TotalSubParlay <= @ThresholdRefno
			SET @LockedByRefno = 1
		
		SET	@SqlCommand =  'EXEC [dbo].[NAP_Admin_Settlement_Profile_Parlay] @MatchID = ' + CONVERT(NVARCHAR(50), @MatchID) 
								+ ', @creator = ' + CONVERT(NVARCHAR(50), @AdminId) 												
								+ ', @SelectedResources = ''' + CONVERT(VARCHAR(MAX), @SelectedResourceParlay) + ''''
								+ ', @hth = ' + ISNULL(CONVERT(NVARCHAR(50), @hth),'NULL')
								+ ', @hta = ' + ISNULL(CONVERT(NVARCHAR(50), @hta),'NULL')
								+ ', @fth = ' + ISNULL(CONVERT(NVARCHAR(50), @fth),'NULL') 
								+ ', @fta = ' + ISNULL(CONVERT(NVARCHAR(50), @fta),'NULL')
								+ ', @IsReSettledTickets = ' + CONVERT(NVARCHAR(50), @IsReSettledTickets) 		
								+ ', @IsCentral = ' + CONVERT(VARCHAR(1), @IsCentral)
								+ ', @DeterminedType = ' + CONVERT(VARCHAR(50), @DeterminedType)
								+ ', @BroadcastSessionId = ''' + @BroadcastSessionIdInstant + ''''
								+ ', @Action = ''CAL'''
								+ ', @ErrCode = @ErrCode OUTPUT' 
								+ ', @ErrMsg = @ErrMsg OUTPUT'

		IF @SPName LIKE '%_xtest' OR @SPName LIKE '%_xpre' OR @SPName LIKE '%_UAT[1-9]'
		BEGIN
			EXEC dbo.NAP_Admin_Settlement_Profile_Parlay
				 @creator				= @AdminId
				,@MatchID				= @MatchID
				,@Action		  		= 'CAL'
				,@SelectedResources		= @SelectedResourceParlay
				,@hth					= @hth
				,@hta					= @hta
				,@fth					= @fth
				,@fta					= @fta
				,@IsReSettledTickets	= @IsReSettledTickets
				,@LockedByRefno			= 1 -- always lock refno for testing
				,@IsCentral				= @IsCentral
				,@DeterminedType        = @DeterminedType
				,@BroadcastSessionId 	= @BroadcastSessionIdInstant

				,@ErrCode				= @ErrCode OUTPUT
				,@ErrMsg 				= @ErrMsg OUTPUT
		END
		ELSE
		BEGIN
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, SQLCommand, Sporttype, LockedByRefno, BroadcastSessionId)
			SELECT @MatchID, 0, @AdminId, '', CURRENT_TIMESTAMP, 'SDT', @SqlCommand, @SportType, @LockedByRefno, @BroadcastSessionIdInstant
		END
	END
END
GO

GO
