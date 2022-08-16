/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_InstantCalculation_Checking]
	@MatchId			INT
	, @InstantKey		INT
	, @HomeScore		VARCHAR(50) = ''
	, @AwayScore		VARCHAR(50) = ''
    , @Action			VARCHAR(10) = 'CAL'
	, @Mode				VARCHAR(10)
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			VARCHAR(250) = '' OUTPUT
AS

/*
	Creator: 20160930@Bobby
	Task: Update or insert new score result for Instant Calculation.
	DB: DBTXN/bodb02
	Revisions:
		- 20160930@Bobby: #65003 - Check validation of instant process 
		- 20161031@Bobby: #66484 - Allow score [0-0] to do Inst.Calc
		- 20161128@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170815@Kathy: Using table ResultDetail to store FGLG result instead of betstatus [Redmine:#81308]
		- 20171212@Kathy: Show error when change back score [Redmine:#84266]
		- 20180801@Kaden: Verify calculateHT before calculating FT [Redmine:#99247]
		- 20181205@Vicky: Add New Undecided Option for MTD team [Redmine:#104948]
		- 20191210@Max: Instant Settlement for Corner Bettype [Redmine:#124951]
		- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		- @Action: ['CAL']
		- @Mode: ['INST-HT', 'INST-FT']

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @matchcode		VARCHAR(30)
		, @leagueid			INT
		, @betstatus		NVARCHAR(50)
		, @totalGoal		TINYINT
		, @totalGoalCheck	TINYINT
		, @goalRecordCheck	VARCHAR(50)
		--, @isPending		BIT
		--, @isUnDecided		BIT
		, @SettlementStatus	TINYINT
		, @isCalculatedHT	BIT
		, @instantCheck		BIT
		, @CalculationType	TINYINT
		, @hScore			TINYINT
		, @aScore			TINYINT
		, @hScore1H			TINYINT
		, @aScore1H			TINYINT
		, @hScore2H			TINYINT
		, @aScore2H			TINYINT
		, @hthomescore		TINYINT
		, @htawayscore		TINYINT
		, @FGNG				VARCHAR(50)		
		, @GoalRecord		VARCHAR(50)
		, @InstantKeyValue	VARCHAR(50)
		, @livehomescore	TINYINT
		, @liveawayscore	TINYINT
		
		, @IsExistFGNG		BIT
		, @IsExistHTFGNG	BIT
		, @IsExistsHTFG		BIT
		, @IsExistsFG		BIT
		--CornerBettype
		,@ChildMatchType		TINYINT
		,@CornerResultString	NVARCHAR(MAX)
		,@Char					VARCHAR(1)
		,@Position				TINYINT
		,@HomeRaceTo			TINYINT
		,@AwayRaceTo			TINYINT
		,@LenResultString		TINYINT
		,@ResultCorner			NVARCHAR(MAX) = ''
		,@hdp					VARCHAR(5) = ''
		,@ResourceResult_Corner	NVARCHAR(MAX) = ''
		,@ResourceResult_CornerRace NVARCHAR(MAX) = ''
		,@NeitherRaceTo			TINYINT
		,@IsCentral				BIT = 0

	CREATE TABLE #instantBettype (bettype SMALLINT)
	DECLARE @ResultDetail_Corner AS TABLE (hdp INT, ResourceID VARCHAR(20), HomeValue VARCHAR(10))
	DECLARE @ResultDetail_Corner_tickets AS TABLE (ResourceID VARCHAR(20))
	DECLARE @ResultDetail_Corner_tmp AS TABLE (ResourceID VARCHAR(20), HomeValue VARCHAR(10))
	
	SET @InstantKeyValue		= CAST(@InstantKey AS VARCHAR(50))
	
	SELECT
		@HomeScore			= ps.HomeValue
		, @AwayScore		= ps.AwayValue
		, @GoalRecord		= ISNULL(fgng.GoalRecord, '')
	FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
		OUTER APPLY (	
			SELECT HomeValue AS GoalRecord
			FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK) 
			WHERE MatchId 			= @MatchId
				AND TypeId			= 103 --FGNG
				AND AwayValue 		= @InstantKeyValue
				
		) AS fgng
	WHERE ProviderResultDetailId = @InstantKey
	
	SELECT @ErrCode			= 0
		, @ErrMsg			= ''
		, @instantCheck		= 0
		, @CalculationType	= CASE 
								WHEN @Mode = 'INST-HT' THEN 101
								WHEN @Mode = 'INST-FT' THEN 102
								ELSE 0
							END
		, @hScore			= CAST(@HomeScore AS INT)
		, @aScore			= CAST(@AwayScore AS INT)
		, @totalGoal		= @hScore + @aScore
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #instantBettype (bettype)
	SELECT bettype
	FROM dbo.f_Set_Instant_GetBettypes()
	WHERE 1	= 	CASE 
					WHEN @CalculationType = 101 AND InstantType & 1 = 1 THEN 1
					WHEN @CalculationType = 102 AND InstantType & 2 = 2 THEN 1
					ELSE 0 
				END
	
	-- checking for instant match status
    SELECT 
		@matchcode 			= m.matchcode
		, @leagueid   		= m.leagueid
		, @betstatus		= m.betstatus
		--, @isPending		= ISNULL(mr.isPending, 0)
		--, @isUnDecided		= ISNULL(mr.isUnDecided, 0)
		, @SettlementStatus	= ISNULL(m.SettlementStatus, 0)
		, @isCalculatedHT   = ISNULL(mr.IsHTCal, 0)
		, @hthomescore		= ISNULL(hthomescore, 0)
		, @htawayscore		= ISNULL(htawayscore, 0)
		, @livehomescore	= ISNULL(m.livehomescore,0)
		, @liveawayscore	= ISNULL(m.liveawayscore,0)
		, @ChildMatchType	= ISNULL(m.ChildMatchType,0)
    FROM dbo.match m WITH (NOLOCK)
		INNER JOIN dbo.league l WITH (NOLOCK)
		ON m.leagueid		= l.leagueid
		INNER JOIN dbo.match_remark mr WITH (NOLOCK)
		ON m.matchid 		= mr.matchid
    WHERE m.matchid 		= @MatchId
		AND m.sporttype		= 1
		AND 2 & ISNULL(m.AutoSetting, l.AutoSetting) = 2
	
	IF (@matchcode 		IS NULL --does not exist match
		OR CHARINDEX('hedge', @matchcode) > 0 -- does not allow doing Inst.C for hedge match
		OR @SettlementStatus & 87 	> 0 -- does not allow doing Inst.C for Pending, Undecided, MTDHold, UnderSettlement, Hold Key
		OR (@Mode = 'INST-FT' AND @isCalculatedHT = 0)
		OR (@hScore > @livehomescore OR  @aScore > @liveawayscore)
	)
    BEGIN
		IF(CHARINDEX('hedge', @matchcode) > 0)
		BEGIN
			SELECT @ErrCode = 1001004
			, @ErrMsg   = 'The selected match is a hedge match. Therefore, it cannot be instantly calculated.'
		END
		ELSE IF(@Mode = 'INST-FT' AND @isCalculatedHT = 0)
		BEGIN
			SELECT @ErrCode = 1001003
			, @ErrMsg   = 'Cannot execute FT instant calculation due to HT process (auto/manual) has not done yet.'
		END
		ELSE IF(@hScore > @livehomescore OR  @aScore > @liveawayscore)
		BEGIN
			SELECT @ErrCode = 1001005
			, @ErrMsg   = 'Instant Settlement cannot be executed because the Home/Away score which is used for Instant Settlement is greater than the current Home/Away score.'
		END
		ELSE
		BEGIN
			SELECT @ErrCode = 1001001
			, @ErrMsg   = 'This match is invalid or disabled instant calculation setting!'
		END
    END
	
	IF @ErrCode = 0
	BEGIN
		--SET scores in 1H & 2H
		SELECT @hScore1H	= CASE WHEN @CalculationType = 101 THEN @hScore ELSE @hthomescore END
			, @aScore1H		= CASE WHEN @CalculationType = 101 THEN @aScore ELSE @htawayscore END 
			, @hScore2H		= CASE WHEN @CalculationType = 102 THEN @hScore-@hScore1H ELSE 0 END
			, @aScore2H		= CASE WHEN @CalculationType = 102 THEN @aScore-@aScore1H ELSE 0 END
			, @GoalRecord	= CASE WHEN LEFT(@GoalRecord, 1) = ';' THEN SUBSTRING(@GoalRecord,2,LEN(@GoalRecord) - 1) ELSE @GoalRecord END
			, @FGNG			= CASE 
								WHEN LEFT(@GoalRecord, 1) = 'H' THEN '1'  
								WHEN LEFT(@GoalRecord, 1) = 'A' THEN '2'  
								ELSE ''
							END 
			, @FGNG			= CASE WHEN @FGNG <> '' THEN @FGNG + ':1' ELSE '' END
								
		BEGIN TRY
			;WITH InstMatchResult AS (
				SELECT TOP 1 
					CAST(HomeValue AS TINYINT) AS HomeScore
					,CAST(AwayValue AS TINYINT) AS AwayScore
					,ISNULL(gc.GoalRecord, '') AS GoalRecord
				FROM DBPRO.bodb02.dbo.AutoPayoutResult aps WITH (NOLOCK)
					OUTER APPLY (
						SELECT TOP 1 HomeValue AS GoalRecord
						FROM DBPRO.bodb02.dbo.ProviderResultDetail ps WITH (NOLOCK)
						WHERE matchid 			= @MatchId
							AND TypeId 			= 103 -- FGNG
							AND IsConfirmed		= 1 -- completed
						ORDER BY ProviderResultDetailId DESC
					) AS gc
				WHERE matchid 			= @MatchId
					AND CalculationType = @CalculationType
					AND StatusId		= 2 -- completed
				ORDER BY ModifiedDate DESC
			) 
			SELECT @totalGoalCheck 	= HomeScore + AwayScore
				,@goalRecordCheck	= GoalRecord
			FROM InstMatchResult
			
			-- CHECK any instant scores has been completed
			SELECT @goalRecordCheck = CASE WHEN LEFT(@goalRecordCheck, 1) = ';' THEN SUBSTRING(@goalRecordCheck,2,LEN(@goalRecordCheck) - 1) ELSE @goalRecordCheck END
		
			
			
			--CornerRace
			IF @ChildMatchType = 204
			BEGIN
				SELECT @CornerResultString = ISNULL(@GoalRecord, '')
					,@ResultCorner = ''
					,@Position = 1
					,@HomeRaceTo = 0
					,@AwayRaceTo = 0
					,@NeitherRaceTo = 0
				SELECT @LenResultString = LEN(@CornerResultString)

				WHILE (@Position <= @LenResultString)
				BEGIN
					SET @Char = SUBSTRING(@CornerResultString, @Position, 1)
					
					IF @Char = 'H'	
					BEGIN
						SET @HomeRaceTo = @HomeRaceTo + 1

						IF @HomeRaceTo > @AwayRaceTo
						BEGIN
							IF @HomeRaceTo < 10  
								SET @hdp = '0' + CAST(@HomeRaceTo AS VARCHAR(5))
							ELSE 
								SET @hdp = CAST(@HomeRaceTo AS VARCHAR(5))

							INSERT INTO @ResultDetail_Corner (HDP, ResourceID, HomeValue)
							VALUES (@HomeRaceTo,CAST(@hdp AS VARCHAR), @Char)
							
						END	
					END
					ELSE IF @Char = 'A' 
					BEGIN
						SET @AwayRaceTo = @AwayRaceTo + 1
						IF @AwayRaceTo > @HomeRaceTo
						BEGIN
							IF @AwayRaceTo < 10  
								SET @hdp = '0' + CAST(@AwayRaceTo AS VARCHAR(5))
							ELSE 
								SET @hdp = CAST(@AwayRaceTo AS VARCHAR(5))
								
							INSERT INTO @ResultDetail_Corner (HDP,ResourceID, HomeValue)
							VALUES (@AwayRaceTo,CAST(@hdp AS VARCHAR), @Char)

						END
					END
					
					SET @Position = @Position + 1	 	
				END
				
				SELECT @ResultCorner = STUFF(
										(
											SELECT ';' + CAST(HDP AS VARCHAR) + HomeValue 
											FROM @ResultDetail_Corner FOR XML PATH ('')
										)
										, 1, 1, ''
									 ) + ';'
				FROM @ResultDetail_Corner
				
				SELECT @NeitherRaceTo = (
											SELECT COUNT(1) 
											FROM @ResultDetail_Corner
										)
				--
			END
			
			-- CHECK for abandoned case
			IF (
				ISNULL(@totalGoalCheck, 0) > 0 -- check is first instant calculation or not
				AND (
					@totalGoal < @totalGoalCheck
					OR LEFT(@GoalRecord, 1) <> LEFT(@goalRecordCheck, 1)
				)
				
			)
			BEGIN			
				--select instant bettype
				;WITH instantTicketCheck AS (
					SELECT b.transid
						, b.statusID
						, ods.statusID AS statusCheck
					FROM dbo.bettrans b WITH(NOLOCK)
						CROSS APPLY [dbo].[f_Set_Instant_CalModds] (
																	b.bettype
																	, b.betteam
																	, b.hdp1
																	, b.hdp2
																	, @hScore1H
																	, @aScore1H
																	, @hScore2H
																	, @aScore2H
																	, @FGNG
																	, @CalculationType
																	, @ResultCorner
																	, @NeitherRaceTo
																	, @GoalRecord
																) AS ods
					WHERE b.matchid 	= @matchid 
						AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) AND b.recommend <> 1688156) --exclude betdaq/betfair
						AND EXISTS (SELECT TOP 1 1 FROM #instantBettype ib WHERE ib.bettype = b.bettype)
						AND b.statusId IN (112, 113)
						AND ISNULL(b.betdaqid,0) <> -2
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
				)
				SELECT TOP(1) @instantCheck = 1
				FROM instantTicketCheck
				WHERE statusCheck 	<> statusID
				
				IF(@instantCheck > 0)
				BEGIN
					SELECT @ErrCode = 1001002
						, @ErrMsg   = 'Some ''WON''/''LOSE'' tickets settled by instant calculation need to be un-calculated with the score. Please arrange to uncalculate instant calculation with the wrong score first. Then, please try to execute instant calculation again.'
				END
			END
			
		END TRY
		BEGIN CATCH 
			SELECT @ErrCode = 1001003
				, @ErrMsg   = ERROR_MESSAGE()
		END CATCH
	END
	
	IF @ErrCode = 0
	BEGIN	
		;WITH cteBetTickets
		AS (
			SELECT	bettype, MAX(CASE WHEN RIGHT(betteam,1) = '1' THEN 1 ELSE 0 END) AS IsExistsFG 
			FROM	dbo.bettrans WITH(NOLOCK)
			WHERE	matchid = @MatchId
					AND bettype IN (14, 127)
					AND statusID NOT IN (101, 102)
					AND betteam IN ('1:1', '2:1', '0:0')
					AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
			GROUP BY bettype
		)
		SELECT	@IsExistFGNG = MAX(CASE WHEN bettype = 14 THEN 1 ELSE 0 END)
				,@IsExistHTFGNG = MAX(CASE WHEN bettype = 127 THEN 1 ELSE 0 END)

				,@IsExistsFG = MAX(CASE WHEN bettype = 14 AND IsExistsFG = 1 THEN 1 ELSE 0 END)
				,@IsExistsHTFG = MAX(CASE WHEN bettype = 127 AND IsExistsFG = 1 THEN 1 ELSE 0 END)
		FROM	cteBetTickets
	END
	
	SELECT	ISNULL(@IsExistFGNG,0) AS IsExistFGNG
			,ISNULL(@IsExistHTFGNG,0) AS IsExistHTFGNG
			,ISNULL(@GoalRecord,'') AS GoalRecord
			,ISNULL(@IsExistsFG,0) AS IsExistsFG
			,ISNULL(@IsExistsHTFG,0) AS IsExistsHTFG
			,@betstatus AS betstatus
END
GO
