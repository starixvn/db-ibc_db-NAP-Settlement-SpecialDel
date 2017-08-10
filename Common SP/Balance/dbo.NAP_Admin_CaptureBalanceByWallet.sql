/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_CaptureBalanceByWallet]
	@MatchId 			INT
	, @Action 			VARCHAR(30)
	, @Mode 			TINYINT
	, @FMResults		VARCHAR(MAX)	= NULL
	, @BAQuarter 		VARCHAR(100)	= NULL
	, @TennisSet    	VARCHAR(100)	= NULL
	, @BAResults		VARCHAR(MAX)	= NULL 
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

		- @BAResults: Early Payout result
			+ Sample: '<Results>
					   <Resource Id="603" HomeValue="H"/> 
					   <Resource Id="604" HomeValue="H"/> 
					   <Resource Id="Q1" HomeValue="30" AwayValue="40"/> 
					 </Results>'
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @sportType			INT
		, @isTrading			BIT
		, @isCheckBet			BIT
		, @balanceType			TINYINT
		, @bettypes				XML
		
	DECLARE @capturedBalance	TVP_BalanceWalletChange
	
	SELECT @sportType			= 1 
		, @isTrading			= 0
		, @isCheckBet			= 0
		, @FMResults 			= ISNULL(@FMResults, '<r />')
		, @BAResults 			= ISNULL(@BAResults, '<Results />')
	
	--CHECK sportType, is trading bet ticket
	IF(@Mode NOT IN(6,7,8))
	BEGIN
		SELECT TOP(1) @sportType 	= sportType
			, @isTrading 			= ISNULL(trade.IsTrading, 0)
		FROM dbo.match m WITH(NOLOCK)
			OUTER APPLY (
				SELECT TOP(1) CAST(1 AS BIT) AS IsTrading
				FROM dbo.bettrans b WITH(NOLOCK)
				WHERE matchid 		= @matchid 
					AND m.SportType = 1 --just offered soccer
					AND EXISTS ( 
						SELECT TOP 1 1
						FROM dbo.f_Settle_GetTradingBettype() 
						WHERE bettype = b.bettype
					)
			) AS trade
		WHERE m.matchid = @matchid
	END
	--Check for doing capture balance by bet ticket or NOT
	SELECT @isCheckBet	= CASE 
							WHEN @sportType IN (2,5) OR @Mode IN (7,8) THEN 1 
							ELSE 0 
						END

	--GET list bettype
	SELECT @bettypes 	= (
			SELECT f.GroupId 	AS '@GroupId'
				, f.GroupName 	AS '@GroupName'
				, f.Bettype 	AS '@Bettype'
			FROM dbo.f_Set_GetGroupBettypes() AS f
				LEFT JOIN dbo.f_Set_GetEarlyBettypes() AS fba
				ON f.Bettype = fba.Bettype
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
					WHEN @Mode = 6 THEN --Auto Settlement
						CASE 
							WHEN @Action IN ('CAL', 'REFUND', 'UNDO') AND f.GroupId = 8 THEN 1
							ELSE 0
						END
					WHEN @Mode = 7 THEN --Fast Market
						CASE 
							WHEN @Action IN ('CAL', 'REFUND', 'UNDO') AND f.GroupId = 9 THEN 1
							ELSE 0
						END
					WHEN @Mode = 8 THEN --Early Payout
						CASE 
							WHEN fba.Bettype > 0 THEN 1
							ELSE 0
						END
					ELSE 0 
				END
				FOR XML PATH ('r')
		)
	
	
	IF(@SportType > 0)
	BEGIN		
		SELECT @balanceType = CASE 
								WHEN (@sportType BETWEEN 1 AND 99 OR @sportType = 154) THEN 1 -- Sports
								WHEN (@sportType = 162) THEN 3 -- Casino
								ELSE 4  -- Others
							END
	
		IF (@isCheckBet = 0) --Capturing Balance M1
		BEGIN
			INSERT INTO @capturedBalance(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT matchid
				, custid
				, @balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByBettype (
				@MatchId
				, @bettypes
			)
			--GET balance by trading bet
			IF (@isTrading = 1)
			BEGIN
				INSERT INTO @capturedBalance(
					matchid
					,custid
					,balanceType
					,walletType
					,bonusId
					,balance
				)
				SELECT matchid
					, custid
					, @balanceType
					, 2 AS WalletType
					, 0 AS BonusID
					, balance 
				FROM dbo.f_Settle_GetBalanceByTradingBet (
					@MatchId
					, @bettypes
				)
			END
		END
		ELSE --Capturing Balance M2
		BEGIN
			INSERT INTO @capturedBalance(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT matchid
				, custid
				, @balanceType AS balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByBettypeTicket (
				@MatchId
				, @bettypes
				, @Mode
				, @SportType
				, @FMResults
				, @BAQuarter
				, @TennisSet
				, @BAResults
			)
		END
	END
	
	--OUTPUT captured balance
	SELECT matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,SUM(balance) AS balance
	FROM @capturedBalance
	GROUP BY matchid
		,custid
		,balanceType
		,walletType
		,bonusId
	
END
GO
