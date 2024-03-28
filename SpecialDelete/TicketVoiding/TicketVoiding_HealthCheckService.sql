/*<info serverAlias="DBOIC-bodb_OIC,DBMSG-bodb_Message,DBPRO-bodb02,DBTXN-bodb02,DBONUSER-ON_USER" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_HealthCheckService]
AS
/*	Created by: Raymond
	Date 20200823
	Task: TVS service health check [Redmine: #140141]
	DB: DBMSG.bodb_Message, DBOIC.bodb_OIC, DBTXN.bodb02, DBPRO.bodb02, DBONUSER.ON_USER
	
	Revisions: 
		- 20200215@Raymond: Create new SP [Redmine: #140141]	
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON

	SELECT @@SERVERNAME + '.' + db_name() 
END