/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementLockDel
	@SessionId		BIGINT		= 0
	,@SiteDBGroupID	SMALLINT	= 0
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG/bodb02,SBSETTLE/bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]

*/
BEGIN
	SET NOCOUNT ON

	DELETE 
	FROM	dbo.SiteDB_SettlementLock WITH(ROWLOCK, UPDLOCK)
	WHERE	sessionId = @SessionId
		AND SiteDBGroupID = @SiteDBGroupID
END
GO