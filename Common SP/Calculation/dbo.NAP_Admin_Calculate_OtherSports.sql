/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_OtherSports]
	@matchid INT = 0
	,@action						VARCHAR(20)		= 'CAL'
	,@strTransIds					VARCHAR(MAX)	= NULL
	,@CalledByBrokerService         BIT         = 0
AS
/*
	Created: 20181016@Vicky
	Task : Covered SP for othersports settlement
	DB: EXECREP SP (DBTrans_Bet)

	Revisions:
		- 20181128@Helen:  Apply Service broker for Number Game [Redmine: 101611]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON
	DECLARE @sMessage NVARCHAR(MAX)
	
	SET @isUndo = CASE 
					WHEN @action LIKE 'UNDO%' THEN 1
					ELSE 0
				END
		
    IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB042'
			, 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
			, 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
			, 'SITDB052', 'SITDB053', 'SITDB054', 'SITDB06'
			, 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02')
			AND @CalledByBrokerService = 0
			
	BEGIN
		-- Just send a message to service broker and then let it to handle the rest.
			
		SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_OtherSports @matchid = ' + CONVERT(NVARCHAR(50), @matchid) + ','
			+ '@action = ' + '''' + @action + '''' +  ','
			+ '@strTransIds = ' + '''' + @strTransIds + '''' +  ','
			+ '@CalledByBrokerService = 1 '
			
		EXEC [sb].[SBInputMessage] @fromService = N'Service_Settlement_OtherSports'
			,@toService = N'Service_Settlement_OtherSports'
			,@onContract = N'Contract_Settlement_OtherSports'
			,@messageType = N'MessageType_Settlement_OtherSports'
			,@messageBody = @sMessage

		RETURN

	SET @isUndo = CASE WHEN @action LIKE '%UNDO%' THEN 1
					   ELSE 0
				  END

	IF @@SERVERNAME IN ('DB042', 'SITDB042', 'DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2' ) AND @isUndo = 0
		RETURN

		
	END
	ELSE
	BEGIN
		IF @action LIKE 'CAL%'
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_TransID
				  @transIds   		= @strTransIds
		END
		ELSE IF @action LIKE 'REFUND%'
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Refund_TransID
				   @transIds   		= @strTransIds
		END		  
		ELSE IF @action LIKE 'UNDO%'
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_Undo_TransID
				   @transIds   		= @strTransIds
		END				   
	END				   
END
GO