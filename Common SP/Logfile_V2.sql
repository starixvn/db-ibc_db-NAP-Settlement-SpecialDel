/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Logfile_V2]
    @UserID int,
    @Doing nvarchar(300),
    @extend int
AS
 /*
	Revision:
		--20220329@Mei (DBTrans): Copy from DBTrans.bodb02.dbo.WriteLog_UserLog
		- 20230315@Louisa: return SP due to not in use [Redmine:#183997]
*/

BEGIN

    SET NOCOUNT ON;

	RETURN

    declare @type smallint
    select @type = dbo.f_GetUserlogNo(@@spid) 
    
    if @type = 0
        insert into LogDB.dbo.userlog_T0 (userid,doing,extend) values (@userid,@doing,@extend)
    else if @type = 1
        insert into LogDB.dbo.userlog_T1 (userid,doing,extend) values (@userid,@doing,@extend)
    else if @type = 2
        insert into LogDB.dbo.userlog_T2 (userid,doing,extend) values (@userid,@doing,@extend)
    else 
        insert into LogDB.dbo.userlog_T3 (userid,doing,extend) values (@userid,@doing,@extend)
END