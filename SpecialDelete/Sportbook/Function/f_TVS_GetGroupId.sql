/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_TVS_GetGroupId] ()
RETURNS TABLE
AS
/*
    Created: 20250417@July
    Task: Get GroupId order follow groupName
	 DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
    Revisions:
		- 20250417@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

    Parameters Explanation:    
		Purpose: get data all sitedb follow paging size order by groupid => show betlist
*/

RETURN (
	SELECT	CONVERT(VARCHAR(100), 'Credit') AS GroupName  
		   ,CONVERT(TINYINT, 1) AS GroupId 
	UNION ALL SELECT '8RM/BARM', 2
	UNION ALL SELECT 'Deposit', 3
	UNION ALL SELECT 'Betfair', 4
	UNION ALL SELECT 'Credit (CO)', 5
	UNION ALL SELECT 'Deposit (CO)', 6
	UNION ALL SELECT 'Credit (Cancel CO)', 7
	UNION ALL SELECT 'Deposit (Cancel CO)', 8
	UNION ALL SELECT 'Credit (Instant Settlement)', 9
	UNION ALL SELECT 'Deposit (Instant Settlement)', 10
	UNION ALL SELECT 'Credit (Parlay)', 11
	UNION ALL SELECT 'Deposit (Parlay)', 12
)
GO
