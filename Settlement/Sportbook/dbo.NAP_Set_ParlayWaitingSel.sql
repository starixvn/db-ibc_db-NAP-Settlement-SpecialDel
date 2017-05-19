ALTER PROCEDURE [NAP_Set_ParlayWaitingSel]
AS
/*
	Created: 20140114@Kathy
	Task: get parlay settlement status for a match
	DB: DBTXN/BODB02
	
	Revision:
	
*/
BEGIN

	SET NOCOUNT ON 
	
	SELECT matchid, isCalculating AS CalcMP
	FROM Parlay_WaitingList WITH(NOLOCK)
	
END


GO

GRANT EXECUTE ON [NAP_Set_ParlayWaitingSel] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Set_ParlayWaitingSel] TO [vnteam] AS [dbo]
GO


