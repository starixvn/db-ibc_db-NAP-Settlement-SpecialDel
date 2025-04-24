/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_PendingCommand_Upd
    @pID		INT
	,@StatusID	TINYINT
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
	UPDATE SiteDB_PendingCommand WITH (ROWLOCK, UPDLOCK)
	SET StatusID = @StatusID
	WHERE pID = @pID

END