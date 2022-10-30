/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ServerInfo
	@ServerAlias VARCHAR(50) = '' OUTPUT
	,@IsEnableServiceBroker BIT = 0 OUTPUT
	,@TotalQueue INT = 0 OUTPUT
	,@Environment VARCHAR(50) = '' OUTPUT
	,@IsCentral BIT = 0 OUTPUT
	,@SiteDB_TotalQueue INT = 0 OUTPUT
AS
/*
    Created: 20200825@Kathy
    Task : Check service broker [Redmine:#140045]
    DB: execrep SP

    Revisions: 
        - 20200825@Kathy: Server is using service broker for settlement [Redmine:#140045]
        - 20210118@Louisa: Change Instant Name of DB054 - DB054C2\DB054 [Redmine:#148785]
        - 20210414@Kathy: Add New DB Server Name for AWS [Redmine:#149852]
        - 20210809@Kathy: Settle by custid [Redmine:159486]
        - 20211208@Louisa: Add ServerAlias DBTP10C [Redmine:#164060]
        - 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
        - 20220606@Kathy: Adjust number of execution service from 6 to 8 [Redmine:#173205]
        - 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @ServerName SYSNAME 
            
    DECLARE @tmpServerInfo TABLE (ServerName SYSNAME
        , ServerAlias VARCHAR(50)
        , IsEnableServiceBroker BIT DEFAULT(0)
        , TotalQueue INT
        , Environment VARCHAR(50)
        , IsCentral BIT DEFAULT(0)
		, SiteDB_TotalQueue INT
        )

    SET @ServerName = @@SERVERNAME

    INSERT INTO @tmpServerInfo(ServerName, ServerAlias, IsEnableServiceBroker, TotalQueue, Environment, IsCentral, SiteDB_TotalQueue)
    -- local dev
    SELECT 'DEVDB053', 'DBEXT', 1, 4, 'Local',0
    UNION ALL
    SELECT 'DB-61\DEVDB053', 'DBEXT', 1, 4, 'Local',0
    UNION ALL
    SELECT 'DB232', 'DBACC', 1, 4, 'Local',0
    UNION ALL
    SELECT 'devdb055', 'DBBOF', 1, 6, 'Local',0
    UNION ALL
    SELECT 'DB230', 'DBTXN', 0, 6, 'Local',0
    UNION ALL
    SELECT 'DB-60\DEVDBTRANS', 'DBTXN', 0, 6, 'Local',1 

    UNION ALL -- local test
    SELECT 'DB215', 'DBEXT', 1, 8, 'Local',0
    UNION ALL
    SELECT 'DB215\SQLSERVER2008R2', 'DBAGE', 1, 8, 'Local',0
    UNION ALL
    SELECT 'DB234', 'DBACC', 1, 8, 'Local',0
    UNION ALL
    SELECT 'DB233\SQLSERVER2008R2', 'DBBOF', 1, 8, 'Local',0
    UNION ALL
    SELECT 'DB206', 'DBTXN', 0, 8, 'Local',1

    UNION ALL -- new local test 2019
    SELECT 'TESTDB053', 'DBEXT', 1, 8, 'Local',0
    UNION ALL
    SELECT 'TESTDB061', 'DBACC', 1, 8, 'Local',0
    UNION ALL
    SELECT 'TESTDB055', 'DBBOF', 1, 8, 'Local',0
    UNION ALL
    SELECT 'TESTDBTRANS', 'DBTXN', 0, 8, 'Local',1

    UNION ALL -- SIT
    SELECT 'SITDB052', 'DBEXT', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDB053', 'DBAGE', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDB06', 'DBACC', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDB055', 'DBBOF', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDBAWS', 'DBBAL', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDBBAL', 'DBBAL', 1, 8, 'SIT',0
    UNION ALL
    SELECT 'SITDBTRANS', 'DBTXN', 0, 8, 'SIT',1
    
    UNION ALL -- PROD
    SELECT 'DB052', 'DBEXT', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB053', 'DBAGE', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB054', 'DBBOF', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB054C2\DB054', 'DBBOF', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB055', 'DBBOF', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB06C2\DB06', 'DBACC', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB06', 'DBACC', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DBTP', 'DBACC', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB061', 'DBACC', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB062', 'DBACC', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DB042', 'DB042', 1, 8, 'PROD',0
    UNION ALL
    SELECT 'DBTRANS', 'DBTXN', 0, 8, 'PROD',1

    UNION ALL
    SELECT 'DBBAL', 'DBBAL', 1, 8, 'DBBAL',0

    UNION ALL
    SELECT 'DBTP10C', 'DBACC', 1, 8, 'PROD',0


    SELECT  @ServerAlias = ServerAlias
            ,@IsEnableServiceBroker = IsEnableServiceBroker
            ,@TotalQueue = TotalQueue
            ,@Environment = Environment
            ,@IsCentral = IsCentral
    FROM    @tmpServerInfo
    WHERE   ServerName = @ServerName

    SET @ServerAlias = CASE WHEN ISNULL(@ServerAlias, '') = '' THEN @ServerName ELSE @ServerAlias END
    SET @IsEnableServiceBroker = ISNULL(@IsEnableServiceBroker, 0)
    SET @TotalQueue = ISNULL(@TotalQueue,0)
    SET @Environment = ISNULL(@Environment, '')
    SET @IsCentral = ISNULL(@IsCentral,0)

END
GO
