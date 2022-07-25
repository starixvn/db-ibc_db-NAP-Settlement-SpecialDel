/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CaptureBalanceByWallet]
	@MatchId 			INT
	, @sportType		INT
	, @Action 			VARCHAR(30)
	, @Mode 			TINYINT
	, @IsRefundHT		BIT				= 0
	, @FMResults		VARCHAR(MAX)	= NULL
	, @BAQuarter 		VARCHAR(100)	= NULL
	, @BAResults		VARCHAR(MAX)	= NULL
	--, @ResourceIDs      VARCHAR(MAX)	= NULL 
	, @SelectedRID      VARCHAR(MAX)    = NULL
	, @TransIDs		    VARCHAR(MAX)    = NULL
	, @IsCentral		BIT				= 0
AS
/* 
	Created: 20170419@Bobby.nguyen  
	Task:  75500 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	Original:   

	Revisions:  
		- 20170801@Bobby: Initial
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190425@Sol: Auto Payout Phase 3 [Redmine:#116073]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20190620@Kathy: Remove betradar corner bettypes [Redmine:#109584]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20201123@Kathy: Apply Settlement by Profile for soccer [Redmine:#142425]
		- 20210428@Kathy: Allow to settle directly for bettype 228 [Redmine:#153155]
		- 20210804@Helen: Support Cashout for Basketball [Redmine:#159617]
		- 20211130@Kathy: New cashout model [Redmine:#164838]	
		- 20220309@Kathy: Remove code old Cashout model [Redmine:#169643]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

	Param's Explanation:   
		- @MatchId: Id of match event
		- @Action : [CAL, CAL-HT, CAL-FT]
		- @Mode:
			   2: Used for Manual settle process, Auto Payout process
			   3: Used for Manual refund process
			   4: Used for CAL FGLG
			   7: Used for Fast Market
			   8: Used for Early Settlement Basketball
		
		- @FMResults: Fast Market result
			+ Sample: '<b Id="221">
							<r p="0" r="36" />
							<r p="2" r="1" />
							<r p="2" r="4" />
						</b>'

		- @BAQuarter: BAIO quater info 
			+ Sample: '801,802,1H,803,804,2H,FT'

		- @SelectedRID = '<root>
							<r bt="9001" b="801"/>
							<r bt="9001" b="801"/>
							<r bt="9001" b="801"/>
						 </root>'
		- @TransIDs = '<root>
							<r t="9001"/>
							<r t="9002"/>
							<r t="9003"/>
						 </root>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isCheckBet		BIT
		, @balanceType		TINYINT
		, @xmlFMResults		XML
		, @xmlBAResults		XML
		, @minBettype		SMALLINT
		, @maxBettype		SMALLINT
		, @handle			INT
	
		, @maxSelectedPosition INT 
		, @maxSelectedTotalGoal INT = 0
		, @totalChangedScore INT = 0
		, @maxSelectedTotalGoalBeforeReCAL INT = 0

	DECLARE @tmpBettypes TABLE (bettype SMALLINT, groupId SMALLINT, GroupName VARCHAR(50))
	DECLARE @tmpResourceIdsBasketBall TABLE (ResourceId VARCHAR(20), bettype SMALLINT)
    DECLARE @tmpSelectedRID TABLE(BetType SMALLINT, BetID BIGINT)
    DECLARE @matchid_tmp INT
	DECLARE @TmpFMData AS TABLE (
		bettype					SMALLINT
		,Position				TINYINT
		,BetOption				TINYINT
		,OldAccumulatedScore	INT -- 228
		,AccumulatedScore		INT -- 228
		,HasInjuryTime			BIT DEFAULT(0)
	)

	CREATE TABLE #tmpFMTransId (TransId BIGINT)
	---------------------------------------------------------------------------------------------------------------------------------------------------
	
	SELECT @xmlFMResults 	= CAST(ISNULL(@FMResults, '<r />') AS XML)
		, @xmlBAResults 	= CAST(ISNULL(@BAResults, '<Results />') AS XML)
		, @balanceType 		= 1 --default sportbook
		
	SET	@matchid_tmp = @MatchId	
	
	--Check for doing capture balance by bet ticket or NOT
	SELECT @isCheckBet	= CASE 
							WHEN @sportType IN (2,5) OR @Mode IN (7,8) THEN 1 
							ELSE 0 
						END
		
	----------------------------------------------------------------------------------------------------------------------------------------------------
	IF @TransIDs IS NOT NULL
	BEGIN
		DECLARE @tblTransID TABLE(transID BIGINT)
		
		EXEC sp_xml_preparedocument @handle OUTPUT, @TransIDs
	    INSERT INTO @tblTransID(transID)
	    SELECT t
	    FROM OPENXML(@handle,'root/r',1) WITH( t BIGINT
                                			) AS tbl
	    EXEC sp_xml_removedocument @handle
	    
        ----cal Balance
        SELECT @MatchId AS matchid,b.custid
               ,@balanceType AS balanceType
               ,ISNULL(b.WalletType,2) AS WalletType -- 2: Cash wallet,
               ,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
               ,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
        FROM @tblTransID t 
        	INNER JOIN BetTrans b WITH (ROWLOCK) ON b.transID = t.transID 
        GROUP BY b.custid, b.WalletType, b.BonusId

		RETURN 
	END
	
	IF @SelectedRID IS NOT NULL
    BEGIN
        
	    EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedRID
	    INSERT INTO @tmpSelectedRID(BetType, BetID)
	    SELECT DISTINCT bt, b
	    FROM OPENXML(@handle,'root/r',1) WITH( bt SMALLINT
	                                           ,b BIGINT
                                			) AS tbl
	    EXEC sp_xml_removedocument @handle
		
        ----cal Balance
        SELECT @MatchId AS matchid
				,b.custid
				,@balanceType AS balanceType
				,b.WalletType
				,b.BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM	(	
					SELECT	
						b.custid
						,ISNULL(b.WalletType,2) AS WalletType -- 2: Cash wallet
						,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
						,b.winlost
						,b.actual_stake
						,b.playercomm
					FROM BetTrans b WITH (ROWLOCK)
					WHERE b.matchid = @matchid_tmp
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						AND b.statusID NOT IN (101,102)
						AND EXISTS( SELECT TOP 1 1
									FROM @tmpSelectedRID t
									WHERE b.BetType = t.BetType AND (t.BetID = 0 OR b.BetID = t.BetID) 
									) 		
		) b
		GROUP BY b.custid, b.WalletType, b.BonusId
		
		RETURN
    END  ---END @SelectedRID
    ELSE IF (@isCheckBet = 0) --Capturing Balance M1
	BEGIN		
		INSERT INTO @tmpBettypes(bettype)
		SELECT f.Bettype
		FROM f_Set_GetGroupBettypes() AS f			
		WHERE	f.IsAuto = 0
				AND	1 = CASE 
							WHEN @Mode = 2 THEN --Manual CAL/ Auto CAL
								CASE 
									WHEN @Action = 'CAL' THEN 1
									WHEN @Action = 'CAL-HT' AND f.GroupId IN (1,3) THEN 1
									WHEN @Action = 'CAL-FT' AND f.GroupId IN (2,4)
											AND 1 = CASE 
														WHEN @IsRefundHT = 0 THEN 1
														WHEN @IsRefundHT = 1 AND f.Is3x30 = 0 THEN 1
														ELSE 0
													END
										THEN 1
									WHEN @Action = 'UNDO' THEN 1
									ELSE 0
								END
							WHEN @Mode = 3 THEN --Manual REFUND
								CASE 
									WHEN @Action = 'CAL' THEN 1
									WHEN @Action = 'CAL-HT' AND f.Is3x30 = 1 THEN 1
									WHEN @Action = 'CAL-FT' AND f.GroupId IN (2,4) 
											AND 1 = CASE 
														WHEN @IsRefundHT = 0 THEN 1
														WHEN @IsRefundHT = 1 AND f.Is3x30 = 0 THEN 1
														ELSE 0
													END
										THEN 1
									ELSE 0
								END
							ELSE 0 
						END
			AND f.SettledByProfile = CASE
										WHEN @Mode = 2 AND @Action IN ('CAL', 'CAL-HT', 'CAL-FT') AND @sportType = 1 THEN 0
										ELSE f.SettledByProfile
									END
				
		SELECT	@minBettype = MIN(bettype)
				,@maxBettype = MAX(bettype)
		FROM	@tmpBettypes
	
		SELECT @maxBettype = MAX(bettype)
		FROM @tmpBettypes
		
		SELECT @MatchId AS matchid
				,b.custid
				,@balanceType AS balanceType
				,b.WalletType
				,b.BonusId
				,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM	(	
			SELECT	
					b.custid
					,ISNULL(b.WalletType,2) AS WalletType -- 2: Cash wallet
					,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
					,b.winlost
					,b.actual_stake
					,b.playercomm
			FROM	 dbo.bettrans b WITH(ROWLOCK)
				INNER JOIN @tmpBettypes bt
					ON bt.bettype = b.bettype
			WHERE	b.matchid = @matchid	
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND b.bettype BETWEEN @minBettype AND @maxBettype	
		) b
		GROUP BY b.custid, b.WalletType, b.BonusId
	END
	ELSE --Capturing Balance M2
	BEGIN
		IF(@Mode IN (2,3,8)) --Tennis, BAIO & Early Payout
		BEGIN
			IF @Mode = 8  -- Early Settlement Basketball
			BEGIN
				INSERT INTO @tmpResourceIdsBasketBall (ResourceId, bettype)
				SELECT	rs.ResourceId
						,f.Bettype
				FROM (
					SELECT	T.C.value('@Id', 'VARCHAR(20)') AS ResourceId
					FROM	@xmlBAResults.nodes('/Results/Resource') AS T(C)
				) AS rs
					INNER JOIN dbo.f_Set_GetEarlyBettypes() f
						ON	rs.ResourceId LIKE CAST(f.bettype AS VARCHAR) + '%'
			END 

			INSERT INTO @tmpBettypes(groupId, GroupName, bettype)
			SELECT	DISTINCT
					f.GroupId
					, f.GroupName
					, f.Bettype 
			FROM	f_Set_GetGroupBettypes() f
				LEFT JOIN @tmpResourceIdsBasketBall AS eb -- Early Settlement for Basketball
					ON	f.Bettype = eb.Bettype
			WHERE	1 = CASE
							WHEN @Mode IN (2,3) AND f.IsAuto = 0 THEN 1 -- Manual CAL/REFUND 
							WHEN @Mode = 8 AND eb.bettype > 0 THEN 1 -- Early Settlement for Basketball
							ELSE 0
						END						

			SELECT	@MatchId AS matchid
					,b.custid
					,@balanceType AS balanceType
					,b.WalletType
					,b.BonusId
					,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM
			(	SELECT	b.custid
						,ISNULL(b.WalletType,2) AS WalletType -- 2: Cash wallet
						,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusId
						,b.winlost
						,b.actual_stake
						,b.playercomm
				FROM dbo.bettrans b WITH (ROWLOCK)
					INNER JOIN @tmpBettypes bt
						ON	bt.bettype = b.bettype
					OUTER APPLY (
						SELECT CAST(CAST(b.bettype AS VARCHAR) + ISNULL(SUBSTRING(CAST(b.betid AS VARCHAR), 2, LEN(b.betid)),'') AS VARCHAR(20)) AS ResourceId		
					) AS rs
				WHERE b.matchid	= @matchid	
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					AND 1 = CASE 
								WHEN @Mode IN (2, 3) AND @SportType = 2 THEN -- BasketBall
									CASE 
										WHEN @BAQuarter IS NULL THEN 1
										WHEN @BAQuarter LIKE '%' + bt.GroupName + '%' THEN 1 -- 1H, 2H, FT
										WHEN bt.GroupId = 10 AND @BAQuarter LIKE '%' + LEFT(CAST(b.betid AS VARCHAR),3) + '%' THEN 1 -- 801, 802, 803, 804
										ELSE 0
									END
								WHEN @Mode = 8 THEN -- Early Settlement for Basketball
					 				CASE 
										WHEN EXISTS(SELECT 1 FROM @tmpResourceIdsBasketBall WHERE ResourceId = rs.ResourceId) THEN 1
										ELSE 0
									END
								ELSE 0 --unsupported SportType
							END
				) b
				GROUP BY b.custid
					, b.WalletType
					, b.BonusID
		END
		ELSE IF (@Mode = 7) -- Fast Market
		BEGIN
			INSERT INTO @TmpFMData (bettype, Position, BetOption, OldAccumulatedScore, AccumulatedScore, HasInjuryTime)
			SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
				,X.C.value('@p','TINYINT') as Position
				,X.C.value('@r','TINYINT') as BetOption
				,X.C.value('@oa','INT') as OldAccumulatedScore
				,X.C.value('@a','INT') as AccumulatedScore
				,ISNULL(X.C.value('@i','BIT'), 0) AS HasInjuryTime
			FROM @xmlFMResults.nodes('/r/b') AS T(C)
				CROSS APPLY
					C.nodes('r') AS X(C)
			OPTION ( OPTIMIZE FOR ( @xmlFMResults = NULL ) )	

			IF EXISTS (SELECT TOP 1 1 FROM @TmpFMData WHERE bettype = 228)
			BEGIN
				SELECT TOP 1 @maxSelectedTotalGoal = AccumulatedScore
							,@maxSelectedPosition = Position
							,@maxSelectedTotalGoalBeforeReCAL = OldAccumulatedScore
				FROM  @TmpFMData 
				WHERE bettype = 228
				ORDER BY Position DESC

				SELECT	@totalChangedScore = SUM(BetOption)
				FROM	@TmpFMData
				WHERE	bettype = 228
			END
	
			INSERT INTO #tmpFMTransId(TransId)
			SELECT b.transid
			FROM dbo.bettrans b WITH (ROWLOCK)
				INNER JOIN @TmpFMData t
					ON t.bettype = b.bettype		
			WHERE b.matchid	= @matchid	
				AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				AND b.statusID NOT IN (101)
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
				AND 1 = CASE
							WHEN b.bettype <> 228 THEN 1
							WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) < @maxSelectedTotalGoal - @totalChangedScore THEN 0
							ELSE 1
						END

			IF @Action IN ('CAL', 'UNDO') AND EXISTS (SELECT TOP 1 1 FROM @TmpFMData WHERE bettype = 228)  
			BEGIN
				;WITH ctePreviousSettledTransId
				AS(
					SELECT	b.transid
					FROM	dbo.bettrans b WITH(NOLOCK)
					WHERE	b.matchid = @matchid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							AND b.bettype = 228
							AND b.statusID NOT IN (101)
							AND @action = 'CAL'
							AND 1 = CASE
										WHEN @maxSelectedPosition < 45 AND b.hdp1 > @maxSelectedPosition THEN 1
										WHEN @maxSelectedPosition >= 45 AND b.hdp1 >= @maxSelectedPosition THEN 1
										ELSE 0
									END
							AND @maxSelectedTotalGoalBeforeReCAL > (b.oddsspread + 0.25)  
				)
				INSERT INTO #tmpFMTransId(transid)
				SELECT	ISNULL(b.transid, c.transid) AS transid
				FROM ( 
					SELECT	b.transid
					FROM	dbo.bettrans b WITH(NOLOCK)
					WHERE	b.matchid = @matchid
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							AND b.bettype = 228
							AND b.statusID NOT IN (101)
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
				) b
					FULL JOIN ctePreviousSettledTransId c
						ON b.transid = c.transid
			END

			SELECT	@MatchId AS matchid
					,b.custid
					,@balanceType AS balanceType
					,ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
					,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
					,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
			FROM	#tmpFMTransId t
				INNER JOIN dbo.bettrans b WITH(ROWLOCK)
					ON t.TransId = b.transid
			GROUP BY b.custid
					,ISNULL(b.WalletType, 2)
					,CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END

		END
	END
END

GO
