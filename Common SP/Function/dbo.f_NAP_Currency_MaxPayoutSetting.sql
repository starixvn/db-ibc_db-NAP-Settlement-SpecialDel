/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_NAP_Currency_MaxPayoutSetting] (
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
			,CAST(ExchangeId AS TINYINT) AS ExchangeId
			,CAST(MaxWinLimit AS MONEY) AS MaxWinLimit
	FROM (VALUES (3,2,200000),
		(3,3,50000),
		(3,5,200000),
		(3,6,40000),
		--(3,7,1000000000),
		(3,12,30000),
		(3,13,200000),
		(3,15,500000),
		(3,20,50000),
		(3,72,50000),
		(3,45,50000000),
		(3,95,50000),
		(3,64,50000),
		(3,35,50000),
		(3,16,50000),
		(3,47,500000),
		(3,43,2000000),
		(3,67,200000),
		(3,69,100000),
		(3,22,500000),
		(3,33,500000),
		(3,34,500000)
		--(3,10,4000000),
		--(3,11,40000)		
	) AS Setting(SiteDBGroupId, ExchangeId, MaxWinLimit)
);
GO