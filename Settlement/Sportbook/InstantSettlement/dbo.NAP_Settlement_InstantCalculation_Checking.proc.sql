/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Settlement_InstantCalculation_Checking]
	@MatchId			INT
	,@Action			VARCHAR(10) 
	,@HomeScore			VARCHAR(50)		= ''
	,@AwayScore			VARCHAR(50)		= ''
	,@ResourceResult	VARCHAR(MAX)	= NULL
	,@ErrCode 			INT				= 0		OUTPUT
	,@ErrMsg 			VARCHAR(250)	= ''	OUTPUT
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
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		
	Param's Explanation:
		- @Action: ['CAL-INST-HT', 'CAL-INST-FT']
		- @ResourceResult
					<Results>
						<Resource Id="" HomeValue="" SettlementStatusId="" ResultStatusId=""/>
					</Results>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @fth					INT
			,@fta					INT
			,@hth					INT
			,@hta					INT
			
			,@IsCentral				BIT = 0
			,@sporttype				SMALLINT
			,@DeterminedType		TINYINT
			,@DummyResourceIds		VARCHAR(MAX) 
			,@DummyResourceResults	VARCHAR(MAX)
			,@xmlResourceResult		XML
			,@handle				INT

			,@IsExistFGNG			BIT
			,@IsExistHTFGNG			BIT
			,@IsExistHTFG			BIT
			,@IsExistFG				BIT

	DECLARE @tmpAllBettypes TABLE (Bettype SMALLINT PRIMARY KEY, ResourceId VARCHAR(20), SDTResourceId VARCHAR(20), SDTpfId SMALLINT, OddsType TINYINT, RefResourceId VARCHAR(20), DeterminedType TINYINT)
	DECLARE @tmpResources TABLE(
		ResourceID VARCHAR(20)
		,SDTResourceId VARCHAR(20)
		,HomeValue VARCHAR(2000)
		,AwayValue VARCHAR(2000)
	)
	DECLARE @tmpSettlementBettypeResult TABLE(Bettype SMALLINT, pfId INT, HomeValue VARCHAR(2000), AwayValue VARCHAR(2000))

	
	SELECT @DeterminedType = CASE 
								WHEN @Action LIKE '%HT%' THEN 1
								WHEN @Action LIKE '%FT%' THEN 4
								ELSE 0
							END

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

    SELECT	@fth = CAST(@HomeScore AS INT)
			,@fta = CAST(@AwayScore AS INT)
			,@hth = CASE WHEN @DeterminedType = 1 THEN CAST(@HomeScore AS INT) ELSE m.hthomescore END
			,@hta = CASE WHEN @DeterminedType = 4 THEN CAST(@AwayScore AS INT) ELSE m.htawayscore END
			,@Sporttype = m.sporttype
    FROM	dbo.match m WITH (NOLOCK)
    WHERE	m.matchid = @MatchId
		
	INSERT INTO @tmpAllBettypes(Bettype, SDTResourceId, SDTpfId, OddsType, ResourceId, RefResourceId, DeterminedType)
	SELECT	DISTINCT s.BetType, s.SDTResourceId, s.SDTpfId, s.OddsType, s.ResourceId, s.RefResourceId, s.DeterminedType
	FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
	WHERE	s.SportType = @sporttype
			AND ISNULL(s.DeterminedType,0) & @DeterminedType > 0
		
	-- Generate result
	BEGIN		
		SET @xmlResourceResult = CAST(@ResourceResult AS XML)

		;WITH cteGoalResource
		AS
		(
			SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
					,T.C.value('@HomeValue', 'VARCHAR(50)') AS HomeValue
					,T.C.value('@AwayValue', 'VARCHAR(50)') AS AwayValue
			FROM    @xmlResourceResult.nodes('/Results/Resource') AS T(C)
		)
		,cteResource
		AS
		(
			SELECT	CASE 
						WHEN @DeterminedType = 1 THEN CAST('01' AS VARCHAR(20))
						ELSE CAST('00' AS VARCHAR(20))
					END AS ResourceID
					,@HomeScore HomeValue
					,@AwayScore AwayValue
			UNION ALL
			SELECT  ResourceId, HomeValue, AwayValue
			FROM	cteGoalResource
			WHERE   ResourceID IS NOT NULL
		)
		INSERT INTO @tmpResources (ResourceID, HomeValue, AwayValue)
		SELECT	ResourceID, HomeValue, AwayValue
		FROM	cteResource

		SELECT	@DummyResourceIds = @DummyResourceIds + CAST(s.SDTResourceId AS VARCHAR(20)) + ','
		FROM	@tmpAllBettypes s
		WHERE	s.SDTResourceId IS NOT NULL
				AND EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes b WHERE b.Bettype = s.BetType)
				
		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@IsDetermined = 1
				,@Action = @Action
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResources (SDTResourceId, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
													,Home VARCHAR(2000)
													,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END
	
		INSERT INTO @tmpSettlementBettypeResult(Bettype, pfId, HomeValue, AwayValue)
		SELECT t.BetType, t.SDTpfId, t.HomeValue, t.AwayValue
		FROM (
			SELECT	s.SDTpfId
					,s.BetType
					,t.HomeValue
					,t.AwayValue	
			FROM    @tmpAllBettypes s 
				INNER JOIN @tmpResources t
					ON s.SDTResourceId = t.SDTResourceId
			WHERE	s.SDTResourceId IS NOT NULL
			UNION 
			SELECT	s.SDTpfId
					,s.BetType				
					,t.HomeValue
					,t.AwayValue
			FROM	@tmpAllBettypes s
				INNER JOIN @tmpResources t
					ON ISNULL(s.RefResourceId,s.ResourceId) = t.ResourceID
			WHERE	s.SDTResourceId IS NULL
		) t
		WHERE  EXISTS (SELECT TOP 1 1 FROM @tmpAllBettypes b WHERE b.Bettype = t.BetType)
	END

	IF EXISTS (SELECT	TOP 1 1		
							FROM	dbo.bettrans b WITH(NOLOCK)
								INNER JOIN @tmpSettlementBettypeResult s
									ON	b.bettype = s.BetType
										AND b.matchid = @MatchId					
								CROSS APPLY dbo.f_Set_SDT_modds(s.pfID, b.betteam
											,b.hdp1
											, b.hdp2, @hth, @hta, @fth, @fta, s.HomeValue, s.AwayValue, b.livehomescore, b.liveawayscore, b.transdesc
											,CAST(b.betid AS VARCHAR(50)) -- betcheck/betid
											, 0) m
							WHERE	b.matchid = @matchid
									AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
									AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
											AND b.recommend <> 1688156) --exclude betdaq/betfair
									AND b.statusId IN (112, 113)
									AND ISNULL(b.betdaqid,0) <> -2
									AND m.modds IS NOT NULL
									AND b.statusId <>  CASE 
															WHEN m.modds >= 0.5 THEN 112
															WHEN m.modds <= -0.5 THEN 113
															ELSE 0
														END 
	)
	BEGIN
		SELECT @ErrCode = 1001002
	END
	ELSE IF EXISTS (SELECT	TOP 1 1		
							FROM	dbo.bettransm bm WITH(NOLOCK)
								INNER JOIN @tmpSettlementBettypeResult s
									ON	bm.bettype = s.BetType
										AND bm.matchid = @MatchId					
								CROSS APPLY dbo.f_Set_SDT_modds(s.pfID, bm.betteam
											,bm.hdp1
											, bm.hdp2, @hth, @hta, @fth, @fta, s.HomeValue, s.AwayValue, bm.livehomescore, bm.liveawayscore, bm.transdesc
											,CAST(bm.betcheck AS VARCHAR(50)) -- betcheck/betid
											, 0) m
							WHERE	bm.matchid = @matchid
									AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
									--AND (bm.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
									--		AND bm.recommend <> 1688156) --exclude betdaq/betfair
									AND bm.statusId IN (112, 113)									
									AND m.modds IS NOT NULL
									AND bm.statusId <>  CASE 
															WHEN m.modds >= 0.5 THEN 112
															WHEN m.modds <= -0.5 THEN 113
															ELSE 0
														END 
	)
	BEGIN
		SELECT @ErrCode = 1001002
	END

	IF @ErrCode = 1001002
		SET @ErrMsg   = 'Some ''WON''/''LOSE'' tickets settled by instant calculation need to be un-calculated with the score. Please arrange to uncalculate instant calculation with the wrong score first. Then, please try to execute instant calculation again.'
END
GO
