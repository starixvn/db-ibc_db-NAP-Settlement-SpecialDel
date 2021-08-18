/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION dbo.f_Set_GetListAction ()
RETURNS TABLE
AS
/*
	Created: 2015107@Patrick	
	Task: Build up half time bettype list
	DB: DBTRANS/BODB02
	Revisions:
		-20161013@Bobby: #65178 - Implement Instant calculation process
		-20200401@Sol: HotFix - Don't write error message on Userlog table when the match is being locked by other actions - [Redmine:#129165]
		-20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
			
	Parameters Explanation:	
		@Mode: 1: For Single ticket - Manual
			   2: For FGLG -  Manual
			   3: For Corner - Manual
			   4: For Parlay - Manual
			   5: For Single ticket - Auto payout
			   6: For Single ticket - Instant Calculation
			   7: For Single ticket - UNDO Instant Calculation
			   8: For sports: Esport, Badminton, Tennis
			   
*/

RETURN (
	SELECT 1 AS Mode, 'CAL' AS ActionName, 100 AS ActionId UNION ALL
	SELECT 1 AS Mode, 'CAL-FT' AS ActionName, 101 AS ActionId UNION ALL
	SELECT 1 AS Mode, 'CAL-HT' AS ActionName, 102 AS ActionId UNION ALL
	SELECT 1 AS Mode, 'UNDO' AS ActionName, 103 AS ActionId UNION ALL

	SELECT 1 AS Mode, 'REFUND-HT' AS ActionName, 110 AS ActionId UNION ALL
	SELECT 1 AS Mode, 'REFUND-FT' AS ActionName, 111 AS ActionId UNION ALL
	SELECT 1 AS Mode, 'REFUND' AS ActionName, 109 AS ActionId UNION ALL

	--FGLG
	SELECT 2 AS Mode, 'CAL-FT' AS ActionName, 163 AS ActionId UNION ALL
	SELECT 2 AS Mode, 'CAL-HT' AS ActionName, 164 AS ActionId UNION ALL
	SELECT 2 AS Mode, 'CAL' AS ActionName, 108 AS ActionId UNION ALL

	SELECT 2 AS Mode, 'REFUND-FGLG' AS ActionName, 112 AS ActionId UNION ALL

	--Corner
	SELECT 3 AS Mode, 'CAL-FT' AS ActionName, 161 AS ActionId UNION ALL
	SELECT 3 AS Mode, 'CAL-HT' AS ActionName, 162 AS ActionId UNION ALL
	SELECT 3 AS Mode, 'CAL' AS ActionName, 151 AS ActionId UNION ALL
	
	--Parlay
	SELECT 4 AS Mode, 'CAL' AS ActionName, 104 AS ActionId UNION ALL
	SELECT 4 AS Mode, 'UNDO' AS ActionName, 105 AS ActionId UNION ALL
	SELECT 4 AS Mode, 'REFUND-FT' AS ActionName, 106 AS ActionId UNION ALL
	SELECT 4 AS Mode, 'REFUND-HT' AS ActionName, 120 AS ActionId UNION ALL
	SELECT 4 AS Mode, 'REFUND' AS ActionName, 107 AS ActionId UNION ALL

	--Auto payout
	SELECT 5 AS Mode, 'CAL-FT' AS ActionName, 158 AS ActionId UNION ALL
	SELECT 5 AS Mode, 'CAL-HT' AS ActionName, 157 AS ActionId UNION ALL
	
	--Instant Calculation
	SELECT 6 AS Mode, 'INST-HT' AS ActionName, 178 AS ActionId UNION ALL
	SELECT 6 AS Mode, 'INST-FT' AS ActionName, 179 AS ActionId UNION ALL
	SELECT 7 AS Mode, 'INST-UNDO' AS ActionName, 182 AS ActionId UNION ALL

	--For sports: Esport, Badminton, Tennis
	SELECT 8 AS Mode, 'CAL' AS ActionName, 100 AS ActionId UNION ALL
	SELECT 8 AS Mode, 'UNDO' AS ActionName, 103 AS ActionId UNION ALL
	SELECT 8 AS Mode, 'REFUND' AS ActionName, 109 AS ActionId UNION ALL
	SELECT 8 AS Mode, 'CAL_EAR' AS ActionName, 189 AS ActionId UNION ALL
	SELECT 8 AS Mode, 'UNDO_EAR' AS ActionName, 190 AS ActionId UNION ALL
	SELECT 8 AS Mode, 'REFUND_EAR' AS ActionName, 191 AS ActionId UNION ALL

	--Auto Settle Cricket
	SELECT 9 AS Mode, 'CAL' AS ActionName, 100 AS ActionId
						  
)
GO


