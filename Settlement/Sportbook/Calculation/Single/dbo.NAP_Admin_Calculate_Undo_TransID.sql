/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Undo_TransID]
	@transIds      		VARCHAR(MAX)

AS
/*
	Created by: 20180801@Vicky
    Task: Incorporate eSports 2.0  
    DB: DBTRANS.BODB02

	Revisions:
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20181016@Vicky: Incorporate Happy 5  [Redmine:#102844]
		
	Param's Explanation:
			
*/ 
BEGIN
	SET NOCOUNT ON
	 
    DECLARE @tempTrans TABLE (TransID BIGINT)
    DECLARE @handle INT
    

    ---parse XML
    EXEC sp_xml_preparedocument @handle OUTPUT, @transIds
    INSERT INTO @tempTrans(TransID)
    SELECT t
    FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT ) tbl
	EXEC sp_xml_removedocument @handle
	
	UPDATE	b
	SET ruben = 0 
		,STATUS = 'running'
		,statusID = 0
		,winlost = 0
		,awinlost = 0
		,mwinlost = 0
		,swinlost = 0
		,playercomm = 0
		,comm = 0
		,acomm = 0
		,scomm = 0
	FROM @tempTrans sr
        INNER JOIN dbo.bettrans b ON  sr.transid = b.transid
END
GO
