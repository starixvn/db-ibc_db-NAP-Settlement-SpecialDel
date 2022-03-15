/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_CheckingMoveBetDay]
(
	@MatchIds VARCHAR(MAX)

	,@MovingMatchIds VARCHAR(MAX) = '' OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
)
AS
/*	
	Creator: 20190219@Kathy
	Task: check move bet day of settling match
	DB: DBTXN/BODB02

	Revisions:		
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20210701@Max: Expand Transfer Time Frame - Change The Rule Checking Move Bet Flag [Redmine: #154572]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]

	Param's Explanation:		
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @Movebetdate DATETIME = NULL

	DECLARE @tmpMatchId TABLE (MatchId INT, EventDate DATETIME)

	INSERT INTO @tmpMatchId(MatchId)
	SELECT DISTINCT CONVERT(INT,[value]) 
	FROM STRING_SPLIT(@MatchIds, ',')
	
	UPDATE t
		SET EventDate = m.eventdate
	FROM	@tmpMatchId t
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON t.MatchId = m.matchid

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' +CAST(t.MatchId AS VARCHAR), CAST(t.MatchId AS VARCHAR))
	FROM	@tmpMatchId t
	WHERE	t.EventDate <= @Movebetdate

	IF @MovingMatchIds <> '' SET @ErrCode = 1001030

END
GO


