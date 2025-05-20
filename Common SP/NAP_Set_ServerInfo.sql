/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ServerInfo
	@ServerAlias VARCHAR(50) = '' OUTPUT
	,@IsEnableServiceBroker BIT = 0 OUTPUT
	,@TotalQueue INT = 0 OUTPUT
	,@TotalParlayQueue INT = 0 OUTPUT
	,@Environment VARCHAR(50) = '' OUTPUT
	,@IsCentral BIT = 0 OUTPUT
	,@SiteDB_TotalQueue INT = 0 OUTPUT
	,@SiteDB_TotalParlayQueue INT = 0 OUTPUT
	,@SiteDB_RunSettlement BIT = 1 OUTPUT
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
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [Redmine:#180225]
		- 20240215@Kathy: support multiple threads to settle parlay [Redmine:#199518]
        - 20250508@Aries: Change instance name DBTRANS [Redmine:#226591]
*/
BEGIN
    SET NOCOUNT ON

    DECLARE @ServerName SYSNAME 
			
    DECLARE @tmpServerInfo TABLE (ServerName SYSNAME
        , ServerAlias VARCHAR(50)
        , IsEnableServiceBroker BIT DEFAULT(0)
        , TotalQueue INT
		, TotalParlayQueue INT
        , Environment VARCHAR(50)
        , IsCentral BIT DEFAULT(0)
		, SiteDB_TotalQueue INT
		, SiteDB_TotalParlayQueue INT
        )

    SET @ServerName = @@SERVERNAME
	SET @SiteDB_RunSettlement = 1

    INSERT INTO @tmpServerInfo(ServerName, ServerAlias, IsEnableServiceBroker, TotalQueue, TotalParlayQueue, Environment, IsCentral, SiteDB_TotalQueue, SiteDB_TotalParlayQueue)
    -- local dev
    SELECT 'DEVDB053', 'DBEXT', 1, 4, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB-61\DEVDB053', 'DBEXT', 1, 4, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB232', 'DBACC', 1, 4, 4, 'Local',0, 4, 4
	UNION ALL
    SELECT 'DEVDB061', 'DBACC', 1, 4, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'devdb055', 'DBBOF', 1, 6, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB230', 'DBTXN', 0, 6, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB-60\DEVDBTRANS', 'DBTXN', 0, 6, 4, 'Local',1, 4, 4

    UNION ALL -- local test
    SELECT 'DB215', 'DBEXT', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB215\SQLSERVER2008R2', 'DBAGE', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB234', 'DBACC', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB233\SQLSERVER2008R2', 'DBBOF', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'DB206', 'DBTXN', 0, 8, 4, 'Local',1, 4, 4

    UNION ALL -- new local test 2019
    SELECT 'TESTDB053', 'DBEXT', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'TESTDB061', 'DBACC', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'TESTDB055', 'DBBOF', 1, 8, 4, 'Local',0, 4, 4
    UNION ALL
    SELECT 'TESTDBTRANS', 'DBTXN', 0, 8, 4, 'Local',1, 4, 4

	UNION ALL -- SIT
    SELECT 'SITDB05', 'DBBAH', 0, 0, 0, 'SIT',0, 0, 0
	UNION ALL 
    SELECT 'SITDB05BK1', 'DBBAH', 0, 0, 0, 'SIT',0, 0, 0
    UNION ALL 
    SELECT 'SITDB052', 'DBEXT', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDB053', 'DBAGE', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDB06', 'DBACC', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDB055', 'DBBOF', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDBAWS', 'DBBAL', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDBBAL', 'DBBAL', 1, 8, 4, 'SIT',0, 4, 4
    UNION ALL
    SELECT 'SITDBTRANS', 'DBTXN', 0, 8, 4, 'SIT',1, 4, 4
	
	UNION ALL -- PROD
    SELECT 'DB05', 'DBBAH', 0, 0, 0, 'PROD',0, 0, 0
	UNION ALL 
    SELECT 'DB05BK1', 'DBBAH', 0, 0, 0, 'PROD',0, 0, 0
    UNION ALL 
    SELECT 'DB052', 'DBEXT', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB053', 'DBAGE', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB054', 'DBBOF', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB054C2\DB054', 'DBBOF', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB055', 'DBBOF', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB06C2\DB06', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB06', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DBTP', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB061', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB062', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DB042', 'DB042', 1, 8, 4, 'PROD',0, 4, 4
    UNION ALL
    SELECT 'DBTRANS', 'DBTXN', 0, 8, 4, 'PROD',1, 4, 4
    UNION ALL
    SELECT 'DBTRANS\INST2', 'DBTXN', 0, 8, 4, 'PROD',1, 4, 4
    UNION ALL
    SELECT 'DBBAL', 'DBBAL', 1, 8, 4, 'DBBAL',0, 4, 4

    UNION ALL
    SELECT 'DBTP10C', 'DBACC', 1, 8, 4, 'PROD',0, 4, 4


    SELECT  @ServerAlias = ServerAlias
            ,@IsEnableServiceBroker = IsEnableServiceBroker
            ,@TotalQueue = TotalQueue
            ,@Environment = Environment
            ,@IsCentral = IsCentral
			,@SiteDB_TotalQueue = SiteDB_TotalQueue
			,@TotalParlayQueue = TotalParlayQueue
			,@SiteDB_TotalParlayQueue = SiteDB_TotalParlayQueue
    FROM    @tmpServerInfo
    WHERE   ServerName = @ServerName

    SET @ServerAlias = CASE WHEN ISNULL(@ServerAlias, '') = '' THEN @ServerName ELSE @ServerAlias END
    SET @IsEnableServiceBroker = ISNULL(@IsEnableServiceBroker, 0)
    SET @TotalQueue = ISNULL(@TotalQueue,0)
    SET @Environment = ISNULL(@Environment, '')
    SET @IsCentral = ISNULL(@IsCentral,0)
	SET @SiteDB_TotalQueue = ISNULL(@SiteDB_TotalQueue,0)
	SET @TotalParlayQueue = ISNULL(@TotalParlayQueue,0)
	SET @SiteDB_TotalParlayQueue = ISNULL(@SiteDB_TotalParlayQueue,0)

	IF @ServerAlias = 'DBBAH'
		SET @SiteDB_RunSettlement = 0

END
GO
