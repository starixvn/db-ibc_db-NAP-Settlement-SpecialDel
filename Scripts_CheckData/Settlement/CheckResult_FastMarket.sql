/*<info serverAlias="DBTP-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

/*Check current result*/
BEGIN
    DECLARE @MatchID INT  = 74580242;
    WITH CTE_FMResource AS (
    SELECT '22100'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [221] "Next 1 Minute"' AS Name UNION ALL
    SELECT '22101'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [221] "Next 1 Minute"' AS Name UNION ALL
    SELECT '221CNT02'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Goals in 1-minute intervals' AS Name UNION ALL
    SELECT '221CNT03'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Corners in 1-minute intervals' AS Name UNION ALL
    SELECT '221CNT04'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Free Kicks in 1-minute intervals' AS Name UNION ALL
    SELECT '221CNT05'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Goal Kicks in 1-minute intervals' AS Name UNION ALL
    SELECT '221CNT06'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Throw Ins in 1-minute intervals' AS Name UNION ALL
    SELECT '221CNT07'   AS ResourceId,'' AS DescResource, '' AS Name UNION ALL
    SELECT '221CNT08'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Penalties in 1-minute intervals' AS Name UNION ALL
    SELECT '22200'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [222] "Next 5 Minutes"' AS Name UNION ALL
    SELECT '22201'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [222] "Next 5 Minutes"' AS Name UNION ALL
    SELECT '22300'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [223] "What will happen first in next 1 min"' AS Name UNION ALL
    SELECT '22301'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [223] "What will happen first in next 1 minute"' AS Name UNION ALL
    SELECT '22400'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [224] "What will happen first in next 5 mins"' AS Name UNION ALL
    SELECT '22401'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [224] "What will happen first in next 5 minutes"' AS Name UNION ALL
    SELECT '22500'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [225] "Next 1 Minute Set Piece"' AS Name UNION ALL
    SELECT '22501'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [225] "Next 1 Minute Set Piece"' AS Name UNION ALL
    SELECT '22600'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [226] "Which combination will happen first in next 1 min"' AS Name UNION ALL
    SELECT '22601'      AS ResourceId,'Time Range: 00->59. 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [226] "Which combination will happen first in next 1 min"' AS Name UNION ALL
    SELECT '22700'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [227] "Which combination will happen first in next 5 mins"' AS Name UNION ALL
    SELECT '22701'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [227]  "Which combination will happen first in next 5 mins"' AS Name  UNION ALL
    SELECT '221WB01'    AS ResourceId,'[homevalue] «s1_start_minute» [awayvalue] «s1_end_minute» [otherinfo] «s1_start_minute»:«s1_start_second», «s1_end_minute»:«s1_end_second» ' AS DescResource, 'Water Break Session 1 row ' AS Name UNION ALL
    SELECT '221WB02'    AS ResourceId,'[homevalue] «s2_start_minute» [awayvalue] «s2_end_minute» [otherinfo] «s2_start_minute»:«s2_start_second», «s2_end_minute»:«s2_end_second» ' AS DescResource, 'Water Break Session 2 row ' AS Name   UNION ALL
    SELECT '22800'    AS ResourceId,'Result-Status of bet type [228] SABA OU TimeMachine' AS DescResource, 'Result-Status  SABA OU TimeMachine' AS Name  UNION ALL
    SELECT '22801'    AS ResourceId,'Time Range: 01:01-02:00.   total-goals scored within digit, value is in {0-9}' AS DescResource, ' Value SABA OU TimeMachine' AS Name  UNION ALL
    SELECT '22900'    AS ResourceId,'Result-Status of bet type [229] SABA HDP TimeMachine' AS DescResource, 'Result-Status  SABA HDP TimeMachine' AS Name  UNION ALL
    SELECT '22901H'    AS ResourceId,'Time Range: 01:01-02:00.  total-goals Home scored within digit, value is in {0-9}' AS DescResource, ' Value Home SABA OU TimeMachine' AS Name  UNION ALL
    SELECT '22901A'    AS ResourceId,'Time Range: 01:01-02:00.   total-goals Away scored within digit, value is in {0-9}' AS DescResource, ' Value Away SABA OU TimeMachine' AS Name 
    ) 
    SELECT r.MatchId,r.ResourceId,fm.Name
         , r.HomeValue,tblH.*,r.AwayValue,tblA.*,r.OtherInfo
         , r.ResultSetting,r.ResultStatusID,r.SettlementStatusID
         , fm.DescResource

    FROM CTE_FMResource AS fm
        INNER JOIN ResultDetail AS  r WITh(nolock) ON r.ResourceId = fm.ResourceId 
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(HomeValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(HomeValue) AND Type = 'p'
                    )AS v
                WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblH(HomeValueJson)
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(HomeValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(AwayValue) AND Type = 'p'
                    )  AS v
                 WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblA(AwayValueJson)
    WHERE r.MatchId = @MatchID  
    ORDER BY r.ResourceId ASC
END


/*Check history result*/
BEGIN
    DECLARE  @MatchID INT  = 94239971  
            ,@ResourceID VARCHAR(20) = '221CNT03' ;

    WITH CTE_FMResource AS (
        SELECT '22100'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [221] "Next 1 Minute"' AS Name UNION ALL
        SELECT '22101'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [221] "Next 1 Minute"' AS Name UNION ALL
        SELECT '221CNT02'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Goals in 1-minute intervals' AS Name UNION ALL
        SELECT '221CNT03'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Corners in 1-minute intervals' AS Name UNION ALL
        SELECT '221CNT04'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Free Kicks in 1-minute intervals' AS Name UNION ALL
        SELECT '221CNT05'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Goal Kicks in 1-minute intervals' AS Name UNION ALL
        SELECT '221CNT06'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Throw Ins in 1-minute intervals' AS Name UNION ALL
        SELECT '221CNT07'   AS ResourceId,'' AS DescResource, '' AS Name UNION ALL
        SELECT '221CNT08'   AS ResourceId,'' AS DescResource, 'Result-Values of event counters of Penalties in 1-minute intervals' AS Name UNION ALL
        SELECT '22200'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [222] "Next 5 Minutes"' AS Name UNION ALL
        SELECT '22201'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [222] "Next 5 Minutes"' AS Name UNION ALL
        SELECT '22300'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [223] "What will happen first in next 1 min"' AS Name UNION ALL
        SELECT '22301'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [223] "What will happen first in next 1 minute"' AS Name UNION ALL
        SELECT '22400'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [224] "What will happen first in next 5 mins"' AS Name UNION ALL
        SELECT '22401'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [224] "What will happen first in next 5 minutes"' AS Name UNION ALL
        SELECT '22500'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [225] "Next 1 Minute Set Piece"' AS Name UNION ALL
        SELECT '22501'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [225] "Next 1 Minute Set Piece"' AS Name UNION ALL
        SELECT '22600'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [226] "Which combination will happen first in next 1 min"' AS Name UNION ALL
        SELECT '22601'      AS ResourceId,'Time Range: 00->59. 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [226] "Which combination will happen first in next 1 min"' AS Name UNION ALL
        SELECT '22700'      AS ResourceId,'0-init,1-running,2-auto-settled,3-manuallyupdated score,4-no ticket(for reserve only),5-manually settled' AS DescResource, 'Result-Status of bet type [227] "Which combination will happen first in next 5 mins"' AS Name UNION ALL
        SELECT '22701'      AS ResourceId,'Time Range: 00->59. BitValue: 1-None,2-Goal,3-Corner,4-FreeKick,5-GoalKick,6-ThrowIn,7-Bookings,8-Penalty' AS DescResource, 'ResourceId of [227]  "Which combination will happen first in next 5 mins"' AS Name  UNION ALL
        SELECT '221WB01'    AS ResourceId,'[homevalue] «s1_start_minute» [awayvalue] «s1_end_minute» [otherinfo] «s1_start_minute»:«s1_start_second», «s1_end_minute»:«s1_end_second» ' AS DescResource, 'Water Break Session 1 row ' AS Name UNION ALL
        SELECT '221WB02'    AS ResourceId,'[homevalue] «s2_start_minute» [awayvalue] «s2_end_minute» [otherinfo] «s2_start_minute»:«s2_start_second», «s2_end_minute»:«s2_end_second» ' AS DescResource, 'Water Break Session 2 row ' AS Name   UNION ALL
        SELECT '22800'    AS ResourceId,'Result-Status of bet type [228] SABA OU TimeMachine' AS DescResource, 'Result-Status  SABA OU TimeMachine' AS Name  UNION ALL
        SELECT '22801'    AS ResourceId,'Time Range: 01:01-02:00.   total-goals scored within digit, value is in {0-9}' AS DescResource, ' Value SABA OU TimeMachine' AS Name  UNION ALL
        SELECT '22900'    AS ResourceId,'Result-Status of bet type [229] SABA HDP TimeMachine' AS DescResource, 'Result-Status  SABA HDP TimeMachine' AS Name  UNION ALL
        SELECT '22901H'    AS ResourceId,'Time Range: 01:01-02:00.  total-goals Home scored within digit, value is in {0-9}' AS DescResource, ' Value Home SABA OU TimeMachine' AS Name  UNION ALL
        SELECT '22901A'    AS ResourceId,'Time Range: 01:01-02:00.   total-goals Away scored within digit, value is in {0-9}' AS DescResource, ' Value Away SABA OU TimeMachine' AS Name 
    ) 
    SELECT top 100 r.MatchId,r.ResourceId,fm.Name
         , r.OldHomeValue
         , tblOH.*
         , r.NewHomeValue
         , tblNH.*
         , r.NewAwayValue
         , r.OldAwayValue
         , r.NewResultStatusID
         , r.NewResultStatusID
         , r.OldSettlementStatusID
         , r.OldSettlementStatusID
         , fm.DescResource
    FROM CTE_FMResource AS fm
        INNER JOIN SettlementResultDetailHistory AS  r WITh(nolock) ON r.ResourceId = fm.ResourceId 
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(OldHomeValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(OldHomeValue) AND Type = 'p'
                    )AS v
                WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblOH(OldHomeValueJson)
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(NewHomeValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(NewHomeValue) AND Type = 'p'
                    )  AS v
                 WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblNH(NewHomeValueJson)
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(OldAwayValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(OldAwayValue) AND Type = 'p'
                    )AS v
                WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblOA(OldAwayValueJson)
        OUTER APPLY (
                SELECT v.Pos
                      ,IIF(bitmap & 1 = 1,1,0) None
                      ,IIF(bitmap & 2 = 2,1,0) Goal
                      ,IIF(bitmap & 4 = 4,1,0) Corner
                      ,IIF(bitmap & 8 = 8,1,0) FreeKick
                      ,IIF(bitmap & 16 = 16,1,0) GoalKick
                      ,IIF(bitmap & 32 = 32,1,0) ThrowIn
                      ,IIF(bitmap & 64 = 64,1,0) Booking
                      ,IIF(bitmap & 128 = 128,1,0) Penalty
                FROM (SELECT 	number AS Pos
			                ,ASCII(SUBSTRING(NewAwayValue, number + 1, 1)) AS bitmap
	                FROM	master.dbo.spt_values
	                WHERE number < DATALENGTH(NewAwayValue) AND Type = 'p'
                    )  AS v
                 WHERE r.ResourceId LIKE '22[1-7]0[1-7]'
                FOR JSON AUTO
        ) AS tblNA(NewAwayValueJson)
    WHERE r.MatchId = @MatchID  and r.resourceId =  @resourceId
    ORDER BY r.ResourceId ASC
END