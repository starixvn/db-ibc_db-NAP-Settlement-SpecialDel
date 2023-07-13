/*<info serverAlias="DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[WriteLog_UserLog_Settle]
    @UserID         INT, 
    @MatchID        INT, 
    @ActionID       INT             = 0, 
    @finalhomescore INT             = NULL,
    @finalawayscore INT             = NULL,  
    @hthomescore    INT             = NULL,
    @htawayscore    INT             = NULL,
    @GoalRecord     VARCHAR(50)     = NULL,
    @betstatus      NVARCHAR(50)    = NULL,
    @Remark         VARCHAR(MAX)    = '',   
    @IP             VARCHAR(15)     = '',
    @LogDate        DATETIME        = NULL
AS
/*
    Creator: Daniel
    Date: 2009-12-25
    DB: bodb_CustomerLog
    Task: Insert LOGS for settlement function

    Revision:
        - 20110110@Jamie: Change size of Remark to 500
        - 20160507@Patrick: Add more param @LogDate & change size of Remark to 3000
        - 20170314@Kathy: Add default value [Redmine:#73218]

*/
    SET NOCOUNT ON;

    INSERT INTO dbo.UserLog_Settle
    (   
        UserID,
        LogDate,
        MatchID,
        ActionID,
        [finalhomescore],
        [finalawayscore],  
        [hthomescore],
        [htawayscore],
        [GoalRecord],
        [betstatus],
        [Remark],
        IP
    ) 
    VALUES
    (   
        @UserID,
        CASE WHEN @LogDate IS NULL THEN GETDATE() ELSE @LogDate END,
        @MatchID,
        @ActionID,
        @finalhomescore,
        @finalawayscore,  
        @hthomescore,
        @htawayscore,
        @GoalRecord,
        @betstatus,
        @Remark,    
        @IP
    )
GO