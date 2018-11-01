/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_OtherSports]
    @matchid                        INT
    ,@action                        VARCHAR(20) 	= 'CAL'
    ,@strTransIds                   VARCHAR(MAX)	= NULL
    ,@CalledByBrokerService         BIT         	= 0
AS
/*
    Created: 20181016@Vicky
    Task : Covered SP for othersports settlement
    DB: EXECREP SP (DBTrans_Bet)

    Revisions:
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]

    Param's Explanation:

*/
BEGIN
    SET NOCOUNT ON;

    DECLARE @isUndo BIT

    SET @isUndo = CASE WHEN @action LIKE '%UNDO%' THEN 1
                       ELSE 0
                  END

    IF @@SERVERNAME IN ('DB042', 'SITDB042', 'DB232\SQLSERVER2008R2', 'DB233\SQLSERVER2008R2' ) AND @isUndo = 0
        RETURN

    IF @@SERVERNAME IN ('DB052', 'DB053', 'DB054', 'DB06', 'DBTP', 'DB042'
            , 'DB231', 'DB231\SQLSERVER2008R2', 'DB232', 'DB232\SQLSERVER2008R2'
            , 'DB215', 'DB215\SQLSERVER2008R2', 'DB234', 'DB233\SQLSERVER2008R2'
            , 'SITDB052', 'SITDB053', 'SITDB054', 'SITDB06'
            , 'DBLicAPI', 'SITDBLicAPI', 'DBLicAPI02')
        AND @CalledByBrokerService = 0
    BEGIN
        -- DB052/DB053/DB054/DB06: got servicebroker, then just send a message to service broker and then let it to handle the rest.
        DECLARE @sMessage NVARCHAR(MAX)
		
	               
        /*SET @sMessage = 'EXEC dbo.NAP_Admin_Calculate_TransID @matchid = ' + CONVERT(NVARCHAR(50), @matchid) + 
            ',@action = ' + CASE
                WHEN @action IS NULL THEN 'NULL'
                ELSE '''' + CONVERT(NVARCHAR(50), @action) + ''''
                END + 
            + CASE WHEN @strTransIds IS NULL THEN '' ELSE ',@strTransIds = ''' + CONVERT(VARCHAR(MAX), @strTransIds) + '''' END

            
        EXEC [sb].[SBInputMessage] @fromService = N'//Service/Calculation_send'
            ,@toService = N'//Service/Calculation_receive'
            ,@onContract = N'//Contract/Calculation'
            ,@messageType = N'//Message/Calculation'
            ,@messageBody = @sMessage*/
        
        IF @action LIKE 'CAL%'
	        EXEC dbo.NAP_Admin_Calculate_TransID
	              @transIds   		= @strTransIds
	
	    IF @action LIKE 'REFUND%'
	        EXEC dbo.NAP_Admin_Calculate_Refund_TransID
	               @transIds   		= @strTransIds
	              
	    IF @action LIKE 'UNDO%'
	        EXEC dbo.NAP_Admin_Calculate_Undo_TransID
	               @transIds   		= @strTransIds

        RETURN
    END
    
	    
    IF @action LIKE 'CAL%'
        EXEC dbo.NAP_Admin_Calculate_TransID
              @transIds   		= @strTransIds

    IF @action LIKE 'REFUND%'
        EXEC dbo.NAP_Admin_Calculate_Refund_TransID
               @transIds   		= @strTransIds
              
    IF @action LIKE 'UNDO%'
        EXEC dbo.NAP_Admin_Calculate_Undo_TransID
               @transIds   		= @strTransIds
END
GO