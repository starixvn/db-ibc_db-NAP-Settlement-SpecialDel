﻿/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Max
	Date: 20250822
	Task: Fix data 2 tickets SABA.games wrong stake,actual_stake - [Redmine: #236796]
	DB: DBSIC/bodb02
	
*/ 
USE bodb02
GO
			

DECLARE @AffectedList	VARCHAR(MAX)

;WITH TicketData AS (
    SELECT	256389202 AS '@c'
            ,'8/15/2025 0:00:00' AS '@w'
            ,-50 AS '@st'
            ,-50 AS '@ast'
            ,0 AS '@w_dif'
            ,0 AS '@aw_dif'
            ,0 AS '@mw_dif'
            ,0 AS '@sw_dif'
            ,0 AS '@pc_dif'
            ,0 AS '@c_dif'
            ,0 AS '@ac_dif'
            ,0 AS '@sc_dif'
    UNION ALL
    SELECT	255164555 AS '@c'
            ,'8/15/2025 0:00:00' AS '@w'
            ,-10 AS '@st'
            ,-10 AS '@ast'
            ,0 AS '@w_dif'
            ,0 AS '@aw_dif'
            ,0 AS '@mw_dif'
            ,0 AS '@sw_dif'
            ,0 AS '@pc_dif'
            ,0 AS '@c_dif'
            ,0 AS '@ac_dif'
            ,0 AS '@sc_dif'
)
SELECT @AffectedList = CAST((
    SELECT *
    FROM TicketData
    FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))


--update 19999	
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList
	,@IsSiteDB = 1

-- insert routine task
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList
	,@IsSiteDB = 1



