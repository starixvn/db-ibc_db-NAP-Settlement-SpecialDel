/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CaptureBalanceByWallet]
	@MatchId 			INT
	, @sportType		INT
	, @Action 			VARCHAR(30)
	, @Mode 			TINYINT
	, @FMResults		VARCHAR(MAX)	= NULL
	, @BAQuarter 		VARCHAR(100)	= NULL
	, @TennisSet    	VARCHAR(100)	= NULL
	, @BAResults		VARCHAR(MAX)	= NULL
	, @ResourceIDs      VARCHAR(MAX)	= NULL 
AS
/* 
	Created: 20170419@Bobby.nguyen  
	Task:  75500 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	Original:   

	Revisions:  
		- 20170801@Bobby: Initial

	Param's Explanation:   
		- @MatchId: Id of match event
		- @Action : [CAL, CAL-HT, CAL-FT]
		- @Mode: 1: Used for Auto payout process
			   2: Used for Manual settle process
			   3: Used for Manual refund process
			   4: Used for CAL FGLG
			   5: Used for Conner
			   6: Used for Auto Settlement
			   7: Used for Fast Market
			   8: Used for Early Payout


		- @FMResults: Fast Market result
			+ Sample: '<b Id="221">
							<r p="0" r="36" />
							<r p="2" r="1" />
							<r p="2" r="4" />
						</b>'

		- @BAQuarter: BAIO quater info 
			+ Sample: '801,802,1H,803,804,2H,FT'

		- @TennisSet: Tennis result
			+ Sample: '1,2,3,4,5,6'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isCheckBet		BIT
		, @balanceType		TINYINT
		, @xmlFMResults		XML
		, @xmlBAResults		XML
		, @minBettype		SMALLINT
		, @maxBettype		SMALLINT
				
	DECLARE @tmpBettypes TABLE (bettype SMALLINT)
	CREATE TABLE #tmpReferTransId (transid BIGINT PRIMARY KEY)

	SELECT @xmlFMResults 	= CAST(ISNULL(@FMResults, '<r />') AS XML)
		, @xmlBAResults 	= CAST(ISNULL(@BAResults, '<Results />') AS XML)
		, @balanceType 		= 1 --default sportbook
	
	--Check for doing capture balance by bet ticket or NOT
	SELECT @isCheckBet	= CASE 
							WHEN @sportType IN (2,5) OR @Mode IN (6,7,8) THEN 1 
							ELSE 0 
						END
		
	IF (@isCheckBet = 0) --Capturing Balance M1
	BEGIN		
		INSERT INTO @tmpBettypes(bettype)
		SELECT f.Bettype
		FROM f_Set_GetGroupBettypes() AS f			
		WHERE 1 = CASE 
					WHEN @Mode = 1 THEN --Auto Payout
						CASE 
							WHEN @Action = 'CAL-HT' AND f.GroupId IN (1) AND f.IsUsedGoalRecordValue = 0 THEN 1
							WHEN @Action = 'CAL-FT' AND f.GroupId IN (2) AND f.IsUsedGoalRecordValue = 0 THEN 1
							ELSE 0
						END
					WHEN @Mode = 2 THEN --Manual CAL
						CASE 
							WHEN @Action = 'CAL' AND f.GroupId IN (1,2,3,4,5,6,7,10) THEN 1
							WHEN @Action = 'CAL-HT' AND f.GroupId IN (1,3,5) THEN 1
							WHEN @Action = 'CAL-FT' AND f.GroupId IN (2,4,6,7,10) THEN 1
							WHEN @Action = 'UNDO' AND f.IsAuto = 0 THEN 1
							ELSE 0
						END
					WHEN @Mode = 3 THEN --Maunal REFUND
						CASE 
							WHEN @Action = 'CAL' AND f.IsAuto = 0 THEN 1
							WHEN @Action = 'CAL-HT' AND f.Is3x30 = 1 THEN 1
							WHEN @Action = 'CAL-FT' AND f.GroupId IN (2,4,6,7) THEN 1
							ELSE 0
						END
					WHEN @Mode = 4 THEN --FGLG
						CASE 
							WHEN @Action = 'CAL-HT' AND f.GroupId IN (3) THEN 1
							WHEN @Action = 'CAL-FT' AND (f.GroupId IN (4) OR (f.GroupId = 2 AND f.IsUsedGoalRecordValue = 1)) THEN 1
							ELSE 0
						END
					WHEN @Mode = 5 THEN --Conner
						CASE 
							WHEN @Action = 'CAL' AND f.GroupId IN (5,6) THEN 1
							WHEN @Action = 'CAL-HT' AND f.GroupId IN (5) THEN 1
							WHEN @Action = 'CAL-FT' AND f.GroupId IN (6) THEN 1
							ELSE 0
						END
					
					ELSE 0 
				END
				
		SELECT	@minBettype = MIN(bettype)
				,@maxBettype = MAX(bettype)
		FROM	@tmpBettypes
	
		-- get main transid of Bettrade & transid of bettype 911
		BEGIN
			;WITH cteMain
			AS(
				SELECT	b.transId, b.matchid, b.custid
				FROM	dbo.bettrans b WITH(NOLOCK)
					INNER JOIN @tmpBettypes t
						ON t.bettype = b.bettype
				WHERE	b.matchid = @matchid
						AND b.betdaqid = 0 
						AND b.bettype BETWEEN @minBettype AND @maxBettype
				UNION ALL
				SELECT NULL, NULL, NULL
			)			
			INSERT INTO #tmpReferTransId(transid)
			SELECT	ISNULL(co.transid, main.transid) AS transid
			FROM cteMain main
				LEFT JOIN dbo.bettrans co WITH(NOLOCK)
					ON	co.matchid = main.matchid
						AND co.refno = main.transid
						AND co.custid = main.custid
						AND co.bettype = 911
			WHERE main.transid IS NOT NULL
			
		END
		
		INSERT INTO @tmpBettypes (bettype) VALUES (904), (914)  -- summary of Bettrade (904) and CashOut (914)
		
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
					AND b.bettype BETWEEN @minBettype AND @maxBettype	
						
			UNION ALL
			SELECT	b.custid
					,2 AS WalletType -- Cash wallet
					,0 AS BonusId -- not join bonus
					,b.winlost
					,b.actual_stake
					,b.playercomm
			FROM	#tmpReferTransId t
				INNER JOIN dbo.bettrans b WITH(ROWLOCK)
					ON	t.transid = b.transid
			WHERE	b.matchid = @matchid
					AND b.bettype = 911 
			
			UNION ALL
			SELECT	b.custid
					,2 AS WalletType  -- Cash wallet
					,0 AS BonusId -- not join bonus
					,b.winlost
					,b.actual_stake
					,b.playercomm
			FROM	#tmpReferTransId t
				INNER JOIN dbo.bettrans b WITH(ROWLOCK)
					ON	t.transid = b.refno
						AND b.matchid = @matchId
						AND b.bettype IN (901, 902, 903, 912, 913)					
		) b
		GROUP BY b.custid, b.WalletType, b.BonusId
	END
	ELSE --Capturing Balance M2
	BEGIN
		IF(@Mode IN (2,3,6,8)) --Tennis, BAIO & Early Payout
		BEGIN
			SELECT @matchid AS matchid
				, custid
				, @balanceType AS balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByBettypeBetId (
				@MatchId
				, @Mode
				, @Action
				, @SportType
				, @BAQuarter
				, @TennisSet
				, @xmlBAResults
				, @ResourceIDs
			)
		END
		ELSE IF (@Mode = 7) -- Fast Market
		BEGIN
			SELECT @matchid AS matchid
				, custid
				,@balanceType AS balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByFastMarket (
				@MatchId
				, @Action
				, @xmlFMResults
			)
		END
	END
END
GO
