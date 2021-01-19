/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ServerInfo
	@ServerAlias VARCHAR(50) = '' OUTPUT
	,@IsEnableServiceBroker BIT = 0 OUTPUT
AS
/*
    Created: 20200825@Kathy
    Task : Check service broker [Redmine:#140045]
    DB: execrep SP

    Revisions: 
		20200825@Kathy: Server is using service broker for settlement [Redmine:#140045]
		20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServerName SYSNAME 

	DECLARE @tmpServerInfo TABLE (ServerName SYSNAME, ServerAlias VARCHAR(50), IsEnableServiceBroker BIT DEFAULT(0))

	SET @ServerName = @@SERVERNAME

	INSERT INTO @tmpServerInfo(ServerName, ServerAlias, IsEnableServiceBroker)
	-- local dev
	SELECT 'DB231', 'DBEXT', 1
	UNION ALL
	SELECT 'DB231\SQLSERVER2008R2', 'DBAGE', 1
	UNION ALL
	SELECT 'DB232', 'DBACC', 1
	UNION ALL
	SELECT 'DB232\SQLSERVER2008R2', 'DBBOF', 1

	UNION ALL -- local test
	SELECT 'DB215', 'DBEXT', 1
	UNION ALL
	SELECT 'DB215\SQLSERVER2008R2', 'DBAGE', 1
	UNION ALL
	SELECT 'DB234', 'DBACC', 1
	UNION ALL
	SELECT 'DB233\SQLSERVER2008R2', 'DBBOF', 1

	UNION ALL -- SIT
	SELECT 'SITDB052', 'DBEXT', 1
	UNION ALL
	SELECT 'SITDB053', 'DBAGE', 1
	UNION ALL
	SELECT 'SITDB06', 'DBACC', 1
	UNION ALL
	SELECT 'SITDB055', 'DBBOF', 1
	
	UNION ALL -- PROD
	SELECT 'DB052', 'DBEXT', 1
	UNION ALL
	SELECT 'DB053', 'DBAGE', 1
	UNION ALL
	SELECT 'DB054C2\DB054', 'DBBOF', 1
	UNION ALL
	SELECT 'DB055', 'DBBOF', 1
	UNION ALL
	SELECT 'DB06C2\DB06', 'DBACC', 1
	UNION ALL
	SELECT 'DB06', 'DBACC', 1
	UNION ALL
	SELECT 'DBTP', 'DBACC', 1
	UNION ALL
	SELECT 'DB061', 'DBACC', 1
	UNION ALL
	SELECT 'DB062', 'DBACC', 1
	UNION ALL
	SELECT 'DB042', 'DB042', 1

	SELECT	@ServerAlias = ServerAlias
			,@IsEnableServiceBroker = IsEnableServiceBroker
	FROM	@tmpServerInfo
	WHERE	ServerName = @ServerName

	SET @ServerAlias = CASE WHEN ISNULL(@ServerAlias, '') = '' THEN @ServerName ELSE @ServerAlias END
	SET @IsEnableServiceBroker = ISNULL(@IsEnableServiceBroker, 0)

END
GO
