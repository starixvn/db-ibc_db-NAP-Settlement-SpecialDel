/*<info serverAlias="DBSIG-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Repl_GetSettlementResultHistory_TicketDetails
	 @start         DATETIME2
    ,@count         INT
    ,@back_fix      INT = 0
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBSIG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment Redmine: #196401
*/
BEGIN	
	SET NOCOUNT ON;

    DECLARE @time_start DATETIME2 = DATEADD(MILLISECOND, -@back_fix, @start);
    DECLARE @time_end DATETIME2;
    DECLARE @time_upperbound DATETIME2 = DATEADD(MILLISECOND, -@back_fix, SYSDATETIME());

    SET LOCK_TIMEOUT 1000;

    WITH CTE_Timestamp (RepUpdateTime) AS (
        SELECT TOP (@count) RepUpdateTime
            FROM dbo.SettlementResultHistory_TicketDetails WITH (NOLOCK, INDEX = IX_RepUpdateTime)
            WHERE RepUpdateTime > @start AND RepUpdateTime < @time_upperbound
            ORDER BY RepUpdateTime
    )
    SELECT @time_end = ISNULL(MAX(RepUpdateTime), @start) FROM CTE_Timestamp;

    SET LOCK_TIMEOUT -1;

    IF @time_end > @start
    BEGIN
        SELECT    SessionID			
                 ,SeqNo				
                 ,Transid			
                 ,ExtraInfo_Before	
                 ,ExtraInfo_After	
                 ,RepUpdateTime  
                 ,IsDeleted		
                 ,SYSDATETIME() AS _FetchedTime
        FROM dbo.SettlementResultHistory_TicketDetails  WITH (NOLOCK, INDEX = IX_RepUpdateTime)
        WHERE repupdatetime > @time_start AND RepUpdateTime <= @time_end
        ORDER BY repupdatetime;
    END;
END