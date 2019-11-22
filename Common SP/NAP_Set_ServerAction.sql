/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ServerAction]
(
	@ServerName			SYSNAME = ''
	,@AllowCalculation	BIT		= 0	OUTPUT
	,@AllowUndo			BIT		= 0	OUTPUT
	,@AllowRefund		BIT		= 0	OUTPUT
	,@AllowExec			BIT		= 0 OUTPUT
)
/*    
	Creator: 20181129@Kathy
    Task: config Settlement action for special servers [Redmine:#105327]
    DB: DBTXN/bodb02

    Revisions:
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190221@Kathy: Exclude 2 new servers DB04ADMIN1 and DB04ADMIN2 out of Settlement Flow [Redmine:#108362]
		- 20191119@Helen: Do not settle ticket on DB054 [Redmine:#123963]
		
    Param's Explanation:
        this SP is adding in publication DBTrans_ExecRep
*/
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpServerName TABLE (ServerName SYSNAME, AllowCalculation BIT, AllowUndo BIT, AllowRefund BIT)

	INSERT INTO @tmpServerName (ServerName, AllowCalculation, AllowUndo, AllowRefund)
	SELECT 'DB04' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'DB042' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund
	UNION ALL
	SELECT 'DB043' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'DB044' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'DB04ADMIN1' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'DB04ADMIN2' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund 
	UNION ALL
	SELECT 'DB054' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund
	
	-- local 
	UNION ALL
	SELECT 'DB233\SQLSERVER2008R2' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund -- DB042
	
	-- SIT
	UNION ALL
	SELECT 'SITDB04' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'SITDB043' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'SITDB044' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'SITDB054' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund
	
	SELECT	@AllowCalculation = AllowCalculation
			,@AllowUndo = AllowUndo
			,@AllowRefund = AllowRefund
			,@AllowExec = 0
	FROM	@tmpServerName
	WHERE	ServerName = @ServerName

	IF @@ROWCOUNT = 0
		SELECT	@AllowCalculation = 1
				,@AllowUndo = 1
				,@AllowRefund = 1
				,@AllowExec = 1
END
GO

