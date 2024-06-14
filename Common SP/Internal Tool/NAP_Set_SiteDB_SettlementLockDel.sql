/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementLockDel
	@SessionId		BIGINT		= 0
	,@SiteDBGroupID	SMALLINT	= 0
	,@Mode VARCHAR(20) = 'single'
AS
/*
	Created by: 20221122@Louisa
	Task: Tool support after release Scaleout [RedmineId:#180746]
	DB: DBCTG/bodb02,SBSETTLE/bodb02
	
	Revisions:
		- 20221122@Louisa: Tool support after release Scaleout [RedmineId:#180746]
		- 20240514@Kathy: parlay settlement [RedmineId:#204985]
	
	Param's Explanation:
		@Mode = 'single', 'parlay'
*/
BEGIN
	SET NOCOUNT ON
	
	IF @Mode = 'single'
		DELETE 
		FROM	dbo.SiteDB_SettlementLock WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId
			AND SiteDBGroupID = @SiteDBGroupID
	
	ELSE IF @Mode = 'parlay'
		DELETE 
		FROM	dbo.SiteDB_ParlaySettlementLock WITH(ROWLOCK, UPDLOCK)
		WHERE	sessionId = @SessionId
			AND SiteDBGroupID = @SiteDBGroupID
END
GO