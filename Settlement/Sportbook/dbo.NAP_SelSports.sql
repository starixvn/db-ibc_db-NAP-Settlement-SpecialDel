ALTER PROCEDURE [NAP_SelSports] @isGetAll BIT = 0
AS
/*
	Created by: 20131223@Kathy
	Task: Get the list of sports for Settlement function
	DB:DB02.BODB02
	Original: Acc_SelSports
	
	Revisions:

	Param's Explanation:
		@isGetAll: 1 - get all sports for view result, 0- get only sportbook
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT *
	FROM Sports WITH (NOLOCK)
	WHERE (SportType <= 99 OR SportType = 154) OR (@isGetAll = 1 AND SportType IN (151, 152, 153))
END


GO

GRANT EXECUTE ON [NAP_SelSports] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_SelSports] TO [vnteam] AS [dbo]
GO


