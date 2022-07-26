/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_MP_Push] (
	@MatchIds 	VARCHAR(4000)
	,@AdminId 	INT
	,@Action 	VARCHAR(20) = 'CAL'
	,@IP 		VARCHAR(15) = ''
	,@ErrCode 	INT = 0 OUTPUT
	,@ErrMsg 	NVARCHAR(200) = '' OUTPUT
	)
AS
/*	Creator: 20140213@Kathy
	Task: Main SP for Mix parly settlement
	DB: DBTXN/BODB02
	ORIGINAL: Admin_Settlement_MP

	Revisions:		
		- 20140506@Kathy: Don't allow to calculate exists matches in queue
		- 20140512@Kathy: allow to execute undo action without score [Redmine:#14449]
		- 20141117@Jamie: Change ErrCode [Redmine:#23034]		
		- 20150401@Kathy: Add checking ticket status before performing settlement [Redmine:#33493]		
		- 20150922@Johnson: check result status from ResultDetail [Redmine: #43806]
		- 20151002@Kathy: add more UAT version for testing (UAT1,UAT2,UAT3,UAT4)
		- 20160429@Kathy: Enhance performance [Redmine:#52426]
		- 20160714@Kathy: Add checking SystemSettings before doing Parlay Settlement on UAT
		- 20160801@Patrick: Auto Payout - User can cal MP before calculating FT FGLG [Redmine: #61767]
		- 20161125@Bobby: #67822 - check single and parlay ticket for AUTO bet types
		- 20170313@Kathy: Check betstatus result for bettype 14,127 to notify user do CAL FGLG [Redmine:#73218]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170609@Kathy: Early settlement for BAIO [Redmine:#77835]
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171204@Kathy: Allow to settle parlay in case Early Settled bettypes have only Single tickets [Redmine:#87544]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20190517@Sol: Tuning performance [Redmine:#112904]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190725@Sol: Incorporate PHAIO 4b - Implement [ResourceID] = '09' to Settle PH4B Bet Types [Redmine:#115232]
		- 20190924@Sol: Incorporate BMAIO - modified sp to support ResultDetailOS [Redmine:#120324]
		- 20200115@Max: Enhance SPs [Redmine: #127031]
		- 20200318@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20201111@Louisa: Prevent process if SettlementStatus turn on bit 1,2,3,5,7 [Redmine:#143441]
		- 20210203@Louisa: Cricket AIO [Redmine:#148870]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220509@Kathy: Change to use STRING_SPLIT on DBPRO [Redmine:#172461]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:		
		
*/
SET NOCOUNT ON

BEGIN
	DECLARE  @NotKeyScoreList VARCHAR(130) = ''
			,@NotAllowCalculating VARCHAR(200)
			,@HaveWaitingTicket VARCHAR(200)
			,@NotExecutedFGLG VARCHAR(200)
			,@procName nvarchar(50)	
			,@matchid int
			,@matchcode nvarchar(50)

			,@MovingMatchIds VARCHAR(MAX) 
			,@InvalidMatchIds VARCHAR(MAX) = ''
			--,@IsExistsResourceEarlyRunning BIT = 0
			,@HoldSettingMatchIds VARCHAR(200) = ''
			,@ParentIds VARCHAR(MAX) = ''
			
	DECLARE @subErrCode		INT
			,@subErrMsg		NVARCHAR(200)
		
	DECLARE @tblBettype TABLE ( matchid INT
						  ,Sporttype SMALLINT
						  ,Bettype SMALLINT
						  ,Betcheck NVARCHAR(50)
						  ,ResourceID VARCHAR(20)
						 )
						 
	Create table #Match (matchid INT
						  ,matchcode NVARCHAR(50)
						  ,fth SMALLINT
						  ,fta SMALLINT
						  ,hth SMALLINT
						  ,hta SMALLINT
						  ,sporttype SMALLINT
						  ,SettlementStatus	TINYINT
						  ,ParentId INT )

	CREATE TABLE #ResultDetail (MatchId INT, ResourceId VARCHAR(20), ResultStatusId TINYINT, SettlementStatusId TINYINT)
	CREATE TABLE #ResultDetailES (MatchId INT, ResourceId VARCHAR(20), ResultStatusId TINYINT, SettlementStatusId TINYINT)
	CREATE TABLE #ResultDetailOS (MatchId INT, ResourceId VARCHAR(20), ResultStatusId TINYINT, SettlementStatusId TINYINT)
	
	SELECT	 @ErrCode = 0
			,@ErrMsg = ''
			,@procName = OBJECT_NAME(@@procid)
			,@subErrCode = 0
			,@subErrMsg = ''
			
	-- get data from remote table match
	DECLARE @queryMatch NVARCHAR(MAX) = '', @queryResultDetail NVARCHAR(MAX) = '', @queryResultDetailES NVARCHAR(MAX) = '', @queryResultDetailOS NVARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''

	SET @queryMatch = '	SELECT matchid
								,matchcode
								,finalhomescore
								,finalawayscore
								,hthomescore
								,htawayscore
								,sporttype
								,ISNULL(SettlementStatus,0) SettlementStatus
								,CASE WHEN ISNULL(ChildMatchType,0) = 200 AND m.ParentId IS NOT NULL AND m.sporttype = 50 THEN m.ParentId ELSE m.MatchId END ParentId
						FROM BODB02.dbo.Match m WITH (NOLOCK)
								INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , '','')) tm
									ON m.matchid = tm.value		
					'

	SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryMatch, N''@MatchIds VARCHAR(4000)'' , @matchids'

	INSERT INTO #Match ( matchid, matchcode, fth, fta, hth, hta, sporttype, SettlementStatus, ParentId)
	EXECUTE	sys.sp_executesql @execSql, N'@queryMatch NVARCHAR(MAX), @MatchIds VARCHAR(4000)', @queryMatch, @matchids
	-- end

	SELECT @ParentIds =  COALESCE(@ParentIds + ',' + CAST(m.ParentId AS varchar),  CAST(ParentId AS varchar)) from #Match m 	
	SELECT @ParentIds = STUFF(@ParentIds, 1, 1, '')

	IF EXISTS (SELECT TOP(1) 1 FROM #Match m WHERE m.sporttype NOT IN (9, 43, 45, 50))
	BEGIN
		-- get date from remote ResultDetail table 
		SET @queryResultDetail = '	SELECT MatchId, ResourceId, ResultStatusId, SettlementStatusId
									FROM BODB02.dbo.ResultDetail r WITH (NOLOCK)
											INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , '','')) tm
												ON r.matchid = tm.value'

		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryResultDetail, N''@MatchIds VARCHAR(4000)'' , @matchids'
		
		INSERT INTO #ResultDetail (MatchId, ResourceId, ResultStatusId, SettlementStatusId)
		EXECUTE	sys.sp_executesql @execSql, N'@queryResultDetail NVARCHAR(MAX), @MatchIds VARCHAR(4000)', @queryResultDetail, @matchids
		-- end
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Match m WHERE m.sporttype IN (43))
	BEGIN
		-- get date from remote ResultDetailES table 
		SET @queryResultDetailES = '	SELECT MatchId, ResourceId, ResultStatusId, SettlementStatusId
										FROM BODB02.dbo.ResultDetailES r WITH (NOLOCK)
												INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , '','')) tm
													ON r.matchid = tm.value
									'

		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryResultDetailES, N''@MatchIds VARCHAR(4000)'' , @matchids'

		INSERT INTO #ResultDetailES (MatchId, ResourceId, ResultStatusId, SettlementStatusId)
		EXECUTE	sys.sp_executesql @execSql, N'@queryResultDetailES NVARCHAR(MAX), @MatchIds VARCHAR(4000)', @queryResultDetailES, @matchids
		-- end
	END

	IF EXISTS (SELECT TOP(1) 1 FROM #Match m WHERE m.sporttype IN (9, 45, 50))
	BEGIN
		-- get date from remote ResultDetailOS table 
		SET @queryResultDetailOS = '	SELECT MatchId, ResourceId, ResultStatusId, SettlementStatusId
										FROM BODB02.dbo.ResultDetailOS r WITH (NOLOCK)
												INNER JOIN (SELECT value FROM STRING_SPLIT(@ParentIds , '','')) tm
													ON r.matchid = tm.value
									'

		SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryResultDetailOS, N''@ParentIds VARCHAR(4000)'' , @ParentIds'

		INSERT INTO #ResultDetailOS (MatchId, ResourceId, ResultStatusId, SettlementStatusId)
		EXECUTE	sys.sp_executesql @execSql, N'@queryResultDetailOS NVARCHAR(MAX), @ParentIds VARCHAR(4000)', @queryResultDetailOS, @ParentIds
		-- end
	END
	
	DECLARE @tblFGLGMatch TABLE(matchid INT, matchcode NVARCHAR(50))
	DECLARE @tmpRunningEarlySettle TABLE (matchid INT)
	DECLARE @tblRunningBAIO TABLE (matchid INT, QuarterX NVARCHAR(50), OrdNo SMALLINT)

	DECLARE @tmpBettypes TABLE (bettype SMALLINT, groupId INT, groupname VARCHAR(50), isEarly BIT)	
	DECLARE @tmpFGLGBettypes TABLE (bettype SMALLINT PRIMARY KEY, groupId INT)
	
	INSERT INTO @tmpBettypes(bettype, groupId, groupname, isEarly)
	SELECT	f.BetType, f.GroupId, f.GroupName
			,(SELECT 1 FROM dbo.f_Set_GetEarlyBettypes() WHERE bettype = f.BetType) AS isEarly
	FROM	dbo.f_Set_GetGroupBettypes() f 
	
	INSERT INTO @tmpFGLGBettypes(bettype, groupId)
	SELECT	f.BetType, f.GroupId
	FROM	dbo.f_Set_GetGroupBettypes() f
	WHERE	f.IsUsedGoalRecordValue = 1
	
	IF EXISTS (SELECT TOP 1 1 FROM #Match WHERE sporttype = 1)
	BEGIN
		;WITH cteBetStatusM
		AS(
			SELECT	DISTINCT matchid
					,s.ResourceId						
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
					ON	s.BetType = bm.bettype
						AND (s.BetID = 0 OR s.BetID = bm.betcheck)
			WHERE	matchid IN (SELECT matchid FROM #Match)
					AND s.SettleType = 'EAR'
					AND statusID = 0
		)
		
		INSERT INTO @tmpRunningEarlySettle (matchid)
		SELECT	c.matchid
		FROM	cteBetStatusM c
			LEFT JOIN #ResultDetail r WITH(NOLOCK)	
				ON	c.matchid = r.matchid 
					AND r.ResourceId = c.ResourceId
		WHERE	ISNULL(r.ResultStatusId,0) NOT IN (2,5)
		GROUP BY c.matchid
		
		;WITH cteFGLGBettypes
		AS(
			SELECT	bm.matchid
					,m.matchcode
					,CASE 
						WHEN bm.bettype = 448 THEN '14L'
						WHEN bm.bettype IN (415,454,172) THEN '14F'
						WHEN bm.bettype IN (14, 127) 
							THEN CAST(bm.bettype AS VARCHAR) 
									+ CASE 
										WHEN RIGHT(bm.betteam,1) IN ('0', '1') THEN 'F'
										WHEN RIGHT(bm.betteam,1) = '2' THEN 'L'
										ELSE ''
									END 
						WHEN bt.groupId = 1 THEN '09'
						ELSE '08'
					END AS ResourceId
			FROM	dbo.bettransm bm WITH(NOLOCK)
				INNER JOIN #Match m
					ON m.matchid = bm.matchid
				INNER JOIN @tmpFGLGBettypes bt
					ON bm.bettype = bt.bettype
			WHERE	bm.statusID NOT BETWEEN 101 AND 102
			GROUP BY bm.matchid
					,m.matchcode
					,CASE 
						WHEN bm.bettype = 448 THEN '14L'
						WHEN bm.bettype IN (415,454,172) THEN '14F'
						WHEN bm.bettype IN (14, 127) 
							THEN CAST(bm.bettype AS VARCHAR) 
									+ CASE 
										WHEN RIGHT(bm.betteam,1) IN ('0', '1') THEN 'F'
										WHEN RIGHT(bm.betteam,1) = '2' THEN 'L'
										ELSE ''
									END 
						WHEN bt.groupId = 1 THEN '09'
						ELSE '08'
					END
		)
		INSERT INTO @tblFGLGMatch(matchid, matchcode)
		SELECT	c.matchid, c.matchcode
		FROM	cteFGLGBettypes c
			LEFT JOIN #ResultDetail r WITH(NOLOCK)
				ON	c.matchid = r.matchid
					AND c.ResourceId = r.ResourceId
		WHERE ISNULL(r.SettlementStatusId,0) <> 4
		GROUP BY c.matchid, c.matchcode			
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM #Match m CROSS APPLY dbo.f_Set_SettingByProfile(m.sporttype))
	BEGIN
		
		;WITH cteBetstatus
		AS(
			SELECT	bm.matchid
					,m.ParentId
					,bm.bettype
					,bm.betcheck
					,m.sporttype
			FROM	#Match m
				INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.matchid = bm.matchid
			WHERE bm.statusID = 0
			GROUP BY bm.matchid, bm.bettype, bm.betcheck,m.sporttype, m.ParentId
		)
		,cteResourceID
		AS(
			SELECT c.sporttype
					,c.matchid
					,c.ParentId
					,CASE 
						WHEN f.ResourceID = '70400' THEN '00'
						WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
						ELSE f.ResourceID 
					END AS ResourceID
					,f.SettleType
					,MAX(f.OrdNo) AS OrdNo
			FROM	cteBetstatus c
				INNER JOIN	dbo.SettlementSpecialBettypeProfile f WITH(NOLOCK) ON f.sporttype = c.sporttype AND c.bettype = f.BetType
			WHERE (f.Betid = 0 OR CAST(f.Betid AS NVARCHAR(50)) = c.Betcheck)
			GROUP BY c.sporttype, c.matchid, c.ParentId
					,CASE 
						WHEN f.ResourceID = '70400' THEN '00' 
						WHEN f.RefResourceId IS NOT NULL THEN f.RefResourceId
						ELSE f.ResourceID 
					END
					,f.SettleType
		)
			
		INSERT INTO @tblRunningBAIO (matchid, QuarterX, OrdNo)
		SELECT	c.matchid, COALESCE(sd.RoundName, 'Early Settle'), MAX(c.OrdNo)
		FROM	cteResourceID c
			OUTER APPLY(
	  			SELECT ResultStatusID
	  			FROM #ResultDetailES rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.matchid
				UNION ALL
				SELECT ResultStatusID
	  			FROM #ResultDetailOS rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.ParentId
				UNION ALL
				SELECT ResultStatusID
	  			FROM #ResultDetail rd WITH (NOLOCK) 
	  			WHERE rd.ResourceID = c.ResourceID
	  				AND rd.matchid = c.matchid
	  		) AS rs
			OUTER APPLY
			(
				SELECT RoundName FROM dbo.f_Set_MajorRound(c.sporttype)
				WHERE c.ResourceID = ResourceID
			) sd 
		WHERE ISNULL(rs.ResultStatusId,0) NOT IN ( 2, 5 )
		GROUP BY c.matchid, sd.RoundName--,c.OrdNo
		--ORDER BY c.OrdNo

	END
	
	SELECT @HoldSettingMatchIds = COALESCE(@HoldSettingMatchIds + ',' + m.matchcode, m.matchcode)
	FROM	#Match m
	WHERE m.SettlementStatus & 87 > 0

	DELETE FROM #Match
	WHERE	SettlementStatus & 87 > 0

	IF EXISTS (SELECT 1
				FROM #Match
				WHERE  MatchId = ParentId AND (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL) ) AND @action <> 'UNDO'
		OR EXISTS (SELECT TOP 1 1 FROM @tmpRunningEarlySettle)	
		OR EXISTS (SELECT TOP 1 1
					FROM @tblRunningBAIO
				)					
	BEGIN
		
		SELECT @NotKeyScoreList = @NotKeyScoreList + matchcode + ','									
		FROM #Match
		WHERE fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL
			
		-- exclude matches were not keyscore yet
		DELETE
		FROM #Match
		WHERE (MatchId = ParentId AND (fth IS NULL OR fta IS NULL OR hth IS NULL OR hta IS NULL))
			

		SELECT @NotKeyScoreList = @NotKeyScoreList + m.matchcode + '(Early Settle)' + ','
		FROM #Match m
			INNER JOIN @tmpRunningEarlySettle t
				ON m.matchid = t.matchid

		DELETE m 
		FROM #Match m
			INNER JOIN @tmpRunningEarlySettle t
				ON m.matchid = t.matchid

		SELECT @NotKeyScoreList = @NotKeyScoreList 
								+ m.matchcode +  '(' + STUFF((SELECT ',' + QuarterX 
												FROM @tblRunningBAIO 
												WHERE m.matchid = matchid 
												ORDER BY OrdNo
												FOR XML PATH('')),1,1,'') + ')' 
								+ ',' 
						
		FROM #Match m
			INNER JOIN @tblRunningBAIO t
				ON	m.matchid = t.matchid		
		GROUP BY m.matchid, m.matchcode
		
		IF RIGHT(@NotKeyScoreList,1) = ','
			SET @NotKeyScoreList = LEFT(@NotKeyScoreList,LEN(@NotKeyScoreList)-1)
			
		DELETE m
		FROM #Match m
		WHERE EXISTS (SELECT TOP 1 1 FROM @tblRunningBAIO WHERE matchid = m.matchid)
		
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @tblFGLGMatch)
	BEGIN
		SELECT @NotExecutedFGLG = COALESCE(@NotExecutedFGLG + ',' + matchcode, matchcode)
		FROM @tblFGLGMatch
		
		DELETE 
		FROM	#Match
		WHERE	matchid IN (SELECT matchid FROM @tblFGLGMatch)
	END	
	
	IF EXISTS (SELECT 1
				FROM #Match
				WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1))
				OR matchid IN (SELECT matchid from Parlay_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1)) )
	BEGIN
		SELECT @NotAllowCalculating = COALESCE(@NotAllowCalculating + ',' + matchcode, matchcode)
		FROM #Match 
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 

		-- exclude matches were not allow to calculate
		DELETE
		FROM #Match
		WHERE matchid IN (SELECT matchid from Single_Calculate_Queue with(NOLOCK) where IsCalculating IN (0,1) )
		OR matchid IN (SELECT matchid FROM Parlay_Calculate_Queue with(NOLOCK) WHERE IsCalculating IN (0,1) ) 
	END

	-- check movebet day
	EXEC dbo.NAP_Admin_Settlement_CheckingMoveBetDay
		@MatchIds =  @matchids 
		,@MovingMatchIds = @InvalidMatchIds OUTPUT
	
	SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' + m.matchcode, m.matchcode)
	FROM	dbo.match m WITH(NOLOCK)
				INNER JOIN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ',')) tm
					ON m.matchid = tm.value 
	
	DELETE FROM #Match
	WHERE	matchid IN (SELECT [value] FROM STRING_SPLIT(@InvalidMatchIds, ','))

	-- check waiting ticket
	EXEC [NAP_Admin_Settlement_Checking] 		@MatchIds = @MatchIds	OUTPUT
		,@Action = @Action
		,@Mode = 'CAL-MP'	
	
	SELECT @HaveWaitingTicket = COALESCE(@HaveWaitingTicket + ',' + m.matchcode, m.matchcode)
	FROM dbo.match m WITH(NOLOCK)
			INNER JOIN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ',')) tm
				ON m.matchid = tm.value
	
	DELETE FROM #Match
	WHERE matchid IN (SELECT [value] FROM STRING_SPLIT(@MatchIds, ','))
	
	IF (ISNULL(@HoldSettingMatchIds,'') <> '' OR ISNULL(@NotKeyScoreList,'') <> '' or ISNULL(@NotAllowCalculating,'') <> '' OR ISNULL(@HaveWaitingTicket,'') <> '') OR ISNULL(@NotExecutedFGLG,'') <> '' OR ISNULL(@MovingMatchIds,'') <> ''
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg = 'All matches are being calculated, except following matches ' 
							+ CASE WHEN ISNULL(@HoldSettingMatchIds, '') <> ''
									THEN '(on hold): ' + STUFF(@HoldSettingMatchIds, 1, 1, '')
									ELSE ''
								END
							+ CASE WHEN ISNULL(@NotKeyScoreList, '') <> '' 
									THEN  '(not keyed in score yet): ' + @NotKeyScoreList 
									ELSE ''
								END
							+ CASE when ISNULL(@NotAllowCalculating,'') <> ''
									THEN  ' (being calculated by another user): ' + @NotAllowCalculating
									ELSE ''
								END 
							+ CASE WHEN ISNULL(@HaveWaitingTicket, '') <> ''
									THEN ' (existing some PENDING tickets): ' + @HaveWaitingTicket
									ELSE ''
								END
							+ CASE WHEN ISNULL(@NotExecutedFGLG, '') <> ''
									THEN ' (need to be executed "Calc FGLG"): ' + @NotExecutedFGLG
									ELSE ''
								END				
							+ CASE WHEN ISNULL(@MovingMatchIds, '') <> ''
									THEN ' (during move-bet progress): ' + @MovingMatchIds + '. Please contact Starix IT for further support!'
									ELSE ''
								END

							
	END
	
	IF EXISTS (
				SELECT TOP 1 1
				FROM #Match
				)
	BEGIN
		IF @procName LIKE '%_xtest' or @procName LIKE '%_xpre' OR @procName LIKE '%_UAT_' -- UAT1 -->UAT9
		BEGIN

			WHILE(1 = 1)
			BEGIN
				SELECT TOP 1 @matchid = matchid
						,@matchcode = matchcode
				FROM #Match

				IF @@ROWCOUNT = 0
					BREAK
				
				IF EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WHERE VName = 'isCalculatingParlay' AND VValue = '0')
					AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.ParlayLocking)
				BEGIN
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
							SET VValue = 1
					WHERE VName = 'isCalculatingParlay'
					
				END
				ELSE
				BEGIN
					SELECT	@ErrCode = 1000000
						,@ErrMsg = 'Another parlay settlement is in progress or some parlay tickets are being deleted, please wait a few seconds until the on-going process has finished and try again.'
					RETURN	
				END
				
				BEGIN TRY
					EXEC [NAP_Admin_Settlement_MP] @matchid = @matchid
						,@creator = @AdminId
						,@action  = @action
						,@IP      = @IP
						,@ErrCode = @subErrCode 	OUTPUT
						,@ErrMsg  = @subErrMsg   	OUTPUT
				END TRY
				BEGIN CATCH			
					UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
						SET VValue = 0
					WHERE VName = 'isCalculatingParlay'
				
					SELECT @ErrMsg  = @matchcode + ': ' + ISNULL(ERROR_MESSAGE(),'')
						  ,@ErrCode = @@error
					
					RETURN
				END CATCH
				
				IF @subErrCode > 0
					SELECT @ErrMsg = @ErrMsg + ' ' + @matchcode + ':' + @subErrMsg + ', '
				
				UPDATE dbo.SystemSettings WITH (ROWLOCK, UPDLOCK)
						SET VValue = 0
				WHERE VName = 'isCalculatingParlay'

				DELETE 
				FROM #Match
				WHERE matchid = @matchid
			END
			
		END
		ELSE
		BEGIN		
			INSERT INTO dbo.Parlay_Calculate_Queue (matchid, isCalculating, creator, ip, starttime, action, Sporttype)
			SELECT matchid, 0, @AdminId, @IP, CURRENT_TIMESTAMP, @action, sporttype
			FROM #Match
		END
	END
END
GO

