/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_NAP_Site_MaxPayoutSetting] (
)
RETURNS TABLE
WITH SCHEMABINDING
AS
/*	Creator: 20230830@Kathy
	Task: Set Max Payout for Non-sports Products [Redmine:#193259]
	DB: DBTXN/BODB02
	
	Revisions:
		- 20230830@Kathy: Set Max Payout for Non-sports Products [Redmine:#193259]
		
*/
RETURN (
	SELECT	CAST(SiteDBGroupId AS SMALLINT) AS SiteDBGroupId
			,CAST(SiteId AS INT) AS SiteId
	FROM (VALUES (3,23),
			(3,25),
			(3,16),
			(3,20),
			(3,21),
			(3,22),
			(3,188),
			(3,1),
			(3,147),
			(3,11),
			(3,109),
			(3,35),
			(3,13),
			(3,1045),
			(3,1046),
			(3,1047),
			(3,1048)			
	) AS Sites(SiteDBGroupId, SiteId)
);
GO