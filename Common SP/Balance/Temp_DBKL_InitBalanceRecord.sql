/*<info serverAlias="DBBAH-bodb02" executers="" isFunction="0"></info>*/
CREATE PROCEDURE Temp_DBKL_InitBalanceRecord 
AS
/*
    Created: 20231220@Louisa
	Task: Init balance record on KL [Redmine: #180592]
	DB:DBBAH/bodb02

	Revisions: 
		20231220@Louisa: Init balance record on KL [Redmine: #180592]
*/

---Sample: EXEC Temp_DBKL_InitBalanceRecord

BEGIN
	SET NOCOUNT ON
	DROP TABLE IF EXISTS #CustId_tmp

	IF Object_id('KL_drill_custlist') IS NULL
	BEGIN
		SELECT 'KL_drill_custlist DOES NOT EXISTS'
		RETURN
	END

	--delete if duplicate
	DELETE c
	FROM
	(	SELECT ROW_NUMBER() OVER (  PARTITION BY custid  ORDER BY (SELECT NULL)	) AS Duplicate
		FROM KL_drill_custlist WITH(NOLOCK)
	) AS c
	WHERE Duplicate > 1 

	INSERT INTO BalanceRecord (custid, transid, bettype, actual_stake, winlost, playercomm, balancechanged, newbalance, actionDate, actionID, [action])
	SELECT c.custid AS custid, 0, 0, 0, 0, 0, 0, bal.Balance AS balance,CURRENT_TIMESTAMP, 255, 'Balance : Re-Init'
	FROM KL_drill_custlist c WITH(NOLOCK)
	CROSS APPLY (
				SELECT TOP 1 Balance 
				FROM DBTXN.bodb02.dbo.v_BalanceTable b WITH(NOLOCK) 
				WHERE b.custid = c.custid
				) AS bal
		
END





