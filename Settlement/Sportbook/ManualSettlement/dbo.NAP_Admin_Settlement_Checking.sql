/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Checking] 
	  @MatchId 				INT = NULL
	, @MatchIds 			VARCHAR(4000) = NULL OUTPUT
	, @Action 				VARCHAR(10) = 'CAL'
	, @Mode 				VARCHAR(20) = 'CAL'
	, @xmlData				VARCHAR(MAX) = NULL
	, @IsAuto				BIT = 0
	, @ErrCode 				INT = 0 OUTPUT
	, @ErrMsg 				NVARCHAR(200)	= '' OUTPUT
AS
/*	Creator: Kathy
	Date: 2015-04-01
	Task: checking ticket status
	DB: DBTXN/BODB02

	Revisions:		
		- 20150415@Kathy: Apply new BetRadar bettypes [Redmine:#27212]
		- 20150605@Jamie: Correct checking for AUTO Bets 
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160315@Patrick: Auto payout [Redmine: #53262]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20170113@Kathy:  Enhancement for Fast Market [Redmine:#69951]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170522@Kathy: Correct checking waiting tickets for tennis [Redmine:#76931]
		- 20170609@Kathy: Basketball All-in-One Early Settlement [Redmine:#77835]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20181114@Helen:  Second Accept - Processing for Waiting Tickets [Redmine:104755]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190107@Kathy: set ticket running if it is accepted by both auto accept & second accept [Redmine:#107452]
		- 20190124@Sol: Second Accept Process of Parlay Tickets [Redmine #107296]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200928@Kathy: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20210107@Kathy: Support settle determined [Readmine:#147141]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20230215@Aries: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		
	Param's Explanation:
		
*/

BEGIN
	SET NOCOUNT ON

	IF  ( @Action LIKE 'REFUND%' AND @Mode ='MP' ) --refund parlay
		OR @Mode LIKE 'INST%'	---setle instant
		OR @Mode = 'BB'			----Betbuider
		OR @Action = 'MoveTicket'
	BEGIN
		RETURN
	END

	DECLARE @isExistWaitingTicket	BIT
		,@xml						XML
		,@currentdate				DATETIME
		,@Sporttype					SMALLINT
		,@handle					INT
		,@IsSettleDetermined		BIT
		,@IsCentral					BIT
    
	
	DECLARE	@tmpResourceIDs TABLE(
		ResourceID	VARCHAR(20)
		,Bettype	INT
		,BetID		BIGINT
	)

	SELECT @currentdate = CURRENT_TIMESTAMP
			,@isExistWaitingTicket = 0
			,@IsSettleDetermined = 0

    SELECT	@Sporttype = sporttype
    FROM	dbo.[match] WITH (NOLOCK)
    WHERE	matchid = @matchid

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	--cal/undo/refund FT/HT/Game/Set
	--cal early sports settle by profile except early soccer
	IF @Action IN ( 'CAL', 'CAL-HT', 'CAL-FT', 'UNDO', 'REFUND','CAL_EAR', 'UNDO_EAR', 'REFUND_EAR','REFUND-FT', 'UNDO-FT') AND @Mode <> 'FM'
	BEGIN	
		IF @xmlData IS NOT NULL
		BEGIN			
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT tbl.Id, sp.BetType, sp.BetID
		    FROM OPENXML(@handle,'Resources/Resource',1) WITH (Id VARCHAR(20)) AS tbl
		        INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.Id
		    WHERE sp.SportType = @SportType 
		    EXEC sp_xml_removedocument @handle
		
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT tbl.Id, sp.BetType, sp.BetID
		    FROM OPENXML(@handle,'Resources/Resource',1) WITH (Id VARCHAR(20)) AS tbl
		        INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.RefResourceId = tbl.Id
				LEFT JOIN @tmpResourceIDs r
					ON r.ResourceID = tbl.Id
						AND r.bettype = sp.bettype
		    WHERE sp.SportType = @SportType 
				AND sp.RefResourceId IS NOT NULL
				AND r.ResourceID IS NULL		
				
		    EXEC sp_xml_removedocument @handle
			
			IF EXISTS (SELECT TOP 1 1
					   FROM dbo.bettrans b WITH(NOLOCK)
					   WHERE b.matchid = @matchid
					   		AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate ))
							AND EXISTS (SELECT 1 
					   					FROM @tmpResourceIDs t
					   					WHERE t.Bettype = b.Bettype AND (t.BetID = 0 OR t.BetID = b.BetID)
					   					)
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					)
			BEGIN
				SELECT @isExistWaitingTicket = 1
			END 				
			ELSE IF EXISTS (SELECT TOP 1 1
					   FROM dbo.bettransm bm WITH(NOLOCK)
					   WHERE bm.matchid = @matchid
					   		AND (bm.statusID = 1 -- waiting status
								OR (bm.statusID = 0 AND bm.SecAcceptFlag=1 AND ISNULL(bm.checktime,@currentdate) > @currentdate ))
							AND EXISTS (SELECT 1 
					   					FROM @tmpResourceIDs t
					   					WHERE t.Bettype = bm.Bettype AND (t.BetID = 0 OR t.BetID = bm.betcheck)
					   					)
							AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					)
			BEGIN
				SELECT @isExistWaitingTicket = 1
			END
		END
		ELSE
		BEGIN
			IF EXISTS (SELECT TOP 1 1 
				FROM dbo.bettrans b WITH(NOLOCK)
					INNER JOIN dbo.f_Set_GetGroupBettypes() f
						ON b.bettype = f.BetType
				WHERE b.matchid = @matchid			
					AND (b.statusID = 1 -- waiting status
						OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
			
						AND f.IsAuto = 0
						AND ((@Action IN ('CAL', 'REFUND'))
							OR (@Action IN ('CAL-HT', 'REFUND-HT')
									AND f.GroupId IN (1,3) -- HT, HT FGLG						
								)
							OR (@Action IN ('CAL-FT', 'REFUND-FT') 
									AND f.GroupId NOT IN (1,3)
								) --exclude bettype [172] in case auto-payout
							)					
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			)
			BEGIN
				SELECT @isExistWaitingTicket = 1
			END
			ELSE IF EXISTS (SELECT TOP 1 1
							FROM dbo.bettransm bm WITH(NOLOCK)
							WHERE bm.matchid = @matchid
					   			AND (bm.statusID = 1 OR (bm.statusID = 0 AND bm.SecAcceptFlag=1 AND ISNULL(bm.checktime,@currentdate) > @currentdate ))
								AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END)
			BEGIN
				SELECT @isExistWaitingTicket = 1
			END

		END		
	END
	
	--refund betDaq
	ELSE IF @Action = 'BetDaq'
	BEGIN	
		IF EXISTS (SELECT TOP 1 1 
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
			WHERE	b.matchid = @matchid
					AND (b.statusID = 1 -- waiting status
						OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))					 
					AND f.GroupId BETWEEN 1 AND 7
					AND b.bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
					AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) 
						OR recommend = 1688156	)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
			SELECT @isExistWaitingTicket = 1
	END		
	
	--refund betfair
	ELSE IF @Action = 'BetFair'
	BEGIN
		IF EXISTS (SELECT TOP 1 1 
			FROM dbo.bettrans b WITH(NOLOCK)
				INNER JOIN dbo.f_Set_GetGroupBettypes() f
					ON b.bettype = f.BetType
			WHERE b.matchid = @matchid
			AND (b.statusID = 1 -- waiting status
						OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
			AND f.GroupId BETWEEN 1 AND 7
			AND b.bettype NOT BETWEEN 153 AND 156   -- New bettype of Tennis
			AND custid IN (2331, 1077687, 115770, 15523642)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
			SELECT @isExistWaitingTicket = 1
	END	

	ELSE IF @Mode = 'FM'
	BEGIN
		DECLARE @maxSelectedTotalGoal	INT = 0
				,@maxSelectedPosition	TINYINT = 0
				,@totalChangedScore		INT = 0
				,@ResultStatus			TINYINT 
				,@BetOption1st			VARCHAR(50) = ''
				,@BetOption2nd			VARCHAR(50) = ''
				,@ResultStatus1st		VARCHAR(50)	= ''		
				,@ResultStatus2nd		VARCHAR(50) = ''

		DECLARE @tblBettype TABLE (bettype SMALLINT, position TINYINT, BetOption TINYINT, AccumulatedScore INT, IsSettleDetermined BIT, HasInjuryTime BIT DEFAULT(0))

		DECLARE @tblResultDetail TABLE (
				ResourceId	VARCHAR(20)
				,HomeValue	VARCHAR(50)
				,AwayValue	VARCHAR(50)
			)
		DECLARE @tblPosition TABLE(
				ResourceId	VARCHAR(20)
				,strPosHome	VARCHAR(1000)
				,strPosAway VARCHAR(1000)
			)
		DECLARE @tblAccumulatedScore TABLE (
				Position TINYINT
				,BetOption TINYINT
				,AccumulatedScore INT
			)
		
		SET @xml = CONVERT(XML,@xmlData)

		INSERT INTO @tblBettype (bettype, position, BetOption, IsSettleDetermined, HasInjuryTime)
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@p','TINYINT') as Position
			,X.C.value('@r','TINYINT') as BetOption
			,X.C.value('@s','BIT') as IsSettleDetermined
			,ISNULL(X.C.value('@i','BIT'),0) as HasInjuryTime
		FROM @xml.nodes('/r/b') AS T(C)
			CROSS APPLY
				C.nodes('r') AS X(C)
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

		IF EXISTS (SELECT TOP 1 1 FROM @tblBettype WHERE bettype = 228)
		BEGIN
			IF @action = 'REFUND' AND EXISTS (SELECT TOP 1 1 FROM @tblBettype WHERE IsSettleDetermined = 1 )
				SET @IsSettleDetermined = 1
			
			INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue)
			SELECT	ResourceId, HomeValue, AwayValue		
			FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
			WHERE	MatchId = @MatchId 
					AND ResourceId LIKE '2280_'

			IF @Action = 'CAL' 
			BEGIN
				SET @ResultStatus = 5

				INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway)
				SELECT	t.ResourceId
						,STUFF ((SELECT	',' + CAST(bt.position AS VARCHAR(200)) + '|' + CAST(@ResultStatus AS VARCHAR(1))
									FROM	@tblBettype	bt
									WHERE	bt.bettype = 228
											AND bt.position <= 45
									FOR XML PATH ('')
							),1,1,'') strPosHome
						,STUFF ((SELECT	',' + CAST((bt.position - 46) AS VARCHAR(200)) + '|' + CAST(@ResultStatus AS VARCHAR(1))
									FROM	@tblBettype	bt
									WHERE	bt.bettype = 228
											AND bt.position >= 46
									FOR XML PATH ('')
							),1,1,'') strPosAway
				FROM	@tblResultDetail t
				WHERE	t.ResourceId = '22800'

				IF @IsAuto = 0
				BEGIN
					INSERT INTO @tblPosition (ResourceId, strPosHome, strPosAway)
					SELECT	t.ResourceId
							,STUFF ((SELECT	',' + CAST(bt.position AS VARCHAR(200)) + '|' + CAST(bt.betOption AS VARCHAR(200))
										FROM	@tblBettype	bt
										WHERE	bt.bettype = 228
												AND bt.position <= 45
										FOR XML PATH ('')
								),1,1,'') strBetOptionHome
							,STUFF ((SELECT	',' + CAST((bt.position - 46) AS VARCHAR(200)) + '|' + CAST(bt.betOption AS VARCHAR(200))
										FROM	@tblBettype	bt
										WHERE	bt.bettype = 228
												AND bt.position >= 46
										FOR XML PATH ('')
								),1,1,'') strBetOptionAway
					FROM	@tblResultDetail t
					WHERE	t.ResourceId = '22801'
				END

				UPDATE	r 
					SET	HomeValue = CASE WHEN ISNULL(p.strPosHome,'') <> '' THEN dbo.f_Set_SetChars(v.HomeValue, p.strPosHome) ELSE r.HomeValue END 
						,AwayValue = CASE WHEN ISNULL(p.strPosAway,'') <> '' THEN dbo.f_Set_SetChars(v.AwayValue, p.strPosAway) ELSE r.AwayValue END
				FROM	@tblResultDetail r
					CROSS APPLY (SELECT CASE WHEN r.HomeValue IS NULL OR r.HomeValue = '' THEN REPLICATE('0', 50) ELSE r.HomeValue END AS HomeValue
										,CASE WHEN r.AwayValue IS NULL OR r.AwayValue = '' THEN REPLICATE('0', 50) ELSE r.AwayValue END AS AwayValue
								)v
					INNER JOIN @tblPosition p 
						ON	r.ResourceId = p.ResourceId
			END

			SELECT	@BetOption1st = MAX(CASE WHEN ResourceId = '22801' THEN HomeValue ELSE '' END)
					,@BetOption2nd = MAX (CASE WHEN ResourceId = '22801' THEN AwayValue ELSE '' END)
					,@ResultStatus1st = MAX (CASE WHEN ResourceId = '22800' THEN HomeValue ELSE '' END)
					,@ResultStatus2nd = MAX (CASE WHEN ResourceId = '22800' THEN AwayValue ELSE '' END)				
			FROM	@tblResultDetail

			;WITH cteBetOption
			AS
			(
				SELECT	f.pos AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOption1st) f
				WHERE	f.pos < 46 AND ISNULL(@BetOption1st,'') <> ''
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS BetOption
				FROM	dbo.f_Set_GetChars(@BetOption2nd) f
				WHERE	f.pos < 45 AND ISNULL(@BetOption2nd,'') <> ''
			)
			,cteResutStatus
			AS (
				SELECT	f.pos AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus1st) f
				WHERE	f.pos < 46 AND ISNULL(@ResultStatus1st,'') <> ''
				UNION ALL
				SELECT	f.pos + 46 AS Position, f.ResultStatus AS ResultStatus
				FROM	dbo.f_Set_GetChars(@ResultStatus2nd) f
				WHERE	f.pos < 45 AND ISNULL(@ResultStatus2nd,'') <> ''
			)
			,cteResult
			AS (
				SELECT rs.Position, CASE WHEN rs.ResultStatus IN (4,5,7) THEN bo.BetOption ELSE 0 END AS BetOption
				FROM cteResutStatus rs
					INNER JOIN cteBetOption bo
						ON rs.Position = bo.Position
			)
			INSERT INTO @tblAccumulatedScore (Position, BetOption, AccumulatedScore)
			SELECT c1.Position, c1.BetOption, c2.BetOption
			FROM cteResult c1
				INNER JOIN cteResutStatus crs
					ON c1.Position = crs.Position
				CROSS APPLY (
					SELECT	ISNULL(SUM(c2.BetOption), 0) as BetOption
					FROM	cteResult c2
					WHERE	c2.Position <= c1.Position
				) c2
				
			UPDATE r 
				SET AccumulatedScore = a.AccumulatedScore
					,BetOption = a.BetOption
			FROM	@tblBettype r
				INNER JOIN @tblAccumulatedScore a
					ON	r.BetType = 228
						AND r.Position = a.Position

			SELECT TOP 1 @maxSelectedTotalGoal = AccumulatedScore
						,@maxSelectedPosition = Position
			FROM  @tblBettype 
			WHERE bettype = 228
			ORDER BY Position DESC

			SELECT	@totalChangedScore = SUM(BetOption)
			FROM	@tblBettype
			WHERE	bettype = 228

			IF EXISTS (	SELECT	TOP 1 1
						FROM	@tblBettype t
							INNER JOIN dbo.bettrans b WITH(NOLOCK)
								ON	b.matchid = @matchid
									AND b.bettype = t.Bettype
						WHERE	b.statusID NOT IN (101)
								AND b.bettype = 228
								AND 1 = CASE
											WHEN t.Position < 45 AND b.hdp1 = t.Position THEN 1
											WHEN t.Position > 45 AND b.hdp1 = t.Position - 1 THEN 1
											ELSE 0
										END
								AND 1 = CASE
											WHEN @action = 'REFUND' AND @IsSettleDetermined = 0 AND (b.oddsspread + 0.25) < @maxSelectedTotalGoal THEN 0
											WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) < @maxSelectedTotalGoal - @totalChangedScore THEN 0
											ELSE 1
										END
								AND (b.statusID = 1
										OR (b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime, @currentdate) > @currentdate))
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

				)
				SELECT @isExistWaitingTicket = 1

			IF @isExistWaitingTicket = 0
			BEGIN
				IF EXISTS (	SELECT	TOP 1 1
							FROM	dbo.bettrans b WITH(NOLOCK)
							WHERE	b.matchid = @matchid
									AND b.bettype = 228
									AND 1 = CASE
												WHEN @maxSelectedPosition < 45 AND b.hdp1 > @maxSelectedPosition THEN 1
												WHEN @maxSelectedPosition >= 45 AND b.hdp1 >= @maxSelectedPosition THEN 1
												ELSE 0
											END
									AND 1 = CASE 
												WHEN @action = 'CAL' AND @maxSelectedTotalGoal > (b.oddsspread + 0.25)  THEN 1
												WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) <= @maxSelectedTotalGoal AND (b.oddsspread + 0.25) >= @maxSelectedTotalGoal - @totalChangedScore THEN 1
												ELSE 0
											END
									AND (b.statusID = 1
										OR (b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime, @currentdate) > @currentdate))
									AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					)
				SET @isExistWaitingTicket = 1
			END
		END
				
		IF EXISTS (SELECT TOP 1 1 
					FROM	dbo.bettrans b WITH(NOLOCK)
						INNER JOIN @tblBettype t
							ON	b.bettype = t.bettype
					WHERE	b.matchid = @matchid
							AND b.bettype <> 228
							AND 1 = CASE
										WHEN t.HasInjuryTime = 0
											THEN CASE 
													WHEN b.hdp1 = t.Position THEN 1
													ELSE 0
												END
										ELSE CASE
												WHEN t.Position < 45 AND b.hdp1 = t.Position THEN 1
												WHEN t.Position > 45 AND b.hdp1 = t.Position - 1 THEN 1
												ELSE 0
											END
									END
							AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		)
			SELECT @isExistWaitingTicket = 1
	END
		
	IF @Action IN ( 'CAL', 'REFUND', 'UNDO' ) AND @Mode = 'EAR'
	BEGIN
		IF @xmlData IS NOT NULL OR @Sporttype = 1
		BEGIN
			EXEC sp_xml_preparedocument @handle OUTPUT, @xmlData
		    INSERT INTO @tmpResourceIDs(ResourceID, BetType, BetID)
		    SELECT DISTINCT tbl.Id, sp.BetType, sp.BetID
		    FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id    VARCHAR(20)
					                                           ,Home VARCHAR(50)
					                                           ,Away VARCHAR(50)
		                                        ) AS tbl
		        INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.Id
		    WHERE sp.SportType = @SportType 		    
		    EXEC sp_xml_removedocument @handle
	
		    
			IF EXISTS (SELECT TOP 1 1
					   FROM dbo.bettrans b WITH(NOLOCK)
					   		INNER JOIN @tmpResourceIDs t ON b.Bettype = t.Bettype AND (t.BetID = 0 OR t.BetID = b.BetID)
					   WHERE b.matchid = @matchid
					   		AND (b.statusID = 1 -- waiting status
								OR (b.statusID = 0 AND b.SecAcceptFlag = 1 AND ISNULL(b.checktime, @currentdate) > @currentdate)
							)
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					)	
				SELECT @isExistWaitingTicket = 1
		END
		ELSE 
		BEGIN
			SET @xml = CONVERT(XML,@xmlData)
			CREATE TABLE #tmpEarlyBettypes (bettype SMALLINT PRIMARY KEY)
			
			INSERT INTO #tmpEarlyBettypes(bettype)
			SELECT	bettype
			FROM	dbo.f_Set_GetEarlyBettypes()
			
			
			INSERT INTO @tmpResourceIDs (ResourceID)
			SELECT	T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
			FROM	@xml.nodes('/Results/Resource') AS T(C)
			
			IF EXISTS(SELECT  TOP 1 1
						FROM	@tmpResourceIDs t
							INNER JOIN (
								SELECT	CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20)) AS ResourceId
								FROM	dbo.bettrans b WITH(NOLOCK)
									INNER JOIN #tmpEarlyBettypes t
										ON b.bettype = t.bettype
								WHERE	b.matchid = @matchid
									AND (b.statusID = 1 -- waiting status
										OR (b.statusID = 0 AND b.SecAcceptFlag=1 AND ISNULL(b.checktime,@currentdate) > @currentdate))
									AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							) b
								ON b.ResourceId = t.ResourceID
				)
				SELECT @isExistWaitingTicket = 1
		END
		
		
	END
	
	IF @isExistWaitingTicket = 1
	BEGIN
		SELECT @ErrCode = 1001013
			,@ErrMsg = 'Cannot proceed as there exists some PENDING tickets in this match. Please contact admin for help.'
			
		RETURN
	END	
END
GO


