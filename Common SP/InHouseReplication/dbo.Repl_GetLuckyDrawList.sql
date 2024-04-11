/*<info serverAlias="DBTCG-bodb02" executers="repl_ap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Repl_GetLuckyDrawList
	 @start         DATETIME2
    ,@count         INT
    ,@back_fix      INT = 0
AS
/*	
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBTCG-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]
*/
BEGIN	
	SET NOCOUNT ON;

    DECLARE @time_start DATETIME2 = DATEADD(MILLISECOND, -@back_fix, @start);
    DECLARE @time_end DATETIME2;
    DECLARE @time_upperbound DATETIME2 = DATEADD(MILLISECOND, -@back_fix, SYSDATETIME());

    SET LOCK_TIMEOUT 1000;

    WITH CTE_Timestamp (RepUpdateTime) AS (
        SELECT TOP (@count) RepUpdateTime
            FROM dbo.LuckyDrawList WITH (NOLOCK, INDEX = IX_RepUpdateTime)
            WHERE RepUpdateTime > @start AND RepUpdateTime < @time_upperbound
            ORDER BY RepUpdateTime
    )
    SELECT @time_end = ISNULL(MAX(repupdatetime), @start) FROM CTE_Timestamp;

    SET LOCK_TIMEOUT -1;

    IF @time_end > @start
    BEGIN
        SELECT   DrawID				
                ,matchid			
                ,custid				
                ,TypeID				
                ,VerificationCode	
                ,DisplayName		
                ,StatusID			
                ,Payout				
                ,Currency			
                ,Remark				
                ,LastModifiedUserID	
                ,CreatedDate		
                ,LastModifiedDate	
                ,ExpiredDate		
                ,IsNotify			
                ,NotifiedDate		
                ,IsTest				
                ,IsLicensee			
                ,SettledDate
				,PoolPrize
				,finalhomescore
				,finalawayscore
                ,RepUpdateTime		
                ,IsDeleted 
                ,SYSDATETIME() AS _FetchedTime
        FROM dbo.LuckyDrawList  WITH (NOLOCK, INDEX = IX_RepUpdateTime)
        WHERE RepUpdateTime > @time_start AND RepUpdateTime <= @time_end
        ORDER BY RepUpdateTime;
    END;
END