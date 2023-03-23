/*<info serverAlias="DBUserlog-LogTDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_UserLog_WriteLogPreSettlement]
    @UserID int,
    @Doing nvarchar(300),
    @extend int
AS
/* 
	Creator: Kathy  
	Date: 20230306  
	Task: write log
	 
	Revisions:  
	- 20230306@Kathy: Create SP [Redmine:#183997]
		

	Param's Explanation:      
    
*/ 
BEGIN

    SET NOCOUNT ON;

    declare @type smallint
    select @type = dbo.f_GetUserlogNo(@@spid) 
    
    if @type = 0
        insert into dbo.userlog_T4 (userid,doing,extend) values (@userid,@doing,@extend)
    else if @type = 1
        insert into dbo.userlog_T5 (userid,doing,extend) values (@userid,@doing,@extend)
    else if @type = 2
        insert into dbo.userlog_T6 (userid,doing,extend) values (@userid,@doing,@extend)
    else 
        insert into dbo.userlog_T7 (userid,doing,extend) values (@userid,@doing,@extend)
END
GO