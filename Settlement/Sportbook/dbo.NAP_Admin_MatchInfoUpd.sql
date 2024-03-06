/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_MatchInfoUpd
	@MatchId			INT
	,@Action			VARCHAR(20)
	,@Mode				VARCHAR(20)		= NULL
	,@FullTimeHome		SMALLINT        = NULL
    ,@FullTimeAway		SMALLINT        = NULL
    ,@HalfTimeHome		SMALLINT        = NULL
    ,@HalfTimeAway		SMALLINT        = NULL 
	,@GoalRecord		VARCHAR(50)     = NULL
    ,@BetStatus			NVARCHAR(50)    = NULL
	,@ResourceResult	VARCHAR(MAX)	= NULL
	,@SDTRecord			TINYINT = NULL
	,@SelectedResources	VARCHAR(MAX)	= NULL
	,@Results			VARCHAR(MAX)	= NULL -- FM
	,@EventCounters		VARCHAR(MAX)	= NULL -- FM
	,@IsSettleDetermined	BIT			= 0    -- FM
	,@SelectedMarket	VARCHAR(MAX)	= NULL -- BB
	,@SelectedSelection	VARCHAR(MAX)	= NULL -- BB
	,@IsDirectly		BIT				= 0
	,@IsAuto			BIT				= 0
	,@IsHTTicketSettled BIT				= 0
	,@AdminId			INT
	,@DeterminedType	TINYINT			= 0
AS
/*
    Created: 20220719@Kathy
    Task : Update match info 

    Revisions:
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20220927@Kathy: Check HTDone [Redmine:#178120]
		- 20221011@Kathy: fix issue basketball - do not upd match_remark.IsHTCal
		- 20230215@Aries: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
		- 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
		- 20230515@Aries: Apply Settle Determined for Basketball [Redmine:#175202]
		- 20230515@Aries: Apply Settle Instant for Basketball [Redmine:#184124]
		- 20231002@Louisa: Integrate sporttype 58-Bandy [Redmine: #196041]
		- 20240510@Aries: Enhance SOP-Refund for Soccer's Early results [Redmine:#201462]

	Param's Explanation:
		@Action: CAL, CAL-FT, CAL-HT, REFUND, REFUND-FT, REFUND-HT, UNDO, CAL_EAR, REFUND_EAR, UNDO_EAR, 'CAL-INST-HT', 'CAL-INST-FT' 'UNDO-INST-FT', 'UNDO-INST-HT'
		@Mode: FM, BB, MP

		@SelectedMarket: <Resources>
				            <rsc m="1"/>
				            <rsc m="2"/>
				            <rsc m="3"/>
				            <rsc m="4"/>
				            <rsc m="5"/>
				         </Resources>

		@SelectedSelection: <Resources>
								<Resource Id="200" Result="WON"/>
								<Resource Id="201" Result="WON"/>
								<Resource Id="202" Result="WON"/>
								<Resource Id="203" Result="REFUND"/>
								<Resource Id="204" Result="LOSE"/>
						   </Resources>

*/
BEGIN
	DECLARE @eventstatus	NVARCHAR(50)
			,@matchcode		NVARCHAR(50)
			,@HTDone		BIT
			,@SportType		SMALLINT
			,@ChildMatchType TINYINT
			,@calCommand	VARCHAR(100)
			,@refundCommand VARCHAR(100)
			,@undoCommand	VARCHAR(100)
			,@refundCommand_1s VARCHAR(100)
			,@instcommand	VARCHAR(100)
			,@IsRefundHT	BIT
			,@ResultTable	TINYINT
			,@existsFinalRound	BIT
			,@existsHTRound BIT
			,@LeagueGroupID SMALLINT
			,@handle	INT
			,@ResultStatusID TINYINT
			,@xmlResults XML
			,@xmlEventCounter XML
			,@parlaycommand VARCHAR(1)
			,@remarkCommand VARCHAR(100)
			,@cornerCommand VARCHAR(100)
			,@undoResultDetailCommand	VARCHAR(100)
			,@IsResultHTCal	BIT

	DECLARE @tmpSelectedRID TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50))
	
	SELECT @HTDone = 0

	SELECT	@SportType = m.sporttype
			,@eventstatus = m.eventstatus
			,@matchcode = m.matchcode
			,@ChildMatchType = ChildMatchType
			,@LeagueGroupID = ISNULL(l.LeagueGroupID, 0)
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE	m.matchid = @MatchId

	SELECT	@ResultTable = ResultTable
	FROM	dbo.SettlementResultTableSetting s WITH(NOLOCK)
	WHERE	s.Sporttype = @SportType

	IF @SportType = 1
	BEGIN
		SELECT	@HTDone = CASE WHEN r.ResultStatusID = 5 THEN 1 ELSE 0 END
				,@IsRefundHT = CASE WHEN r.SettlementStatusID = 2 THEN 1 ELSE 0 END
				,@IsResultHTCal = CASE WHEN r.SettlementStatusID = 4 THEN 1 ELSE 0 END
		FROM	dbo.ResultDetail r WITH(NOLOCK)
		WHERE	r.MatchID = @MatchId
				AND r.ResourceID = '01'
	END
	ELSE IF @ResultTable = 0
	BEGIN			
		SELECT	@HTDone = @IsHTTicketSettled
	END

	IF @SelectedResources IS NOT NULL
	BEGIN
		EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpSelectedRID(ResourceID, HomeValue, AwayValue)
		SELECT Id, Home, Away
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle

		SET @existsFinalRound = 0
  		SELECT TOP 1 @existsFinalRound = 1
			,@FullTimeHome = HomeValue
			,@FullTimeAway = AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '00'

  		SET @existsHTRound = 0
  		SELECT TOP 1 @existsHTRound = 1		
			,@HalfTimeHome = HomeValue
			,@HalfTimeAway = AwayValue
  		FROM @tmpSelectedRID sr
  		WHERE sr.ResourceID = '01' 
			AND 1 = CASE 
						WHEN @sportType IN ( 2, 58) THEN 1
						WHEN @sportType = 1 AND @LeagueGroupID = 113 THEN 1---PinGoal
						ELSE 0
					END

		IF @existsHTRound = 1 
		BEGIN
			SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
		END
			
  		IF @existsFinalRound = 1
  		BEGIN
	  		SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
					,@FullTimeHome   = COALESCE (@FullTimeHome, 0)
					,@FullTimeAway   = COALESCE (@FullTimeAway, 0)
		END
	END

	IF @Mode = 'FM'
	BEGIN				
		SET @xmlResults = CONVERT(XML, @Results)
		SET @xmlEventCounter = CONVERT(XML, @EventCounters)

		;WITH cteInputResults AS (
			SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
				,X.C.value('@Position','TINYINT') as Position
				,X.C.value('@Result','TINYINT') as BetOption
			FROM @xmlResults.nodes('/BetTypes/BetType') AS T(C)
				CROSS APPLY
					C.nodes('Item') AS X(C)
		)
		SELECT @Results = CAST((
					SELECT bettype '@Id'
						,(SELECT Position '@p'
								,BetOption '@r'
								,CASE WHEN r.bettype = 229 THEN 0 ELSE @IsSettleDetermined END AS '@s'
								,CASE WHEN r.bettype IN (228, 229) THEN 1 ELSE NULL END AS '@i' -- HasInjuryTime
							FROM cteInputResults WHERE r.bettype = bettype FOR XML PATH('r'), TYPE)
					FROM cteInputResults r
					GROUP BY r.bettype
					FOR XML PATH('b'), ROOT ('r'), TYPE
				) AS VARCHAR(MAX))		

		;WITH cteEventCounter
		AS (
			SELECT T.C.value('@Id', 'VARCHAR(20)') AS 'Id'
				,X.C.value('@Position','TINYINT') AS Position
				,X.C.value('@Result','TINYINT') AS Result
			FROM	@xmlEventCounter.nodes('/EventCounters/EventCounter') AS T(C)
				CROSS APPLY C.nodes('Item') AS X(C)
		)
		SELECT @EventCounters = CAST((SELECT   Id '@Id'
				,(	SELECT	Position AS '@p'
							,Result AS '@r'
					FROM	cteEventCounter 
					WHERE	Id = c.Id 
					FOR XML PATH('r'), TYPE)
		FROM	cteEventCounter c
		GROUP BY Id
		FOR XML PATH('e'), ROOT('r'), TYPE)  AS VARCHAR(MAX))

		EXEC dbo.NAP_Set_FastMarket_ResultDetailUpd @MatchId = @MatchId
			,@Results = @Results
			,@EventCounters = @EventCounters
			,@Action = @Action
			,@IsAuto = @IsAuto
			,@AdminId = @AdminId	
	
		RETURN
	END

	IF @Mode = 'BB'
	BEGIN
		SET @ResultStatusID = CASE 
						WHEN @Action = 'UNDO' THEN 3	--undo
						WHEN @IsAuto = 1 THEN 2 		--auto cal
						ELSE 5 END 						--manual cal

		EXEC dbo.NAP_Admin_SMPMarket_Update 
			@matchID 			= @matchID
			,@VendorID			= 34
			,@action			= @action
			,@SelectedMarket 	= @SelectedMarket
			,@resultStatusID 	= @ResultStatusID
			,@mode				= 'ResultStatusID'

		EXEC dbo.NAP_Admin_SMPMarketSelection_Update 
			@matchID 			= @matchID
			,@action			= @action
			,@SelectedMarket	= @SelectedMarket
			,@SelectedSelection	= @SelectedSelection
			,@resultStatusID 	= @ResultStatusID

		IF @IsAuto = 0
			EXEC dbo.NAP_Admin_SMPMarket_Update 
				@matchID 			= @matchID
				,@action			= @action
				,@SelectedMarket	= @SelectedMarket
				,@resultStatusID 	= @ResultStatusID

		RETURN
	END

	IF @Action LIKE '%INST%' AND  @ResourceResult IS NOT NULL	
	BEGIN
		SET @instcommand = CASE 
								WHEN @Action LIKE 'CAL%' THEN 'CalByResourceId'
								WHEN @Action LIKE 'UNDO%' THEN 'UndoByResouceId'
								ELSE ''
							END

		EXEC dbo.NAP_Admin_Result_Update_1s
			@Command        = @instcommand,
			@MatchID        = @MatchID,                  
			@ResourceResult	= @ResourceResult,                    
			@creator        = @AdminId

		EXEC dbo.NAP_Admin_Match_Update 
			@Command         = 'instant'
			,@MatchID        = @matchid
			,@creator        = @AdminId
			,@BetStatus 	 = @betstatus

		RETURN
	END

	IF @Action LIKE 'CAL%' 
	BEGIN
		IF (@SportType = 1 AND @LeagueGroupID <> 113 AND @SelectedResources IS NULL) -- soccer main
			OR (@SportType = 1 AND @LeagueGroupID = 113 AND @SelectedResources IS NULL) -- cal soccer pingoal manually
			OR @ResultTable = 0
		BEGIN
			SELECT	@eventstatus = CASE 
										WHEN @action = 'CAL' THEN N'completed'
										WHEN @action = 'CAL-HT' AND @matchcode LIKE '%hedge%' THEN @eventstatus -- Jamie@20120330: Not change eventstatus='completed' for Hedge Match although 
										WHEN @action = 'CAL-FT' AND @HTDone = 1 THEN N'completed'
										ELSE @eventstatus
										END			
			
			SET @calCommand = 'NAP_Admin_Settlement_1-CAL'

			EXEC dbo.NAP_Admin_Match_Update 
				@Command            = @calCommand
				,@MatchID           = @matchid
				,@FTHome            = @FullTimeHome
				,@FTAway            = @FullTimeAway
				,@HTHome            = @HalfTimeHome
				,@HTAway            = @HalfTimeAway
				,@BetStatus         = @BetStatus
				,@GoalRecord        = @GoalRecord              
				,@Action            = @Action
				,@HTDone            = @HTDone
				,@creator           = @AdminId
	
			IF @eventstatus = 'completed' AND ISNULL(@BetStatus,'') NOT LIKE '%Refund;%' AND ISNULL(@BetStatus,'') NOT LIKE '%Refund FT;%' AND ISNULL(@BetStatus,'') NOT LIKE '%Abandoned%' 
			BEGIN
				EXEC dbo.NAP_updateMatch_remark 
					@matchid    = @matchid
					,@command    = 'C'                
			END
			ELSE IF (@action = 'CAL-HT')
			BEGIN
				EXEC dbo.NAP_updateMatch_remark 
					@matchid    = @matchid
					,@command    = 'H'
			END

			IF @SportType = 1
			BEGIN
				EXEC dbo.NAP_Admin_Result_Update_1s
					@Command         = @calCommand,
					@MatchID         = @MatchID,
					@fth             = @FullTimeHome,
					@fta             = @FullTimeAway,
					@hth             = @HalfTimeHome,
					@hta             = @HalfTimeAway,
					@ResourceResult	 = @ResourceResult,
					@Action          = @Action,
					@IsAuto          = 0,
					@creator		 = @AdminId
			END
		END
		ELSE IF @SportType = 1 AND @SelectedResources IS NOT NULL AND @existsFinalRound = 0 AND @existsHTRound = 0 -- early settlement
		BEGIN
			SELECT @calCommand = 'NAP_Admin_Settlement_Auto_1s-CAL'

			EXEC dbo.NAP_Admin_Result_Update_1s 
				@Command            = @calCommand,
				@MatchID            = @MatchID,
				@SelectedResources	= @SelectedResources,
				@creator            = @AdminID
		END
		ELSE -- profile
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update
					@Command				= 'profile'
					,@Action				= 'CAL'
					,@MatchID				= @matchid
					,@FTHome				= @FullTimeHome
					,@FTAway				= @FullTimeAway
					,@HTHome				= @HalfTimeHome
					,@HTAway				= @HalfTimeAway
					,@creator				= @AdminId
					,@IsFinalRound			= @existsFinalRound
					,@IsHTRound				= @existsHTRound
					,@BetStatus				= @BetStatus
			
			IF @existsHTRound = 1
			BEGIN				 
				EXEC dbo.NAP_updateMatch_remark 
						@matchid    = @matchid
						,@command    = 'H'
			END

			IF  @existsFinalRound = 1
			BEGIN				 
				EXEC dbo.NAP_updateMatch_remark
							@matchid				= @matchid
							,@command				= 'C'
			END			

			EXEC dbo.NAP_Admin_Result_Update_9001
				@action					= 'CAL'
				,@MatchID				= @MatchID
				,@creator				= @AdminId
				,@Sporttype				= @Sporttype
				,@SelectedRID   		= @SelectedResources
				,@IsDirectly			= @IsDirectly
				,@IsAuto				= @IsAuto
		END
	END
	ELSE IF @Action LIKE 'UNDO%'
	BEGIN
		IF (@SportType = 1 AND @LeagueGroupID <> 113 AND @SelectedResources IS NULL)
			OR (@SportType = 1 AND @LeagueGroupID = 113 AND @SelectedResources IS NULL) -- cal pingoal manually
			OR @ResultTable = 0
		BEGIN
			SELECT @undoCommand =	CASE WHEN @Action = 'UNDO' THEN 'NAP_Admin_Settlement_1-UNDO'
										 WHEN @Action = 'UNDO-FT' THEN 'NAP_Admin_Settlement_1-UNDO-FT'									
									END
			SELECT @remarkCommand = CASE WHEN @Action = 'UNDO' THEN 'U'
										 WHEN @Action = 'UNDO-FT' THEN 'UF'									
									END
			
			SELECT @cornerCommand = CASE WHEN @Action = 'UNDO' THEN 'NAP_Admin_Settlement_1-Corner-UNDO'
										 WHEN @Action = 'UNDO-FT' THEN 'NAP_Admin_Settlement_1-Corner-UNDO-FT'									
									END

			SELECT @undoResultDetailCommand =	CASE WHEN @Action = 'UNDO' THEN 'NAP_Admin_Settlement_1-UNDO'
													 WHEN @Action = 'UNDO-FT' THEN 'UndoByResouceId'									
												END
									

			EXEC dbo.NAP_Admin_Match_Update 
				@Command        = @undoCommand
				,@MatchID       = @matchid
				,@betstatus     = @betstatus 
				,@GoalRecord	 = @GoalRecord
				,@creator       = @AdminId

			EXEC dbo.NAP_UpdateMatch_Remark 
				@matchid        = @matchid
				,@command        = @remarkCommand
				,@IsRefundHT	 = @IsRefundHT	
				,@IsResultHTCal  = @IsResultHTCal
        
			IF @SportType <> 1 -- update parlay
			BEGIN
				EXEC dbo.NAP_Admin_Match_Update @Command = 'NAP_Admin_Settlement_Parlay'
					,@Matchid = @matchid
					,@creator = @AdminId
			END
		
			IF @SportType = 1-- Soccer
			BEGIN
				IF @ChildMatchType = 204 -- Corner
				BEGIN
					EXEC dbo.NAP_Admin_Result_Update_1s 
						@Command            = @cornerCommand,
						@MatchID            = @MatchID,
						@creator            = @AdminId 
				END
				ELSE
				BEGIN
					EXEC dbo.NAP_Admin_Result_Update_1s 
						@Command            = @undoResultDetailCommand,
						@MatchID            = @MatchID,
						@ResourceResult		= @ResourceResult,
						@creator            = @AdminId 
				END

				EXEC dbo.NAP_Set_AutoPayoutResultUpd 
					@MatchId = @matchid
					,@TypeId = NULL
					,@StatusId = NULL 
					,@IsUndoMatch = 1 --Clear data in table AutoPayoutResult if match has been undo

			END   
		END
		ELSE IF @SportType = 1 AND @SelectedResources IS NOT NULL -- early settlement
		BEGIN
			SELECT @undoCommand = 'NAP_Admin_Settlement_Auto_1s-UNDO'

			EXEC dbo.NAP_Admin_Result_Update_1s 
				@Command            = @undoCommand,
				@MatchID            = @MatchID,
				@SelectedResources	= @SelectedResources,
				@creator            = @AdminID

		END
		ELSE -- profile
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update
				@Command			='profile'
				,@Action			='UNDO'
				,@MatchID			= @matchid
				,@creator			= @AdminId
				,@IsFinalRound		= @existsFinalRound
				,@IsHTRound			= @existsHTRound
				,@BetStatus			= @BetStatus
			
			IF @existsHTRound = 1
			BEGIN
				EXEC dbo.NAP_updateMatch_remark
					@matchid			= @matchid
					,@command			= 'U'							
					,@IsHTRound			= @existsHTRound
			END

			IF @existsFinalRound = 1
			BEGIN
				EXEC dbo.NAP_updateMatch_remark
					@matchid			= @matchid
					,@command			= 'U'
					,@IsFinalRound		= @existsFinalRound
					,@IsHTRound			= @existsHTRound
			END
			
			EXEC dbo.NAP_Admin_Result_Update_9001
				@action  			= 'UNDO'
				,@matchid 			= @MatchId
				,@SelectedRID   	= @SelectedResources
				,@Sporttype			= @Sporttype
				,@creator 			= @AdminId	
			
			IF @SportType = 2
			BEGIN
				EXEC dbo.NAP_Set_AutoPayoutResultUpd 
						@MatchId = @matchid
						,@TypeId = NULL
						,@StatusId = NULL 
						,@IsUndoMatch = 1 
						,@SportType = @SportType
						,@SelectedResources = @SelectedResources
			END 
		END
	END
	ELSE IF @Action LIKE 'REFUND%'
	BEGIN
		SELECT @refundCommand = CASE 
									WHEN @Action = 'REFUND' OR (@IsRefundHT = 1 AND @Action = 'REFUND-FT') THEN 'NAP_Admin_Settlement_Refund-All'
									WHEN @Action = 'REFUND-HT' THEN 'NAP_Admin_Settlement_Refund-HT'
									WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_Refund-FT'									
								END
		
		IF (@SportType = 1 AND @SelectedResources IS NULL) -- cal soccer/pingoal soccer manually
		BEGIN
			SELECT @refundCommand_1s =  @refundCommand

			IF @SDTRecord & 4 > 0
			BEGIN
				SET @refundCommand = @refundCommand + '-Abandoned'
				SET @refundCommand_1s = CASE 
											WHEN @Action = 'REFUND-FT' THEN 'NAP_Admin_Settlement_RefundFT-Abandoned' 
											ELSE @refundCommand
										END
			END

			SELECT @HTDone = CASE 
							WHEN @Action = 'REFUND' THEN 1						
							WHEN @Action = 'REFUND-FT' AND @HTDone = 1 THEN 1 
							ELSE 0 END

			EXEC dbo.NAP_Admin_Match_Update 
				@Command         = @refundCommand
				,@MatchID        = @matchid
				,@creator        = @AdminId
				,@BetStatus 	 = @betstatus
				,@GoalRecord	 = @GoalRecord 
				,@HTHome		 = @HalfTimeHome
				,@HTAway		 = @HalfTimeAway
				,@FTHome		 = @FullTimeHome
				,@FTAway		 = @FullTimeAway
				,@HTDone		 = @HTDone
			
			EXEC dbo.NAP_updateMatch_remark 
				@matchid       = @matchid
				,@command      = 'F'		

			EXEC dbo.[NAP_Admin_Result_Update_1s] 
				@Command        = @refundCommand_1s
				,@MatchID       = @matchid
				,@creator       = @AdminId
				,@SDTRecord		= @SDTRecord
				,@fth			= @FullTimeHome
				,@fta			= @FullTimeAway
				,@hth			= @HalfTimeHome
				,@hta			= @HalfTimeAway
				,@ResourceResult = @ResourceResult
				,@Action        = @Action
		END
		ELSE IF @SportType = 1 AND @LeagueGroupID <> 113 AND @SelectedResources IS NOT NULL -- early settlement 
		BEGIN
			SELECT @refundCommand = 'NAP_Admin_Settlement_Auto_1s-REFUND'

			EXEC dbo.NAP_Admin_Result_Update_1s 
				@Command            = @refundCommand,
				@MatchID            = @MatchID,
				@SelectedResources	= @SelectedResources,
				@creator            = @AdminID

		END
		ELSE IF @ResultTable = 0
		BEGIN
			EXEC dbo.NAP_Admin_Match_Update 
				@Command 	= @refundCommand 
				,@MatchID 	= @matchid		
				,@creator 	= @adminid
				,@HTDone	= @HTDone
				,@BetStatus = @betstatus	
				
			EXEC dbo.NAP_updateMatch_remark 
				@matchid    = @matchid
				,@command   = 'F'

		END
		ELSE -- profile
		BEGIN
			SELECT  @HalfTimeHome	= COALESCE (@HalfTimeHome, 0)
					,@HalfTimeAway   = COALESCE (@HalfTimeAway, 0)
					,@FullTimeHome   = COALESCE (@FullTimeHome, 0)
					,@FullTimeAway   = COALESCE (@FullTimeAway, 0)

			EXEC dbo.NAP_Admin_Match_Update
							@matchid			= @matchid
							,@command			= 'profile'
							,@Action			= 'REFUND'
							,@FTHome			= @FullTimeHome
							,@FTAway			= @FullTimeAway
							,@HTHome			= @HalfTimeHome
							,@HTAway			= @HalfTimeAway
							,@IsFinalRound  	= @existsFinalRound
							,@IsHTRound			= @existsHTRound
							,@BetStatus			= @BetStatus
							
			EXEC dbo.NAP_Admin_Result_Update_9001
							@action				= 'REFUND'
							,@MatchID			= @MatchID
							,@creator			= @AdminId
							,@Sporttype			= @Sporttype
							,@SelectedRID   	= @SelectedResources
							,@IsAuto			= @IsAuto
							,@DeterminedType	= @DeterminedType
							
			IF  @existsFinalRound = 1 OR @existsHTRound = 1
			BEGIN
					EXEC dbo.NAP_updateMatch_remark
						@matchid			= @matchid
						,@command			= 'F'
						,@IsFinalRound		= @existsFinalRound
						,@IsHTRound         = @existsHTRound

			END

			IF @SportType = 2
			BEGIN
				EXEC dbo.NAP_Set_AutoPayoutResultUpd 
						@MatchId = @matchid
						,@TypeId = NULL
						,@StatusId = NULL 
						,@IsUndoMatch = 1 
						,@SportType = @SportType
						,@SelectedResources = @SelectedResources
			END 
		END
	END
END
