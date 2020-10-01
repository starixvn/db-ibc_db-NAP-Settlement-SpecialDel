/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_JobDeploymentInfo
	@JobName		VARCHAR(100)
	,@WaitingTime	VARCHAR(10) = '00:01:00'	OUTPUT
	,@IsWaiting		BIT = 0		OUTPUT
AS
/*
	Created by: 20201001@Kathy
	Task: Set waiting time for deployment [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201001@Kathy: Set waiting time for deployment [Redmine:#140452]	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpJobInfo TABLE (JobName VARCHAR(100), WaitingTime VARCHAR(10), IsWaiting BIT DEFAULT (0))

	SET @WaitingTime = 60
	SET @IsWaiting = 0

	INSERT INTO @tmpJobInfo (JobName, WaitingTime, IsWaiting)
	SELECT 'SingleSettlement', '00:01:00', 0
	UNION ALL
	SELECT 'ParlaySettlement', '00:01:00', 0

	SELECT @WaitingTime = WaitingTime
			,@IsWaiting = IsWaiting
	FROM	@tmpJobInfo
	WHERE	JobName = @JobName

END
GO