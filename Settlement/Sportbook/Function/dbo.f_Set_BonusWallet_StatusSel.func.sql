/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1" isNested="1" selecters="vnteam"></info>*/
CREATE FUNCTION dbo.f_Set_BonusWallet_StatusSel ()
RETURNS TABLE
AS
/*
	Created: 20170426@bobby
	Task: 72789 - Implement bonus system into NAP Settlement
	DB: DBTXN/BODB02
	Revisions:
		- 20170426@bobby.nguyen: Initial
		- 20180523@Kathy: Add StatusId = 8 [Redmine:#91460]
			
	Parameters Explanation:	
		- @BonusFlag: TINYINT
			+ 0: ALL
			+ 1: Count into Balance
			+ 2: None-Count into Balance
*/

RETURN (
		SELECT 0  AS StatusId --completed
			,1 	  AS BonusFlag
		UNION ALL SELECT 2, 1 --closed
		UNION ALL SELECT 4, 1 --running
		UNION ALL SELECT 5, 1 --rejected
		UNION ALL SELECT 6, 1 --approved
		UNION ALL SELECT 1, 2 --expired
		UNION ALL SELECT 3, 2 --cancelled
		UNION ALL SELECT 8, 1 --calculating
)
GO


