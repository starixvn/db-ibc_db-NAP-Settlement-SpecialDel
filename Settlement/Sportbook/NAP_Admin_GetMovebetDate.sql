/*<info serverAlias="DBTXN-bodb02,DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBBAH-bodb02,DBTP-bodb02,DBBAL-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_GetMovebetDate
    @EventTable	VARCHAR(100) = 'match'
	,@MovebetDate SMALLDATETIME OUTPUT
AS
/*
    Created: 20210331@Patrick
    Task: Get current movebet date
    DB: DBTXN-bodb02,DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBBAH-bodb02,DBTP-bodb02,DBBAL-bodb02
    Params:
        @MovebetDate: current movebet date
        
    Revisions:   
        - 20210323@Patrick: Initial [Redmine: #149927]
        - 20210816@Sophia: add DBBAL [Redmine: #154300]
		- 20220719@Louisa: Get MovebetDate for Outright [Redmine:#175251]
        - 20230213@Aries: Migrate Calculate Outright Function to NAP Settlement Site [Redmine:#163971]
*/
BEGIN
    SET NOCOUNT ON
    SELECT @MovebetDate = CONVERT(SMALLDATETIME, VValue)
    FROM dbo.SystemSettings
    WHERE VName = 'MovebetDate'

END