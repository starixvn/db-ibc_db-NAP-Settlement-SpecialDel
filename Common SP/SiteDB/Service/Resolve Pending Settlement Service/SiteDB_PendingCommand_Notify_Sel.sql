/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE  SiteDB_PendingCommand_Notify_Sel
	@CheckTime	TINYINT ---minutes
AS
/*	
	Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
	
	Revisions:
		- 20250416@Louisa: Enhance settlement flow when sitedb have down time [Redmine:#217722]

*/

BEGIN
	
	DECLARE @ToTime DATETIME = DATEADD(minute,-@checkTime,GETDATE() )

	SELECT pID
		,matchid
		,ProductType
		,SiteDBGroupID
	FROM SiteDB_PendingCommand c WITH(NOLOCK)
	WHERE c.CreateDate < @ToTime
		AND c.StatusID = 0

END
GO