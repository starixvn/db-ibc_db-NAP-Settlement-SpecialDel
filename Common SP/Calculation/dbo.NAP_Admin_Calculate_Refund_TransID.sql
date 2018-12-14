/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Refund_TransID]
	@transIds					VARCHAR(MAX)
 
AS
/*  Created by: Vicky
    Date: 20180801
    Task: Refund for esport
    DB: DBTXN/BODB02
    
    Revisions:
    	- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181203@Helen: Apply Service Broker for Other Sports - [Redmine:101611]
        
*/
BEGIN
    SET NOCOUNT ON

    -----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowRefund		BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowRefund		= @AllowRefund		OUTPUT

		IF @AllowRefund = 0
			RETURN
	END
	-----------------------CHECK SERVER-----------------------------------------
	
    DECLARE @tempTrans TABLE (TransID BIGINT)
    DECLARE @handle INT

    ---parse XML
    EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
    INSERT INTO @tempTrans(TransID)
    SELECT t
    FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT) tbl
    EXEC sp_xml_removedocument @handle  
    
	UPDATE	b
	SET [status] = N'Refund'
					,statusID = 103
					,winlost = actual_stake
					,awinlost = 0
					,mwinlost = 0
					,swinlost = 0
					,playercomm = 0
					,comm = 0
					,acomm = 0
					,scomm = 0
				    ,ruben = 1
				    ,statuswinlost = 0
	FROM @tempTrans sr
        INNER JOIN dbo.bettrans b ON  sr.transid = b.transid
        
END
GO
