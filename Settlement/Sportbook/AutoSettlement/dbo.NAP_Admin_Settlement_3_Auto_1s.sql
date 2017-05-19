ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Auto_1s] 
  @MatchID		INT
 ,@ResourceIDs	VARCHAR(MAX)	= '' 
 ,@Mode			VARCHAR(6)		= 'CAL'
AS
/*	Creator: Jamie
	Date: 20150205
	Task: BetRadar Auto/Manual Settlement
	DB: DBTXN/BODB02
	Original: 
	
	Revisions:
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]

	Param's Explanation:
*/	
BEGIN
	SET NOCOUNT ON 
	DECLARE	@strBettypes				VARCHAR(MAX)

			,@penaltyshootout		VARCHAR(10)	=''
			,@matchDecidedMethod	VARCHAR(10)	=''
			,@1st10Min1x2			VARCHAR(10)	=''
			,@1stGoalTime10Min		VARCHAR(10)	=''
			,@1stGoalTime15Min		VARCHAR(10)	=''
			,@WhoAdvancesNextRound	VARCHAR(10) =''
			,@ExtraTimeandGoal		VARCHAR(10)	=''
			,@ExtraTimeYN			VARCHAR(10) =''	

			,@PlayerSentOff			VARCHAR(10) =''
			,@HTPlayerSentOff		VARCHAR(10) =''
			,@PlayerSentOffHome		VARCHAR(10) =''
			,@HTPlayerSentOffHome	VARCHAR(10) =''
			,@PlayerSentOffAway		VARCHAR(10) =''
			,@HTPlayerSentOffAway	VARCHAR(10) =''
			,@GoalScorerFirst		VARCHAR(10) =''		
				
			,@1HNextGoal			VARCHAR(MAX)=''
			,@NextGoal				VARCHAR(MAX)=''
			,@NextGoalTime15Min		VARCHAR(MAX)=''
			,@ExtraNextGoal			VARCHAR(MAX)=''
			,@GoalScorerAnytime		VARCHAR(MAX)=''
			
			,@FirstGoalMethod		VARCHAR(2) =''

	DECLARE	@tmpResourceIDs TABLE(
		ResourceID	VARCHAR(20)
		,Bettype	INT
	)
	INSERT INTO @tmpResourceIDs(ResourceID,Bettype)
	SELECT val, CAST(LEFT(val,3) AS INT) FROM strSplit(@ResourceIDs,',')

	DECLARE	@tmpResultDetail TABLE(
		 MatchID			INT
		,ResourceID			VARCHAR(20)
		,HomeValue			VARCHAR(20)
		,AwayValue			VARCHAR(20)
		,SettlementStatusID	TINYINT
	)
	INSERT INTO @tmpResultDetail(
		MatchID
		,ResourceID
		,HomeValue
		,AwayValue
		,SettlementStatusID
	)
	SELECT	 MatchID
			,ResourceID
			,HomeValue
			,AwayValue
			,SettlementStatusID
	FROM	DBPRO.bodb02.dbo.ResultDetail WITH (NOLOCK)
	WHERE	MatchID = @MatchID 
			AND ResourceID IN (SELECT ResourceID FROM @tmpResourceIDs)
			AND SettlementStatusID = 4 
	
	;WITH cteBettypes
	AS(
		SELECT	BetType
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	GroupId = 8
	)
	SELECT	@strBettypes = COALESCE(@strBettypes + ',' + CAST(b.bettype AS VARCHAR(10)),CAST(b.bettype AS VARCHAR(10)))
	FROM	(
		SELECT	b.bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchId
				AND b.statusID NOT BETWEEN 101 AND 102
		GROUP BY b.bettype
	)b
	WHERE	b.bettype IN (SELECT bettype FROM cteBettypes)
			AND b.bettype IN (SELECT Bettype FROM @tmpResourceIDs)

	SELECT	 @penaltyshootout		= ISNULL(MAX(CASE WHEN ResourceID='135' THEN HomeValue ELSE '' END),'')
			,@WhoAdvancesNextRound	= ISNULL(MAX(CASE WHEN ResourceID='168' THEN HomeValue ELSE '' END),'')
			,@ExtraTimeYN			= ISNULL(MAX(CASE WHEN ResourceID='173' THEN HomeValue ELSE '' END),'')
			,@ExtraTimeandGoal		= ISNULL(MAX(CASE WHEN ResourceID='174' THEN HomeValue ELSE '' END),'')
			,@matchDecidedMethod	= ISNULL(MAX(CASE WHEN ResourceID='175' THEN HomeValue ELSE '' END),'')  
			,@1st10Min1x2			= ISNULL(MAX(CASE WHEN ResourceID='176' THEN HomeValue ELSE '' END),'') 
			,@1stGoalTime10Min		= ISNULL(MAX(CASE WHEN ResourceID='192' THEN HomeValue ELSE '' END),'') 
			,@1stGoalTime15Min		= ISNULL(MAX(CASE WHEN ResourceID='193' THEN HomeValue ELSE '' END),'')

			,@PlayerSentOff			= ISNULL(MAX(CASE WHEN ResourceID='210' THEN HomeValue ELSE '' END),'')
			,@HTPlayerSentOff		= ISNULL(MAX(CASE WHEN ResourceID='211' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOffHome		= ISNULL(MAX(CASE WHEN ResourceID='212' THEN HomeValue ELSE '' END),'')
			,@HTPlayerSentOffHome	= ISNULL(MAX(CASE WHEN ResourceID='213' THEN HomeValue ELSE '' END),'')
			,@PlayerSentOffAway		= ISNULL(MAX(CASE WHEN ResourceID='214' THEN AwayValue ELSE '' END),'')	--AwayValue 
			,@HTPlayerSentOffAway	= ISNULL(MAX(CASE WHEN ResourceID='215' THEN AwayValue ELSE '' END),'') --AwayValue

			,@GoalScorerFirst		= ISNULL(MAX(CASE WHEN ResourceID='217' THEN HomeValue ELSE '' END),'')
			,@FirstGoalMethod		= ISNULL(MAX(CASE WHEN ResourceID='424' THEN HomeValue ELSE '' END),'')
	FROM	@tmpResultDetail
	WHERE	MatchID = @MatchID 
			AND ResourceID IN (SELECT ResourceID FROM @tmpResourceIDs)
	
	SELECT	 @NextGoal				= @NextGoal + CASE WHEN ResourceID LIKE '160__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@ExtraNextGoal			= @ExtraNextGoal +  CASE WHEN ResourceID LIKE '164__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@NextGoalTime15Min		= @NextGoalTime15Min + CASE WHEN ResourceID LIKE '169__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@1HNextGoal			= @1HNextGoal + CASE WHEN ResourceID LIKE '180__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@GoalScorerAnytime		= @GoalScorerAnytime + CASE WHEN ResourceID LIKE '216__' THEN ISNULL(HomeValue,'') +',' ELSE '' END 
	FROM	@tmpResultDetail
	WHERE	MatchID = @MatchID 
			AND ResourceID IN (SELECT ResourceID FROM @tmpResourceIDs)
	
	EXEC dbo.NAP_Admin_Calculate_Main
				 @matchid				= @matchid
				,@action				= 'CAL-AUTO'
				,@mode					= 'CAL'
				,@ResourceIDs			= @ResourceIDs
				,@penaltyshootout		= @penaltyshootout
				,@matchDecidedMethod	= @matchDecidedMethod
				,@1st10Min1x2			= @1st10Min1x2
				,@1stGoalTime10Min		= @1stGoalTime10Min
				,@1stGoalTime15Min		= @1stGoalTime15Min
				,@WhoAdvancesNextRound	= @WhoAdvancesNextRound
				,@ExtraTimeandGoal		= @ExtraTimeandGoal	
				,@ExtraTimeYN			= @ExtraTimeYN
				,@NextGoal				= @NextGoal
				,@ExtraNextGoal			= @ExtraNextGoal
				,@NextGoalTime15Min		= @NextGoalTime15Min
				,@1HNextGoal			= @1HNextGoal
				,@PlayerSentOff			= @PlayerSentOff
				,@HTPlayerSentOff		= @HTPlayerSentOff
				,@PlayerSentOffHome		= @PlayerSentOffHome
				,@HTPlayerSentOffHome	= @HTPlayerSentOffHome
				,@PlayerSentOffAway		= @PlayerSentOffAway
				,@HTPlayerSentOffAway	= @HTPlayerSentOffAway
				,@GoalScorerAnytime		= @GoalScorerAnytime
				,@GoalScorerFirst		= @GoalScorerFirst
				,@FirstGoalMethod		= @FirstGoalMethod
				,@strBettypes			= @strBettypes
				,@CalledByBrokerService = 0	

END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_3_Auto_1s] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_3_Auto_1s] TO [vnteam] AS [dbo]