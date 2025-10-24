/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_BettypesUsingBetteam] ()
RETURNS TABLE
AS
/*
    Created: 20251024@Lani
    Task: Add list bettypes using betchoice column to search (Only use for wrong OU) [Redmine: #242269]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

    Revisions:
		- 20251024@Lani: [TVS] Wrong OU - Add more bet types to the filter (New Bettype Player Prop Basketball) [Redmine: #242269]

*/

RETURN (
	SELECT CONVERT(SMALLINT,653) AS BetTypeId
	UNION ALL SELECT 655
	UNION ALL SELECT 656
	UNION ALL SELECT 658
	UNION ALL SELECT 659
	UNION ALL SELECT 661
	UNION ALL SELECT 662
	UNION ALL SELECT 664
	UNION ALL SELECT 665
	UNION ALL SELECT 667
	UNION ALL SELECT 669
	UNION ALL SELECT 671
	UNION ALL SELECT 685
	UNION ALL SELECT 686
	UNION ALL SELECT 687
	UNION ALL SELECT 688
)
GO
