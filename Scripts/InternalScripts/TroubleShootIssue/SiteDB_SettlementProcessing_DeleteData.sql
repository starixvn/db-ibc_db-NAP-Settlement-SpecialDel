/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
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

IF EXISTS (SELECT TOP 1 * FROM SiteDB_SettlementProcessing WITH (NOLOCK) WHERE SessionId= @session_id )
BEGIN
	-- backup before delete
	SELECT  * 
	INTO #temp_SiteDB_SettlementProcessing
	FROM SiteDB_SettlementProcessing WITH (NOLOCK) 
	WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid
	
	DELETE P
	FROM SiteDB_SettlementProcessing p 
	WHERE SessionId = @session_id AND SiteDBGroupId = @sitedbgroupid
END

