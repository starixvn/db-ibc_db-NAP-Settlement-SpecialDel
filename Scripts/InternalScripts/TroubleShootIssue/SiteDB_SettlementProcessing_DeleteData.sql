/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
-- RUN ON DBTRANS/bodb02
DECLARE @session_id BIGINT, @sitedbgroupid smallint

-- GET session in progress
SET @sitedbgroupid = XXX

SET @session_id = (SELECT TOP 1 SessionId 
					FROM SiteDB_SettlementLock WITH (NOLOCK)
					WHERE SiteDBGroupId = @sitedbgroupid
					ORDER BY SessionId)
/*
-- CHECK DATA

SELECT  * 
FROM SiteDB_SettlementProcessing WITH (NOLOCK) 
WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid


SELECT  *
FROM SiteDB_SettlementLock WITH (NOLOCK) 
WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid

*/

IF EXISTS (SELECT TOP 1 1 FROM SiteDB_SettlementProcessing WITH (NOLOCK) WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid AND StatusID = 3)
BEGIN
	-- backup before delete
	SELECT  * 
	INTO #temp_SiteDB_SettlementProcessing
	FROM SiteDB_SettlementProcessing WITH (NOLOCK) 
	WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid 
	
	DELETE p
	FROM SiteDB_SettlementProcessing p 
	WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid 
		AND StatusID = 3 -- IN CASE need to delete all, can rem this filter
END

/*
--Sample code to decompress json
DECLARE @Decompress_TransInfoJson NVARCHAR(MAX), @TransInfoJson VARBINARY(MAX)

SET @TransInfoJson = 0x1F8B0800000000000400ED95CB6AC3301045EFB778DD18C9766A3B1FD16C0A5D8410523785424D42EDD045E9BFF76A3C49FC5A749F41083473E665F98236F84184967B850C0512E458F294C1C37179AE47FA0B94240F8CAB2536A23F9688B0222147210BDAB1C407D2F91B21AE9711FC8DF68DD8D57127CC0DFD42851CCFB45352CF5956324DCC9A61BEAEDBB7E47AED34ACBC57BA60AE9BD0FA4AD319DA5C69324B5B566F7196B84F894C849C50A935CEA974D2E564CA8E94931E95FE8FB1BFBBAD17ACF1A4B7D0E0036F5ADFEB245F6A87F32B0E78C74EBF693CD985DEAA38FC92FC5F13A569C234D1D3442967D38469A2AF89D4DE0ED3C44413F6769826869AC8ECEDB8134D6CF107E09BBFA87A0C0000

SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

SELECT @Decompress_TransInfoJson

*/
