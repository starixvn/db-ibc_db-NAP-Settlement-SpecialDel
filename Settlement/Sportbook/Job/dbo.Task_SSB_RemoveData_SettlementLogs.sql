/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_SSB_RemoveData_SettlementLogs]
	@CreationTime datetime
AS

/*
	20180720 @ Patrick
	DB: SBSETTLE-bodb02
	Task: Remove data settlement logs

	Revisions:  
		- 20211028@Kathy: Remove log on table SSB_SettlementLogs [Redmine:#159486]
*/

BEGIN
	SET NOCOUNT ON

	IF @CreationTime >= DATEADD(DAY, -1, GETDATE()) OR @CreationTime IS NULL
		SET @CreationTime = DATEADD(DAY, -1, GETDATE())

	WHILE 1 = 1
	BEGIN
		DELETE TOP(2000) FROM sb.CalculationLogs WITH(ROWLOCK)
		WHERE creationTime <= @CreationTime

		IF @@ROWCOUNT = 0
			BREAK
	END

	WHILE(1=1)
	BEGIN
		DELETE TOP(2000) FROM dbo.SSB_SettlementLogs WITH(ROWLOCK)
		WHERE StartTime <= @CreationTime

		IF @@ROWCOUNT = 0
			BREAK
	END
END