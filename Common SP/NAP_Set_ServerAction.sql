/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ServerAction]
(
	@ServerName			SYSNAME = ''
	,@AllowCalculation	BIT		= 0	OUTPUT
	,@AllowUndo			BIT		= 0	OUTPUT
	,@AllowRefund		BIT		= 0	OUTPUT
)
/*    
	Creator: 20181129@Kathy
    Task: config Settlement action for special servers [Redmine:#105327]
    DB: DBTXN.bodb02

    Revisions:
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		
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
	 
	-- local 
	UNION ALL
	SELECT 'DB233\SQLSERVER2008R2' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund -- DB042
	
	-- SIT
	UNION ALL
	SELECT 'SITDB04' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'SITDB053' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 0 AS AllowRefund -- DB042
	UNION ALL
	SELECT 'SITDB043' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund
	UNION ALL
	SELECT 'SITDB044' AS ServerName, 0 AS AllowCalculation, 1 AS AllowUndo, 1 AS AllowRefund

	SELECT	@AllowCalculation = AllowCalculation
			,@AllowUndo = AllowUndo
			,@AllowRefund = AllowRefund
	FROM	@tmpServerName
	WHERE	ServerName = @ServerName

	IF @@ROWCOUNT = 0
		SELECT @AllowCalculation = 1
				,@AllowUndo = 1
				,@AllowRefund = 1
END
GO

