/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDB_SettlementProcessingDel
	@SessionId		BIGINT		= 0
	,@SiteDBGroupId SMALLINT	= 0
	,@Action		VARCHAR(1) = ''
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

	IF OBJECT_ID ('SiteDB_SettlementProcessing','U') IS NOT NULL
	BEGIN
		IF @Action = 'D'
		BEGIN
			DELETE 
			FROM	dbo.SiteDB_SettlementProcessing WITH(ROWLOCK, UPDLOCK)
			WHERE	sessionId = @SessionId
				AND SiteDBGroupId = @SiteDBGroupId
				AND StatusId IN (1,3)
		END

		IF @Action = 'U'
		BEGIN
			UPDATE dbo.SiteDB_SettlementProcessing WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 0
			WHERE	sessionId = @SessionId
				AND SiteDBGroupId = @SiteDBGroupId
				AND StatusId IN (1,3)
		END

	END

END
GO