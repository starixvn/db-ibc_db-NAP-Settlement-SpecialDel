/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Undo_s213] 
	@matchid INT =0,
	@GambleID INT = 0,
	@CalledByBrokerService BIT = 0
AS
	/*
		Created by:[Johnson]
		Date:[20190109]
		Task: Undo for NG2
		DB: DBTXN/BODB02
		
		Revisions:
			- 20190109@Johnson: create sp [redmine:#107658]
			- 20190319@Johnson: migrate server DB061,062 [redmine: #110514]
		Parameter's Explanation:
		
	*/
BEGIN
	SET NOCOUNT ON
	
	IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DB061', 'DB062', 'DBTP', 'DB042'
            , 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
            , 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
			, 'DB231\DBSPU2','DB232\DBSPU2'
            , 'SITDB052', 'SITDB053', 'SITDB054', 'SITDB06'
            , 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02')
		AND @CalledByBrokerService = 0
	BEGIN
		-- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
		DECLARE @sMessage NVARCHAR(MAX)

		SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_Undo_s213 '
		+'@matchid =' +  CONVERT(VARCHAR(20),@matchid) + ','
		+'@GambleID =' +  CONVERT(VARCHAR(20),@GambleID) + ','
		+'@CalledByBrokerService = 1'
		
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
			WHERE	matchid = @matchid
				AND betdaqid = @GambleID
				AND statusID NOT IN (103, 101, 102) 
			
			 IF @@ROWCOUNT < 10000
				BREAK
		END
	END
END
GO
