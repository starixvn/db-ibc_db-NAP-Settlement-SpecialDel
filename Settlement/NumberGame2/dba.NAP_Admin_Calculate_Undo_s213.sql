/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Undo_s213] 
	@matchid INT =0,
	@GambleID INT = 0,
	@CalledByBrokerService BIT = 0,
	@RunOnServer VARCHAR(100) = NULL
AS
	/*
		Created by:[Johnson]
		Date:[20190109]
		Task: Undo for NG2
		DB: DBTXN/BODB02
		
		Revisions:
			- 20190109@Johnson: create sp [redmine:#107658]
			- 20190319@Johnson: migrate server DB061,062 [redmine: #110514]
			- 20200826@Johnson: add more servers DB055, DB06C2\DB06 [redmine:#140315]
			- 20210125@Johnson: Migrate DB054 to cluster, instance DB054C2\DB054 [redmine:#149341]
			- 20210419@Johnson: Do not run replicated commands on servers which setup service broker [Redmine:#145127]
			- 20230419@Kathy: Scale Out for Number Game 2 [Redmine:#186722]
		Parameter's Explanation:
		
	*/
BEGIN
	SET NOCOUNT ON
	  
	DECLARE @IsEnableServiceBroker BIT 
		
	EXEC dbo.NAP_Set_ServerInfo 
		@IsEnableServiceBroker = @IsEnableServiceBroker OUTPUT
	
	SET @RunOnServer = ISNULL(@RunOnServer,@@SERVERNAME)
	
	IF @RunOnServer <> @@SERVERNAME
	BEGIN
		PRINT 'This command was skipped because run wrong server'
		RETURN
	END
	
	IF (@@SERVERNAME IN ('DB231\DBSPU2','DB232\DBSPU2','DBLicAPI','SITDBLicAPI','DBLicAPI02') OR @IsEnableServiceBroker = 1)
		AND @CalledByBrokerService = 0
	BEGIN
		-- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
		DECLARE @sMessage NVARCHAR(MAX)

		SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_Undo_s213 '
		+'@matchid =' +  CONVERT(VARCHAR(20),@matchid) + ','
		+'@GambleID =' +  CONVERT(VARCHAR(20),@GambleID) + ','
		+'@CalledByBrokerService = 1'
		+CASE WHEN @RunOnServer IS NULL THEN '' ELSE ',@RunOnServer = ' + '''' + CONVERT(NVARCHAR(100), @RunOnServer) + '''' END
				
		EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
			,@toService = N'//Service/Calculation_receive'
			,@onContract = N'//Contract/Calculation'
			,@messageType = N'//Message/Calculation'
			,@messageBody = @sMessage

		RETURN
	END
	ELSE
	BEGIN
		WHILE (1 = 1)
		BEGIN
			UPDATE	TOP (10000) dbo.bettrans WITH (ROWLOCK, UPDLOCK)
				SET [status] = N'running'
					,statusID = 0
					,winlost = 0
					,awinlost = 0
					,mwinlost = 0
					,swinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
					,ruben = 0				
					,RepUpdateTime = SYSDATETIME()
			WHERE	matchid = @matchid
				AND betdaqid = @GambleID
				AND statusID NOT IN (103, 101, 102) 
			
			 IF @@ROWCOUNT < 10000
				BREAK
		END
	END
END
GO
