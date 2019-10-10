/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_Parlay_BetRadar] (
	@matchId 			INT
	, @matchdate		SMALLDATETIME
	, @Mode 			VARCHAR(20)
	, @ticketCount		INT = 0 OUTPUT
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
)
AS
/*	Creator: 20161206@Bobby
	Task: #61352 - Apply settle determined for parlay bet types
	DB: DBTXN/BODB02
	ORIGINAL: 

	Revisions:		
		- 20170328@Bobby: #74203 - Update modds alias column
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		
	Param's Explanation:		
		- @Mode: ['ABANDONED-1H', 'ABANDONED-2H']
*/
BEGIN
	SET NOCOUNT ON
	
	--BetRadar result
	DECLARE @IsHT 				BIT
		,@PenaltyShootout		VARCHAR(10)	=''
		,@MatchDecidedMethod	VARCHAR(10)	=''
		,@First10Min1x2			VARCHAR(10)	=''
		,@FirstGoalTime10Min	VARCHAR(10)	=''
		,@FirstGoalTime15Min	VARCHAR(10)	=''
		,@WhoAdvancesNextRound	VARCHAR(10) =''
		,@ExtraTimeandGoal		VARCHAR(10)	=''
		,@ExtraTimeYN			VARCHAR(10) =''	

		,@PlayerSentOff			VARCHAR(10) =''
		,@PlayerSentOff1H		VARCHAR(10) =''
		,@PlayerSentOffHome		VARCHAR(10) =''
		,@PlayerSentOffHome1H	VARCHAR(10) =''
		,@PlayerSentOffAway		VARCHAR(10) =''
		,@PlayerSentOffAway1H	VARCHAR(10) =''
		,@GoalScorerFirst		VARCHAR(10) =''		
			
		,@NextGoal1H			VARCHAR(MAX)=''
		,@NextGoal				VARCHAR(MAX)=''
		,@NextGoalTime15Min		VARCHAR(MAX)=''
		,@ExtraNextGoal			VARCHAR(MAX)=''
		,@GoalScorerAnytime		VARCHAR(MAX)=''
		
		,@FirstGoalMethod		VARCHAR(2) =''
		,@TimeFirstGoal			VARCHAR(10)=''
			
	DECLARE	@tmpResultDetail TABLE(
		 MatchID				INT
		,ResourceID				VARCHAR(20)
		,HomeValue				VARCHAR(20)
		,AwayValue				VARCHAR(20)
		,SettlementStatusID		TINYINT
	)
	
	CREATE TABLE #autoBettypes (bettype SMALLINT, ResourceId VARCHAR(20)) 
	
	SELECT @IsHT			= CASE WHEN @Mode IN ('ABANDONED-1H', 'REFUND') THEN 1 ELSE 0 END
		,@ticketCount		= 0
	
	INSERT INTO #autoBettypes (bettype, ResourceId)
	SELECT f.bettype
		,CASE 
			WHEN f.bettype = 22 THEN CAST('160' AS VARCHAR(20)) + '%'
			ELSE CAST(f.bettype AS VARCHAR(20)) + '%' 
		END AS  ResourceId
	FROM dbo.f_Set_GetGroupBettypes() AS f 
	WHERE f.GroupId 	= 8 
		
	INSERT INTO @tmpResultDetail(
		MatchID
		,ResourceID
		,HomeValue
		,AwayValue
		,SettlementStatusID
	)
	SELECT DISTINCT
		rs.MatchID
		,rs.ResourceID
		,rs.HomeValue
		,rs.AwayValue
		,rs.SettlementStatusID
	FROM DBPRO.bodb02.dbo.ResultDetail rs WITH (NOLOCK)
		INNER JOIN #autoBettypes AS f 
		ON rs.ResourceId LIKE f.ResourceId
		
	WHERE rs.MatchID = @MatchID 
		AND rs.SettlementStatusID = 4 -- Completed
	
	SELECT	 @PenaltyShootout		= ISNULL(MAX(CASE WHEN ResourceID='135' THEN HomeValue ELSE '' END),'')
			,@WhoAdvancesNextRound	= ISNULL(MAX(CASE WHEN ResourceID='168' THEN HomeValue ELSE '' END),'')
			,@ExtraTimeYN			= ISNULL(MAX(CASE WHEN ResourceID='173' THEN HomeValue ELSE '' END),'')
			,@ExtraTimeandGoal		= ISNULL(MAX(CASE WHEN ResourceID='174' THEN HomeValue ELSE '' END),'')
			,@MatchDecidedMethod	= ISNULL(MAX(CASE WHEN ResourceID='175' THEN HomeValue ELSE '' END),'')  
			,@First10Min1x2			= ISNULL(MAX(CASE WHEN ResourceID='176' THEN HomeValue ELSE '' END),'') 
			,@FirstGoalTime10Min	= ISNULL(MAX(CASE WHEN ResourceID='192' THEN HomeValue ELSE '' END),'') 
			,@FirstGoalTime15Min	= ISNULL(MAX(CASE WHEN ResourceID='193' THEN HomeValue ELSE '' END),'')

			,@PlayerSentOff			= ISNULL(MAX(CASE WHEN ResourceID='210' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOff1H		= ISNULL(MAX(CASE WHEN ResourceID='211' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOffHome		= ISNULL(MAX(CASE WHEN ResourceID='212' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOffHome1H	= ISNULL(MAX(CASE WHEN ResourceID='213' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOffAway		= ISNULL(MAX(CASE WHEN ResourceID='214' THEN AwayValue ELSE '' END),'')	--AwayValue 
			,@PlayerSentOffAway1H	= ISNULL(MAX(CASE WHEN ResourceID='215' THEN AwayValue ELSE '' END),'') --AwayValue

			,@GoalScorerFirst		= ISNULL(MAX(CASE WHEN ResourceID='217' THEN HomeValue ELSE '' END),'')
			
			,@FirstGoalMethod		= ISNULL(MAX(CASE WHEN ResourceID='424' THEN HomeValue ELSE '' END),'')
			,@TimeFirstGoal			= ISNULL(MAX(CASE WHEN ResourceID='455' THEN HomeValue ELSE '' END),'')
			
	FROM	@tmpResultDetail
	SELECT @NextGoal				= @NextGoal + CASE WHEN ResourceID LIKE '160__' THEN ResourceID + HomeValue +',' ELSE '' END 
		,@ExtraNextGoal				= @ExtraNextGoal +  CASE WHEN ResourceID LIKE '164__' THEN ResourceID + HomeValue +',' ELSE '' END 
		,@NextGoalTime15Min			= @NextGoalTime15Min + CASE WHEN ResourceID LIKE '169__' THEN ResourceID + HomeValue +',' ELSE '' END 
		,@NextGoal1H				= @NextGoal1H + CASE WHEN ResourceID LIKE '180__' THEN ResourceID + HomeValue +',' ELSE '' END 
		,@GoalScorerAnytime			= @GoalScorerAnytime + CASE WHEN ResourceID LIKE '216__' THEN ISNULL(HomeValue,'') +',' ELSE '' END 
	FROM @tmpResultDetail
	
	
	DECLARE @tempBatch TABLE (refno BIGINT)
	DECLARE @tempRefno TABLE (refno BIGINT)
	DECLARE @batchNo			INT
			,@batchCount		INT
			,@strTicket			VARCHAR(MAX)

	INSERT INTO @tempRefno (refno)
	SELECT bm.refno
	FROM dbo.bettransm bm WITH(NOLOCK)
		INNER JOIN #autoBettypes t ON bm.bettype = t.bettype

	WHERE bm.matchid 	= @matchid
		AND bm.statusID NOT IN (101)

	SELECT @batchNo			= 2000
		, @batchCount		= 0
		, @ticketCount		= 0
	
	--DO settle SDT parlay tickets
	WHILE (1 = 1)
	BEGIN
			
		DELETE @tempBatch
			
		DELETE TOP(@batchNo) t
		OUTPUT DELETED.refno
		INTO @tempBatch(refno)
		FROM @tempRefno t
			
		
		SELECT @batchCount	= @@ROWCOUNT
			,@ticketCount	+= @batchCount
		
		SELECT @strTicket =  CAST(
		(
			SELECT *
			FROM (
				SELECT TOP(@batchNo)
					b.transid AS t
					, b.refno AS r
					, ISNULL(odds.modds, 0) AS m
				FROM @tempBatch ref
					INNER JOIN dbo.bettransm b WITH(NOLOCK) ON ref.refno = b.refno
					OUTER APPLY [dbo].[f_Set_Parlay_SDT_CalModds_BetRadar](
							b.bettype
							, b.betteam
							, b.betcheck
							, @PenaltyShootout
							, @MatchDecidedMethod
							, @First10Min1x2
							, @FirstGoalTime10Min
							, @FirstGoalTime15Min
							, @WhoAdvancesNextRound
							, @ExtraTimeandGoal
							, @ExtraTimeYN

							, @PlayerSentOff
							, @PlayerSentOff1H
							, @PlayerSentOffHome
							, @PlayerSentOffHome1H
							, @PlayerSentOffAway
							, @PlayerSentOffAway1H
							, @GoalScorerFirst
						
							, @NextGoal1H
							, @NextGoal
							, @NextGoalTime15Min
							, @ExtraNextGoal
							, @GoalScorerAnytime
							, @FirstGoalMethod
							, @TimeFirstGoal
							, @IsHT
						)  AS odds
				WHERE b.matchid = @matchid 
			) AS b FOR XML AUTO
		) AS VARCHAR(MAX))
		
		--select @matchid
		--	,@matchdate
		--	,@mode AS mode
		--	,'REFUND' AS [action] 		
		--	,@strTicket AS strTransIds
				
		IF(@strTicket IS NOT NULL)
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_MP_broker 
				@matchid 		= @matchid
				,@matchdate		= @matchdate
				,@mode 			= 'ABANDONED'
				,@action 		= 'REFUND'
				,@strTransIds	= @strTicket
		END
			
		IF(@batchCount < @batchNo) BREAK
	END

	RETURN
	
END
GO

