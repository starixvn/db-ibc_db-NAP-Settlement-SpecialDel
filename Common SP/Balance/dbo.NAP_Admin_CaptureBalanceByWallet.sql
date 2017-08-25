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
	
	DECLARE @isCheckBet	BIT
		, @balanceType	TINYINT
	
	SELECT @FMResults 	= ISNULL(@FMResults, '<r />')
		, @BAResults 	= ISNULL(@BAResults, '<Results />')
		, @balanceType 	= 1 --default sportbook
	
	--Check for doing capture balance by bet ticket or NOT
	SELECT @isCheckBet	= CASE 
							WHEN @sportType IN (2,5) OR @Mode IN (7) THEN 1 
							ELSE 0 
						END
		
	IF (@isCheckBet = 0) --Capturing Balance M1
	BEGIN
		SELECT @matchid AS matchid
			, custid
			, @balanceType AS balanceType
			, WalletType
			, BonusID
			, balance 
		FROM dbo.f_Settle_GetBalanceByBettype (
			@MatchId
			, @Mode
			, @Action
		)
	END
	ELSE --Capturing Balance M2
	BEGIN
		IF(@Mode IN (2,3)) --Tennis & BAIO
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
			)
		END
		ELSE IF (@Mode = 7)
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
				, @FMResults
			)
		END
	END
END
GO
