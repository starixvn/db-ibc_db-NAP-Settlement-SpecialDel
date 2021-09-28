/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_APL_00]
	@TableName VARCHAR(200)
	, @data VARCHAR(MAX)
AS
/*
	Creator:	20210920@Louisa
	Task:		Cleanup data - [Redmine:#161455]
	Database:	DBPRO.bodb02
		
	Revisions:
		- 20210920@Louisa:	Delete ResultDetail/ProviderExternalResultDetailES - [Redmine:#161455]
	
	Param's Explanation: 
		- SP test execrep local DB206, 215, db233\sqlserver2008R2 : QC_Local_ExecRep10
		
*/
BEGIN;

	SET NOCOUNT ON;

	IF NOT EXISTS (
		SELECT 1 FROM sysobjects WHERE name = @TableName AND [type] = 'U'
	)
	BEGIN
		RETURN -- no table name exists, do nothing
	END

	DECLARE @xmlData XML
	SET @xmlData = CAST(@data AS XML)

	IF @TableName = 'ResultDetail'
	BEGIN
		DECLARE @__resultIds TABLE(matchId INT, resourceId VARCHAR(20))
		INSERT INTO @__resultIds (matchId, resourceId)
		SELECT T.c.value('@m','int') matchId, T.c.value('@r','varchar(20)') resourceId
		FROM @xmlData.nodes('/root/r') AS T(c)
		OPTION (optimize FOR (@xmlData = NULL))

		DELETE r 
		FROM dbo.ResultDetail r WITH(ROWLOCK)
		WHERE EXISTS (
			SELECT TOP 1 1 FROM @__resultIds t 
			WHERE t.matchId = r.MatchId AND t.resourceId = r.ResourceId
		)

		RETURN
	END

	ELSE IF @TableName = 'ProviderExternalResultDetailES'
	BEGIN
		DECLARE @__resultESIds TABLE(providerExternalId INT)
		INSERT INTO @__resultESIds (providerExternalId)
		SELECT T.c.value('@id','int') providerExternalId
		FROM @xmlData.nodes('/root/r') AS T(c)
		OPTION (optimize FOR (@xmlData = NULL))

		DELETE r 
		FROM dbo.ProviderExternalResultDetailES r WITH(ROWLOCK)
		WHERE EXISTS (
			SELECT TOP 1 1 FROM @__resultESIds t WHERE t.providerExternalId = r.ProviderExternalId
		)

		RETURN
	END
END
GO
