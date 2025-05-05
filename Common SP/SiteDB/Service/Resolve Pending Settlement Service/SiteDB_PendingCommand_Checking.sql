/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE  SiteDB_PendingCommand_Checking
	@matchid		INT
	,@SiteDBGroupID TINYINT
	,@ErrCode		INT				= 0  OUTPUT
	,@ErrMsg		NVARCHAR(200)	= '' OUTPUT
AS
/*	
	Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
	
	Revisions:
		- 20250416@Louisa: Enhance settlement flow when sitedb have down time [Redmine:#217722]

*/

BEGIN
	IF EXISTS (SELECT TOP 1 1 FROM SiteDB_PendingCommand c WITH(NOLOCK) WHERE c.MatchID = @matchid AND c.StatusID = 0 AND c.SiteDBGroupID = @SiteDBGroupID)
	BEGIN
		SELECT @ErrCode = 1
			 , @ErrMsg	= 'Exists pending data!'
	END
END
GO