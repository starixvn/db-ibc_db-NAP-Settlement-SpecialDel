/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_CheckingMoveBetDay]
	@MatchIds VARCHAR(MAX)

	,@MovingMatchIds VARCHAR(MAX) = '' OUTPUT
	,@ErrCode INT = 0 OUTPUT
	,@ErrMsg VARCHAR(200) = '' OUTPUT
AS
/*	Creator: 20190219@Kathy
	Task: check move bet day of settling match
	DB: DBTXN/BODB02

	Revisions:		
		- 20190218@Kathy: Do not allow to settle match which has eventdate = movebet day [Redmine:#108768]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]

	Param's Explanation:		
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsMovingBet BIT

	DECLARE @tmpMatchId TABLE (MatchId INT, EventDate DATETIME)
	DECLARE @tmpMoveBetsDay TABLE (ScheduleId INT,  MoveBetsDay DATETIME)

	INSERT INTO @tmpMatchId(MatchId)
	SELECT DISTINCT CONVERT(INT,val) 
	FROM dbo.f_SplitString(@MatchIds, ',')
	OPTION (maxrecursion 0) 

	UPDATE t
		SET EventDate = m.eventdate
	FROM	@tmpMatchId t
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON t.MatchId = m.matchid

	SELECT @IsMovingBet = VValue
	FROM	dbo.SystemSettings
	WHERE	VName = 'isMovingBet_Local'

	INSERT INTO @tmpMoveBetsDay(ScheduleId, MoveBetsDay)
	EXEC Task_MoveBetsDayByScheduleSel 

	IF @IsMovingBet = 1
	BEGIN
		SELECT	@MovingMatchIds = COALESCE(@MovingMatchIds + ',' +CAST(t.MatchId AS VARCHAR), CAST(t.MatchId AS VARCHAR))
		FROM	@tmpMatchId t
		WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpMoveBetsDay mb WHERE t.EventDate = mb.MoveBetsDay)

		IF ISNULL(@MovingMatchIds, '') <> ''
			SELECT	@ErrCode = 1001030
					,@ErrMsg = 'Cannot proceed as during move-bet progress. Please contact Starix IT for further support!'
	END


END
GO


