/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_PendingCommand_Sel
    @SiteDBGroupID SMALLINT
	,@batch SMALLINT
AS
/*	
	Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
	
	Revisions:
		- 20250416@Louisa: Enhance settlement flow when sitedb have down time [Redmine:#217722]
AS

*/
BEGIN
	
   SELECT TOP (@batch)
		pID
		,matchid		
		,ProductType	
		,SPName
		,Parameter
		,SystemName
		,AdminID
		,Action
	FROM SiteDB_PendingCommand WITH(NOLOCK)
	WHERE SiteDBGroupID = @SiteDBGroupID 
		AND StatusID = 0
	ORDER BY pID ASC
END
 
  

