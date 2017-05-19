ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_2_Auto_1s] 
  @MatchID				INT
 ,@penaltyshootout		VARCHAR(10)	='' OUTPUT 
 ,@matchDecidedMethod	VARCHAR(10)	='' OUTPUT
 ,@1st10Min1x2			VARCHAR(10)	='' OUTPUT
 ,@1stGoalTime10Min		VARCHAR(10)	='' OUTPUT
 ,@1stGoalTime15Min		VARCHAR(10)	='' OUTPUT
 ,@WhoAdvancesNextRound	VARCHAR(10) ='' OUTPUT
 ,@ExtraTimeandGoal		VARCHAR(10)	='' OUTPUT
 ,@ExtraTimeYN			VARCHAR(10) =''	OUTPUT

 ,@PlayerSentOff		VARCHAR(10) ='' OUTPUT
 ,@HTPlayerSentOff		VARCHAR(10) ='' OUTPUT
 ,@PlayerSentOffHome	VARCHAR(10) ='' OUTPUT
 ,@HTPlayerSentOffHome	VARCHAR(10) ='' OUTPUT
 ,@PlayerSentOffAway	VARCHAR(10) ='' OUTPUT
 ,@HTPlayerSentOffAway	VARCHAR(10) ='' OUTPUT
 ,@GoalScorerFirst		VARCHAR(10) =''	OUTPUT	
				
 ,@1HNextGoal			VARCHAR(MAX)='' OUTPUT
 ,@NextGoal				VARCHAR(MAX)='' OUTPUT
 ,@NextGoalTime15Min	VARCHAR(MAX)='' OUTPUT
 ,@ExtraNextGoal		VARCHAR(MAX)='' OUTPUT
 ,@GoalScorerAnytime	VARCHAR(MAX)='' OUTPUT
 ,@ResourceIDsCAL		VARCHAR(MAX)= '' OUTPUT
 ,@ResourceIDsREFUND	VARCHAR(MAX)= '' OUTPUT
 ,@ResourceIDs			VARCHAR(MAX)= '' 
 ,@Mode					VARCHAR(6)	= 'CAL'
AS
/*	Creator: Jamie
	Date: 20150205
	Task: BetRadar Auto/Manual Settlement
	DB: DBTXN/BODB02
	Original: 
	
	Revisions:

	Param's Explanation:
*/	
BEGIN
	SET NOCOUNT ON 

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
			AND SettlementStatusID > 0
			AND ResultStatusID IN (2,5)  
			AND( ResourceID IN ('135','168','192','193','217')
								OR ResourceID LIKE '17[3-6]'
								OR ResourceID LIKE '21[0-5]'
								OR ResourceID LIKE '160__'
								OR ResourceID LIKE '164__'
								OR ResourceID LIKE '169__'
								OR ResourceID LIKE '180__'
								OR ResourceID LIKE '216__'
						)

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
	FROM	@tmpResultDetail
	WHERE	MatchID = @MatchID 
			AND SettlementStatusID = 4 
	
	SELECT	 @NextGoal				= @NextGoal + CASE WHEN ResourceID LIKE '160__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@ExtraNextGoal			= @ExtraNextGoal +  CASE WHEN ResourceID LIKE '164__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@NextGoalTime15Min		= @NextGoalTime15Min + CASE WHEN ResourceID LIKE '169__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@1HNextGoal			= @1HNextGoal + CASE WHEN ResourceID LIKE '180__' THEN ResourceID + HomeValue +',' ELSE '' END 
			,@GoalScorerAnytime		= @GoalScorerAnytime + CASE WHEN ResourceID LIKE '216__' THEN ISNULL(HomeValue,'') +',' ELSE '' END 
	FROM	@tmpResultDetail
	WHERE	MatchID = @MatchID 
			AND SettlementStatusID = 4

		---- Get Set/Match
	SELECT	 @ResourceIDsCAL	= @ResourceIDsCAL + CASE WHEN SettlementStatusID = 4 THEN ResourceID +',' 
														 ELSE '' END		
			,@ResourceIDsREFUND = @ResourceIDsREFUND + CASE WHEN SettlementStatusID BETWEEN 1 AND 3 THEN ResourceID + ',' 
															ELSE '' END											
	FROM	@tmpResultDetail

END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_2_Auto_1s] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_2_Auto_1s] TO [vnteam] AS [dbo]