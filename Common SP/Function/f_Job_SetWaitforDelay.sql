/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Job_SetWaitforDelay] ()
RETURNS VARCHAR(100)
/* 
	Created:20200527@Helen
    Task: 
    DB: dbtrans/bodb02 - https://nexdev.net/issues/134854
    
    
	Revisions:
		- 20200527@Helen: support deploy without UM - [Redmine:134854]
		- 20200604@Max: [TVS] Apply new policy into Void Abnormal Bet rules - rollback - [Redmine: #133705]
   
	Notes:
		DECLARE @Delay VARCHAR(100) = ''
		SET @Delay = dbo.f_Job_SetWaitforDelay () 
		WAITFOR DELAY @Delay

*/
AS
BEGIN
    RETURN '00:00:03:100'
END
GO
