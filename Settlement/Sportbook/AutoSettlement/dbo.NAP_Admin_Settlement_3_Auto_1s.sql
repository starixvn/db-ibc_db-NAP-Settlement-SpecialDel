/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Auto_1s] 
	@MatchID				INT
	,@SelectedResources		VARCHAR(MAX)
	,@Mode					VARCHAR(6)		= 'CAL'
	,@IsReSettledTickets	BIT		= 1
AS
/*	Creator: Jamie
	Date: 20150205
	Task: BetRadar Auto/Manual Settlement
	DB: DBTXN/BODB02
	Original: 
	
	Revisions:
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]

	Param's Explanation:
*/	
BEGIN
	SET NOCOUNT ON 

	DECLARE	@strBettypes			VARCHAR(MAX)	
			,@xmlSelectedResources	XML
			,@NextGoal				VARCHAR(MAX)=''			
			,@FirstGoalMethod		VARCHAR(2) =''
			,@TimeFirstGoal			VARCHAR(10)=''

	DECLARE	@tmpSelectedResources TABLE(
		ResourceID	VARCHAR(20)
		,HomeValue	VARCHAR(50)
		,Bettype	INT
	)

	;WITH cteSelectedResources
    AS
    (
        SELECT  T.C.value('@Id', 'VARCHAR(50)') AS ResourceId
				,T.C.value('@Home', 'VARCHAR(50)') AS HomeValue
        FROM    @xmlSelectedResources.nodes('/Resources/Resource') AS T(C)
    )
    INSERT INTO @tmpSelectedResources(ResourceID, HomeValue, Bettype)
    SELECT   r.ResourceId, r.HomeValue, s.BetType
    FROM    cteSelectedResources r
		INNER JOIN dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			ON	r.ResourceId = s.ResourceID
	WHERE	s.SportType = 1
	
	SELECT	@strBettypes = COALESCE(@strBettypes + ',' + CAST(b.bettype AS VARCHAR(10)),CAST(b.bettype AS VARCHAR(10)))
	FROM	(
		SELECT	b.bettype
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	b.matchid = @matchId
				AND b.statusID NOT BETWEEN 101 AND 102
				AND b.statusID = CASE WHEN @IsReSettledTickets = 0 THEN 0 ELSE b.statusID END
		GROUP BY b.bettype
	)b
	WHERE	b.bettype IN (SELECT DISTINCT Bettype FROM @tmpSelectedResources)

	--SELECT	 @FirstGoalMethod		= ISNULL(MAX(CASE WHEN ResourceID='424' THEN HomeValue ELSE '' END),'')			
	--		,@TimeFirstGoal			= ISNULL(MAX(CASE WHEN ResourceID='455' THEN HomeValue ELSE '' END),'')			
	--FROM	@tmpSelectedResources
	
	--SELECT	@NextGoal				= @NextGoal + CASE WHEN ResourceID LIKE '160__' THEN ResourceID + HomeValue +',' ELSE '' END 
	--FROM	@tmpSelectedResources
	
	EXEC dbo.NAP_Admin_Calculate_Main
		@matchid				= @matchid
		,@action				= 'CAL-EARLY'
		,@mode					= 'CAL'
		,@NextGoal				= @NextGoal
		,@FirstGoalMethod		= @FirstGoalMethod
		,@TimeFirstGoal			= @TimeFirstGoal
		,@strBettypes			= @strBettypes
		,@CalledByBrokerService = 0	
		,@IsReSettledTickets	= @IsReSettledTickets

END
GO
