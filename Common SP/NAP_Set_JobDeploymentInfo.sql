/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_JobDeploymentInfo
	@JobName		VARCHAR(100)
	,@WaitingTime	VARCHAR(10) 	OUTPUT
	,@IsWaiting		BIT		OUTPUT
AS
/*
	Created by: 20201001@Kathy
	Task: Set waiting time for deployment [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201001@Kathy: Set waiting time for deployment [Redmine:#140452]
		- 20201006@Louisa: Hardcode for JobName [Redmine:#140452]
		- 20210128@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210206@Max: TVS - Lock TempVariableNumber and can't void cash out ticket [Redmine: #150176]
		- 20210207@Helen: TVS - Increase Retry for void process [Redmine: #150176]
		- 20210209@Helen: TVS - Performance Tuning for void abnormal account over 300 matches [Redmine: #150204]
		- 20220406@Kathy: Add job bodb02 : NAP Settlement VS BetRadar [Redmine:#166457]
		- 20220822@Max: Deploy [TVS] Support Max Payout & Max Turnover for Deposit [Redmine: #176894]
		- 20220809@Max: DBA - PROD - Enhance Parlay Calculation for Max Payout [Redmine: #177611]   
		- 20230712@Max: Scale out credit [Redmine: #181595]
		- 20230907@July: Remove job un-used [Redmine: #193701]

*/ 
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpJobInfo TABLE (JobName VARCHAR(100), WaitingTime VARCHAR(10), IsWaiting BIT DEFAULT (0))

	SET @WaitingTime = '00:01:00'
	SET @IsWaiting = 0

	---1.Single Settlement
	INSERT INTO @tmpJobInfo (JobName, WaitingTime, IsWaiting)
	SELECT 'bodb02 : NAP Single Settlement'		, '00:01:00', 0

	--2.Parlay Settlement
	UNION ALL
	SELECT 'bodb02 : NAP Parlay Settlement'		, '00:01:00', 0

	--3.Single Settlement 3rd
	UNION ALL
	SELECT 'bodb02 : NAP Single Settlement 3rd'	, '00:01:00', 0

	--4.BalanceUpdBonusCredit
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdBonusCredit', '00:01:00', 0

	--5.BalanceUpdCreditCasino
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdCreditCasino', '00:01:00', 0

	--6.BalanceUpdCreditOthers
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdCreditOthers', '00:01:00', 0

	--7.BalanceUpdCreditSports
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdCreditSports', '00:01:00', 0

	--8.BalanceUpdDebitCasino
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdDebitCasino', '00:01:00', 0

	--9.BalanceUpdDebitOthers
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdDebitOthers', '00:01:00', 0

	--10.BalanceUpdDebitSports
	UNION ALL
	SELECT 'bodb02 : Task_BalanceUpdDebitSports', '00:01:00', 0

	--12.VS BetRadar
	UNION ALL
	SELECT 'bodb02 : NAP Settlement VS BetRadar', '00:01:00', 0 

	--13.Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Max Payout Per Match'	, '00:01:00', 0

	--13.1.Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Max Payout Per Match Licensee'	, '00:01:00', 0

	--13.2.Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Max Payout Per Match Credit'	, '00:01:00', 0

	--14.Retry Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Retry Max Payout'	, '00:01:00', 0

	--14.1.Retry Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Retry Max Payout Licensee'	, '00:01:00', 0

	--14.2.Retry Max Payout
	UNION ALL
	SELECT 'bodb02 : Task Retry Max Payout Credit'	, '00:01:00', 0


	SELECT @WaitingTime = WaitingTime
			,@IsWaiting = IsWaiting
	FROM	@tmpJobInfo
	WHERE	JobName = @JobName

END
GO