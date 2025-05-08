/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_CheckServerCentral] ()
RETURNS BIT
/*
	Created: 20252802@Aries.Nguyen	
	Task: Enhance
	DB: 
	
	Revisions:
		- 20252802@Aries.Nguyen: Enhance the logic code to decrease the amount of calling SPs into NAP_Set_ServerInfo [RedmineID: #218790]
		- 20250508@Aries: Change instance name DBTRANS [Redmine:#226591]
	Example:			
*/
AS
BEGIN
   RETURN (SELECT CASE WHEN @@SERVERNAME IN ('DB-60\DEVDBTRANS','TESTDBTRANS','SITDBTRANS','DBTRANS', 'DBTRANS\INST2') THEN 1
                       ELSE 0
                  END)

END
GO    