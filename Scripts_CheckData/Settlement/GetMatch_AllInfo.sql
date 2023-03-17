/*********************Get status******************************/
/*
@MatchType	: 1: normal SB,VS soccer,VS Tennis,VS Betradar
						  2: PinGoal
						  3: Fantasy
						  4: Outright
						  5: bitcoin
						  6: Happy5
						  7: Bingoball
						  8: Virtual Cricket
@SportType     : 180-Virtual Soccer, 186-Virtual Tennis, BetRadar-190~199
@InsertTicketBy	: 0:not insert ticket, 1-insert ticket by configuration, 2-copy exists tickets, 3-betdaq ticket'

*/

 DECLARE  @MatchID              INT =   70085092
         ,@MatchType            INT =   1
         ,@SelectedResources	VARCHAR(MAX) =  '' --'<Resources><Resource Id="1" Home="" Away="" IsDetermined="0" /><Resource Id="2" Home="" Away="" IsDetermined="0" /><Resource Id="3" Home="" Away="" IsDetermined="0" /><Resource Id="4" Home="" Away="" IsDetermined="0" /><Resource Id="OT" Home="" Away="" IsDetermined="0" /><Resource Id="01" Home="1" Away="2" IsDetermined="0" /><Resource Id="00" IsDetermined="0" /></Resources>' 
    
USE bodb02;
BEGIN
    DECLARE @LeagueID                   INT 
        ,   @SportType                  INT 
        ,   @SportName                  VARCHAR(100)
        ,   @BetStatus	                VARCHAR(100)
        ,   @ParlayStatus	            VARCHAR(100)
        ,   @Remark	                    VARCHAR(500)
        ,   @EventDate	                DATETIME
        ,   @SettlementStatus           TINYINT
        ,   @AutoSetting                TINYINT
        ,   @HasAutoPayout              TINYINT
        ,   @HasAutoPayoutDirect        TINYINT
        ,   @HasAutoInstant             TINYINT
        ,   @HasAutoFastMarket          TINYINT
        ,   @HasAutoBetBuilder          TINYINT
        ,   @ChangeTime                 DATETIME
        ,   @IsDeadheat                 TINYINT
        ,   @IsDeleted                  TINYINT
        ,   @Status                     VARCHAR(10)
        ,   @OddsStatus                 VARCHAR(10)

        ,   @MovebetDate                SMALLDATETIME
        ,   @IsCalculating              INT
        ,   @HasMarkedTransaction       INT

        ,   @ExternalResultTable	               TINYINT = 0
        ,   @ExternalResultTableName	           NVARCHAR(40)
		,   @ResultTable			               TINYINT = 0
        ,   @ResultTableName			           NVARCHAR(40)


        ,   @sql                                    NVARCHAR(4000)
        ,   @handle					                INT

        ,   @LeagueGroupID				            SMALLINT = 0
 
    IF OBJECT_ID(N'tempdb..#MatchLifeCycle') IS NOT NULL
    BEGIN
        DROP TABLE #MatchLifeCycle
    END 
    CREATE TABLE #MatchLifeCycle (ServerName VARCHAR(50),TableData VARCHAR(100), UserID INT, ActionName VARCHAR(100), SPName VARCHAR(64), Remark VARCHAR(MAX), Created DATETIME)    
    

    IF OBJECT_ID(N'tempdb..#CountTicket') IS NOT NULL
    BEGIN
        DROP TABLE #CountTicket
    END 
    CREATE TABLE #CountTicket (ServerName VARCHAR(20), TicketType  VARCHAR(20),Bettype INT,BetID INT, Status VARCHAR(20), Total INT, GroupName VARCHAR(20), SettleType VARCHAR(20), GroupType VARCHAR(20), ResourceID VARCHAR(20), typenamee VARCHAR(50))    



    SELECT @MovebetDate = CONVERT(SMALLDATETIME, VValue)
    FROM dbo.SystemSettings
    WHERE VName = 'MovebetDate'

    
    IF @MatchType = 1
    BEGIN
        SELECT  @SportType                  = m.sporttype
            ,   @SportName                  = s.SportName
	        ,   @BetStatus		            = m.betstatus
		    ,   @EventDate		            = m.eventdate
            ,   @SettlementStatus           = m.SettlementStatus
            ,   @AutoSetting                = m.AutoSetting
            ,   @HasAutoPayout              = CASE WHEN (m.AutoSetting & 1) = 1 THEN 1 ELSE 0 END
            ,   @HasAutoPayoutDirect        = CASE WHEN (m.AutoSetting & 16) = 16 THEN 1 ELSE 0 END
            ,   @HasAutoInstant             = CASE WHEN (m.AutoSetting & 2) = 2 THEN 1 ELSE 0 END
            ,   @HasAutoFastMarket          = CASE WHEN (m.AutoSetting & 4) = 4 THEN 1 ELSE 0 END
            ,   @HasAutoBetBuilder          = CASE WHEN (m.AutoSetting & 8) = 8 THEN 1 ELSE 0 END
            ,   @Remark                     = CONCAT(  'SetSta: ',settlementstatus,
                                                       '; LH: ', livehomescore,
                                                       '; LA: ',liveawayscore,
                                                       '; FH: ', finalhomescore,
                                                       '; FA: ',finalawayscore,
                                                       '; HH: ', hthomescore,
                                                       '; HA: ',htawayscore,            
                                                       '; EvDa: ', eventdate, 
                                                       '; EvSta: ', eventstatus) 
	    FROM dbo.match m WITH(NOLOCK)
	        LEFT JOIN  [dbo].[Sports] AS s ON m.Sporttype = s.Sporttype
        WHERE m.matchid = @MatchID

        SELECT   @ExternalResultTable       =	r.ExternalResultTable 
                ,@ExternalResultTableName   =   CASE WHEN r.ExternalResultTable  = 0 THEN 'None'
                                                     WHEN r.ExternalResultTable  = 1 THEN 'ProviderExternalResultDetail'
                                                     WHEN r.ExternalResultTable  = 2 THEN 'ProviderExternalResultDetailOS'
                                                     WHEN r.ExternalResultTable  = 3 THEN 'ProviderExternalResultDetailES'
                                                END
		        ,@ResultTable			    =	r.ResultTable 
                ,@ResultTableName           =   CASE WHEN r.ResultTable  = 0 THEN 'Match'
                                                     WHEN r.ResultTable  = 1 THEN 'ResultDetail'
                                                     WHEN r.ResultTable  = 2 THEN 'ResultDetailOS'
                                                     WHEN r.ResultTable  = 3 THEN 'ResultDetailES'
                                                END
	    FROM dbo.SettlementResultTableSetting r (NOLOCK)
	    WHERE r.Sporttype = @Sporttype

       
      
        INSERT INTO #CountTicket(ServerName, TicketType,Bettype,BetID, Status, Total,GroupName, SettleType, GroupType, ResourceID, typenamee)
        SELECT t.ServerName
             , t.TicketType
             , t.Bettype
             , t.BetID
             , CASE WHEN statusID = 0   THEN 'Running'		
                     WHEN statusID = 101 THEN 'Reject'			
                     WHEN statusID = 102 THEN 'Void'			
                     WHEN statusID = 103 THEN 'Refund'			
                     WHEN statusID = 111 THEN 'Draw'			
                     WHEN statusID = 112 THEN 'Won'			
                     WHEN statusID = 113 THEN 'Lose'
                     ELSE CAST(statusID AS VARCHAR(5))
                END AS Status
            ,   Total
            ,b.GroupName, st.SettleType, st.GroupType, st.ResourceID, bt.typenamee
        FROM(
            SELECT  'DBTXN' AS ServerName, 'Single' AS TicketType, bettype,ISNULL(BetID,0) AS BetID,  statusID, count(1) AS Total FROM [bodb02].[dbo].bettrans WITH(NOLOCK) WHERE matchId = @MatchID AND SiteDBGroupID = 0 GROUP BY bettype,BetID, statusID
            UNION ALL
            SELECT  'DBTXN' AS ServerName, 'Parlay' AS TicketType, bettype, 0 AS BetID, statusID, count(1) AS Total FROM [bodb02].[dbo].bettransm WITH(NOLOCK) WHERE matchId = @MatchID AND SiteDBGroupID = 0 GROUP BY bettype, statusID
            UNION ALL
            SELECT  'DBSIG01' AS ServerName, 'Single' AS TicketType, bettype,ISNULL(BetID,0) AS BetID, statusID, count(1) AS Total FROM DBSIG01.[bodb02].[dbo].bettrans WITH(NOLOCK) WHERE matchId = @MatchID GROUP BY bettype,BetID,statusID
            UNION ALL
            SELECT  'DBSIG01' AS ServerName, 'Parlay' AS TicketType, bettype, 0 AS BetID,statusID, count(1) AS Total FROM DBSIG01.[bodb02].[dbo].bettransm WITH(NOLOCK) WHERE matchId = @MatchID GROUP BY bettype,statusID
            UNION ALL
            SELECT  'DBSIG02' AS ServerName, 'Single' AS TicketType, bettype, ISNULL(BetID,0) AS BetID,statusID, count(1) AS Total FROM DBSIG02.[bodb02].[dbo].bettrans WITH(NOLOCK) WHERE matchId = @MatchID GROUP BY bettype,BetID,statusID
            UNION ALL
            SELECT  'DBSIG02' AS ServerName, 'Parlay' AS TicketType, bettype, 0 AS BetID,statusID, count(1) AS Total FROM DBSIG02.[bodb02].[dbo].bettransm WITH(NOLOCK) WHERE matchId = @MatchID GROUP BY bettype,statusID			
        ) AS t
        LEFT JOIN f_Set_GetGroupBettypes() AS b ON t.Bettype = b.Bettype
        LEFT JOIN [dbo].[bettype] AS bt  WITH(NOLOCK) ON t.Bettype = bt.typeid
        LEFT JOIN SettlementSpecialBettypeProfile AS st WITH(NOLOCK) ON t.Bettype = st.Bettype AND st.SportType = @Sporttype AND t.BetID = st.BetID;
	    

        

        SET @IsCalculating = ISNULL((SELECT TOP 1 1 FROM dbo.Single_Calculate_Queue WITH (NOLOCK) WHERE matchid = @matchid  AND IsCalculating IN (0, 1)),0)
        SET @HasMarkedTransaction = ISNULL((SELECT TOP 1 1 FROM dbo.MarkedTransaction WITH (NOLOCK) WHERE matchid = @matchid),0)

        /**get current status match**/
        SELECT  @MatchID                AS MatchID 
            ,   @SportType              AS SportType
            ,   @SportName              AS SportName
            ,   @BetStatus              AS BetStatus
            ,   @EventDate              AS EventDate
            ,   @MovebetDate            AS MovebetDate
            ,   @IsCalculating          AS Calculating
            ,   @Remark                 AS Remark
            ,   @ParlayStatus           AS ParlayStatus
            ,   @HasMarkedTransaction   AS HasMarkedTransaction
            ,   CASE WHEN @SettlementStatus = 1  THEN 'Pending ( Hold by KST)'
                     WHEN @SettlementStatus = 2  THEN 'Undecided (Hold by KST)'
                     WHEN @SettlementStatus = 4  THEN 'UnderSettlement'
                     WHEN @SettlementStatus = 8  THEN 'SystemSettlement'
                     WHEN @SettlementStatus = 16 THEN 'MTD Hold (Hold by KST or MTD)'
                     WHEN @SettlementStatus = 32 THEN 'Mark Refund All'
                     WHEN @SettlementStatus = 64 THEN 'HoldKey (Hold by Trader/Suspender)'
                     ELSE CAST(@SettlementStatus AS VARCHAR(20))
                END AS SettlementStatus
            ,   @HasAutoPayout         AS HasAutoPayout
            ,   @HasAutoPayoutDirect   AS HasAutoPayoutDirect
            ,   @HasAutoInstant        AS HasAutoInstant
            ,   @HasAutoFastMarket     AS HasAutoFastMarket
            ,   @HasAutoBetBuilder     AS HasAutoBetBuilder
        
        SELECT 'All' AS ServerName,  SUM(TOTAL) AS Total,  NULL AS TicketType, NULL AS Bettype, NULL AS BetID, NULL AS Status, NULL AS GroupName, NULL AS  SettleType, NULL AS GroupType, NULL AS  ResourceID, NULL AS  typenamee FROM #CountTicket
        UNION ALL 
        SELECT 'All' AS ServerName ,SUM(TOTAL), NULL AS TicketType, NULL AS Bettype, NULL AS BetID, NULL AS Status, NULL AS GroupName, SettleType, NULL AS GroupType, NULL AS  ResourceID, NULL AS  typenamee FROM #CountTicket  GROUP BY SettleType
        UNION ALL 
        SELECT ServerName, SUM(TOTAL) AS Total,  NULL AS TicketType, NULL AS Bettype, NULL AS BetID, NULL AS Status, NULL AS GroupName, NULL AS  SettleType, NULL AS GroupType, NULL AS  ResourceID, NULL AS  typenamee FROM #CountTicket  GROUP BY ServerName
        UNION ALL 
        SELECT ServerName ,SUM(TOTAL), NULL AS TicketType, NULL AS Bettype, NULL AS BetID, NULL AS Status, NULL AS GroupName, SettleType, NULL AS GroupType, NULL AS  ResourceID, NULL AS  typenamee FROM #CountTicket GROUP BY ServerName,SettleType
        UNION ALL 
        SELECT ServerName, SUM(TOTAL) AS Total, TicketType, NULL AS Bettype, NULL AS BetID, NULL AS Status, NULL AS GroupName, NULL AS  SettleType, NULL AS GroupType, NULL AS  ResourceID, NULL AS  typenamee FROM #CountTicket GROUP BY ServerName,TicketType
        UNION ALL 
        SELECT ServerName,Total,TicketType,Bettype,BetID,Status,GroupName, SettleType, GroupType, ResourceID, typenamee FROM #CountTicket 



            ;WITH CTE_MatchParlay AS (
                SELECT DISTINCT repla.matchid
                FROM [dbo].[bettransm] AS repla
                WHERE repla.refno in (SELECT  refno FROM [dbo].[bettransm]  AS m  WITH(NOLOCK) WHERE matchId = @Matchid))
                SELECT  @ParlayStatus = STRING_AGG (CONCAT(cte.matchid,'-',m.eventstatus,'-',s.SportName),';'
            )
            FROM CTE_MatchParlay AS cte
                LEFT JOIN dbo.match m WITH(NOLOCK)  ON m.matchid = cte.matchid
	            LEFT JOIN  [dbo].[Sports] AS s ON m.Sporttype = s.Sporttype;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBLOG' AS ServerName
                ,   'bodb_CustomerLog.dbo.UserLog_Settle' AS TableData
                ,   UserID
                ,   CASE WHEN ActionID = 81002 THEN 'Update Settlement Status to IsPending -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81003 THEN 'Update Settlement Status to IsUndecided -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81004 THEN 'Update Settlement Status to IsUnderSettlement -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81005 THEN 'Update Settlement Status to IsMTDHold -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81018 THEN 'Update Settlement Status to IsRefund -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81019 THEN 'Update Settlement Status to Hold Key -> NAP_Set_SettlementStatusUpd'

                         WHEN ActionID = 100 THEN 'Calculate All -> Admin_Settlement_1'
                         WHEN ActionID = 101 THEN 'Calculate FT -> Admin_Settlement_1'
                         WHEN ActionID = 102 THEN 'Calculate HT -> Admin_Settlement_1'
                         WHEN ActionID = 103 THEN 'Undo Settlement -> Admin_Settlement_1'

                         WHEN ActionID = 104 THEN 'Calculate Mix Parlay -> Admin_Settlement_Parlay'
                         WHEN ActionID = 105 THEN 'Undo Mix Parlay Settlement -> Admin_Settlement_Parlay'
                         WHEN ActionID = 106 THEN 'Refund Mix Parlay FT -> Admin_Settlement_Parlay'
                         WHEN ActionID = 107 THEN 'Refund Mix Parlay All -> Admin_Settlement_Parlay'

                         WHEN ActionID = 108 THEN 'Calculate FGLG -> Admin_Settlement_FGLG'
                         WHEN ActionID = 109 THEN 'Refund All -> Admin_Settlement_Refund_All'
                         WHEN ActionID = 81028 THEN  'Calculate Parlay -> Admin_Settlement_FGLG'
				         WHEN ActionID = 81029 THEN  'Refund Parlay -> Admin_Settlement_FGLG'
				         WHEN ActionID = 81030 THEN  'Undo FGLG -> Admin_Settlement_FGLG'
			             ELSE CAST(ActionID AS VARCHAR(50)) 
		            END AS ActionName
                ,   Remark
                ,   LogDate AS Created
            FROM DBLOG.bodb_CustomerLog.dbo.UserLog_Settle WITH(NOLOCK)
            WHERE MatchId = @MatchID


            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,   'bodb_CustomerLog.dbo.UserLog_Settle' AS TableData
                ,   UserID
                ,   CASE WHEN ActionID = 81002 THEN 'Update Settlement Status to IsPending -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81003 THEN 'Update Settlement Status to IsUndecided -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81004 THEN 'Update Settlement Status to IsUnderSettlement -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81005 THEN 'Update Settlement Status to IsMTDHold -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81018 THEN 'Update Settlement Status to IsRefund -> NAP_Set_SettlementStatusUpd'
			             WHEN ActionID = 81019 THEN 'Update Settlement Status to Hold Key -> NAP_Set_SettlementStatusUpd'

                         WHEN ActionID = 100 THEN 'Calculate All -> Admin_Settlement_1'
                         WHEN ActionID = 101 THEN 'Calculate FT -> Admin_Settlement_1'
                         WHEN ActionID = 102 THEN 'Calculate HT -> Admin_Settlement_1'
                         WHEN ActionID = 103 THEN 'Undo Settlement -> Admin_Settlement_1'

                         WHEN ActionID = 104 THEN 'Calculate Mix Parlay -> Admin_Settlement_Parlay'
                         WHEN ActionID = 105 THEN 'Undo Mix Parlay Settlement -> Admin_Settlement_Parlay'
                         WHEN ActionID = 106 THEN 'Refund Mix Parlay FT -> Admin_Settlement_Parlay'
                         WHEN ActionID = 107 THEN 'Refund Mix Parlay All -> Admin_Settlement_Parlay'

                         WHEN ActionID = 108 THEN 'Calculate FGLG -> Admin_Settlement_FGLG'
                         WHEN ActionID = 109 THEN 'Refund All -> Admin_Settlement_Refund_All'
			             ELSE CAST(ActionID AS VARCHAR(50)) 
		            END AS ActionName
                ,   Remark
                ,   LogDate AS Created
            FROM DBTXN.bodb_CustomerLog.dbo.UserLog_Settle  WITH(NOLOCK)
            WHERE MatchId = @MatchID 


            /***************Single_Calculate_Queue*********************/

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'Single_Calculate_Queue' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None'  AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM Single_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'Single_Calculate_Queue' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None'  AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM DBSIG01.[bodb02].[dbo].Single_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'Single_Calculate_Queue' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None'  AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM DBSIG02.[bodb02].[dbo].Single_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;


            /***************Parlay_Calculate_Queue*********************/

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'Parlay_Calculate_Queue' AS TableData
                ,   Creator AS UserID
                ,   Action + '-> None' AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM Parlay_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'Parlay_Calculate_Queue' AS TableData
                ,   Creator AS UserID
                ,   Action + '-> None' AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM  DBSIG01.[bodb02].[dbo].Parlay_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'Parlay_Calculate_Queue' AS TableData
                ,   Creator AS UserID
                ,   Action + '-> None' AS ActionName
                ,   sqlCommand AS Remark
                ,   Starttime AS Created
            FROM  DBSIG02.[bodb02].[dbo].Parlay_Calculate_Queue WITH(NOLOCK)
            WHERE MatchId = @MatchID;




             /***************Settled_Message*********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'Settled_Message' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None' AS ActionName
                ,   ISNULL(Message,'') + ISNULL(Warning,'') AS Remark
                ,   Starttime AS Created
            FROM Settled_Message WITH(NOLOCK)
            WHERE MatchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'Settled_Message' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None' AS ActionName
                ,   ISNULL(Message,'') + ISNULL(Warning,'') AS Remark
                ,   Starttime AS Created
            FROM DBSIG01.[bodb02].[dbo].Settled_Message WITH(NOLOCK)
            WHERE MatchId = @MatchID;


            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'Settled_Message' AS TableData
                ,   AdminId AS UserID
                ,   Action + '-> None' AS ActionName
                ,   ISNULL(Message,'') + ISNULL(Warning,'') AS Remark
                ,   Starttime AS Created
            FROM DBSIG02.[bodb02].[dbo].Settled_Message WITH(NOLOCK)
            WHERE MatchId = @MatchID;
    

            /***************BalanceNegative*********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'BalanceNegative' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName
                ,   CONCAT('TotalCust:',  Count(1)) AS Remark
                ,   ExecDate AS Created
            FROM dbo.BalanceNegative WITH(NOLOCK)
            WHERE MatchId = @MatchID
            GROUP BY ExecDate, ActionID; 

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'BalanceNegative' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName
                ,   CONCAT('TotalCust:',  Count(1)) AS Remark
                ,   ExecDate AS Created
            FROM DBSIG01.[bodb02].[dbo].BalanceNegative WITH(NOLOCK)
            WHERE MatchId = @MatchID
            GROUP BY ExecDate, ActionID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'BalanceNegative' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName
                ,   CONCAT('TotalCust:',  Count(1)) AS Remark
                ,   ExecDate AS Created
            FROM DBSIG02.[bodb02].[dbo].BalanceNegative WITH(NOLOCK)
            WHERE MatchId = @MatchID
            GROUP BY ExecDate, ActionID;



            /***************BalanceNegativeHistory*********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT  'DBTXN' AS ServerName
                ,   'BalanceNegativeHistory' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName 
                ,  CONCAT('Balance: ', Balance, ';TotalBalance: ', TotalBalance) AS Remark
                ,   LogDate AS Created 
            FROM BalanceNegativeHistory WITH(NOLOCK) 
            WHERE matchID =@MatchID

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT  'DBSIG01' AS ServerName
                ,   'BalanceNegativeHistory' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName 
                ,  CONCAT('Balance: ', Balance, ';TotalBalance: ', TotalBalance) AS Remark
                ,   LogDate AS Created 
            FROM DBSIG01.[bodb02].[dbo].BalanceNegativeHistory WITH(NOLOCK) 
            WHERE matchID =@MatchID

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT  'DBSIG02' AS ServerName
                ,   'BalanceNegativeHistory' AS TableData
                ,   NULL AS UserID
                ,   CAST(ActionID AS VARCHAR(10)) + '-> None' AS ActionName 
                ,  CONCAT('Balance: ', Balance, ';TotalBalance: ', TotalBalance) AS Remark
                ,   LogDate AS Created 
            FROM DBSIG02.[bodb02].[dbo].BalanceNegativeHistory WITH(NOLOCK) 
            WHERE matchID =@MatchID
    

             /***************DBTP.bodb02.dbo.Match_Tracking *********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTP' AS ServerName
                ,   'Match_Tracking' AS TableData
                ,   NULL AS UserID
                ,   'Update Match -> None' AS ActionName 
                ,   CONCAT('SetSta: ',settlementstatus,
                           '; LH: ', livehomescore,
                           '; LA: ',liveawayscore,
                           '; FH: ', finalhomescore,
                           '; FA: ',finalawayscore,
                           '; HH: ', hthomescore,
                           '; HA: ',htawayscore,            
                           '; EvDa: ', eventdate, 
                           '; EvSta: ', eventstatus) AS Remark
                            , CASE WHEN DATEDIFF(second,changetime,UpdateTime) < 5 THEN changetime ELSE UpdateTime END  AS Created 
            FROM DBTP.bodb02.dbo.Match_Tracking 
            WHERE matchId = @MatchID;


             /***************ParlaySettlement_trace *********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,   'ParlaySettlement_trace' AS TableData
                ,   NULL AS UserID
                ,   'Parlay Running -> None' AS ActionName 
                ,   doing AS Remark
                ,   logtime  AS Created 
            FROM dbo.ParlaySettlement_trace
            WHERE matchId = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,   'ParlaySettlement_trace' AS TableData
                ,   NULL AS UserID
                ,   'Parlay Running -> None' AS ActionName 
                ,   doing AS Remark
                ,   logtime  AS Created 
            FROM DBSIG01.[bodb02].[dbo].ParlaySettlement_trace
            WHERE matchId = @MatchID;


            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,   'ParlaySettlement_trace' AS TableData
                ,   NULL AS UserID
                ,   'Parlay Running -> None' AS ActionName 
                ,   doing AS Remark
                ,   logtime  AS Created 
            FROM DBSIG02.[bodb02].[dbo].ParlaySettlement_trace
            WHERE matchId = @MatchID;

             /***************TempVariableNumberHistory *********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'TempVariableNumberHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   'Lock Match' AS Remark
                ,   CreatedDateTime AS Created
            FROM TempVariableNumberHistory WITH(NOLOCK)
            WHERE KeyValue = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'TempVariableNumberHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   'Lock Match' AS Remark
                ,   CreatedDateTime AS Created
            FROM DBSIG01.[bodb02].[dbo].TempVariableNumberHistory WITH(NOLOCK)
            WHERE KeyValue = @MatchID;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'TempVariableNumberHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   'Lock Match' AS Remark
                ,   CreatedDateTime AS Created
            FROM DBSIG02.[bodb02].[dbo].TempVariableNumberHistory WITH(NOLOCK)
            WHERE KeyValue = @MatchID;


            /***************[ParlayLockingHistory] *********************/
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBTXN' AS ServerName
                ,  'ParlayLockingHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   CONCAT('Lock Parlay(',Session,')') AS Remark
                ,   CreatedDate AS Created
            FROM [ParlayLockingHistory] WITH(NOLOCK)
            WHERE [MatchId] = @MatchID
            GROUP BY SPName, CreatedDate, Action,Session;
    
    
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG01' AS ServerName
                ,  'ParlayLockingHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   CONCAT('Lock Parlay(',Session,'):') AS Remark
                ,   CreatedDate AS Created
            FROM DBSIG01.[bodb02].[dbo].[ParlayLockingHistory] WITH(NOLOCK)
            WHERE [MatchId] = @MatchID
            GROUP BY SPName, CreatedDate, Action,Session;

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBSIG02' AS ServerName
                ,  'ParlayLockingHistory' AS TableData
                ,   NULL AS UserID
                ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
                ,   CONCAT('Lock Parlay(',Session,'):') AS Remark
                ,   CreatedDate AS Created
            FROM DBSIG02.[bodb02].[dbo].[ParlayLockingHistory] WITH(NOLOCK)
            WHERE [MatchId] = @MatchID
            GROUP BY SPName, CreatedDate, Action,Session;


    
            SET @sql = CONCAT('SELECT *
                           FROM OPENQUERY([DBSIG01], ''SELECT  ''''DBSIG01'''' AS ServerName
                                                      ,''''SiteDB_SettlementService_CalculationLog'''' AS TableData 
                                                      ,NULL AS UserID
                                                      ,CONCAT(SettlementAction,'''' -> None '''') AS Action
                                                      ,CONCAT(''''FunctionName: '''',FunctionName, ''''TableName: '''', TableName)
                                                      ,[LogDate] AS Created
                                                FROM [bodb02].[dbo].[SiteDB_SettlementService_CalculationLog] 
                                                WHERE [MatchId] = ',@MatchID,''' )')
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            EXEC sp_executesql @sql


            SET @sql = CONCAT('SELECT *
                               FROM OPENQUERY([DBSIG02], ''SELECT  ''''DBSIG02'''' AS ServerName
                                                          ,''''SiteDB_SettlementService_CalculationLog'''' AS TableData 
                                                          ,NULL AS UserID
                                                          ,CONCAT(SettlementAction,'''' -> None '''')  AS Action
                                                          ,CONCAT(''''FunctionName: '''',FunctionName, ''''TableName: '''', TableName)
                                                          ,[LogDate] AS Created
                                                    FROM [bodb02].[dbo].[SiteDB_SettlementService_CalculationLog] 
                                                    WHERE [MatchId] = ',@MatchID,''' )')
            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            EXEC sp_executesql @sql

            INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
            SELECT 'DBPRO' AS ServerName
                ,  'ResultDetail' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,ResultStatusID: ', ResultStatusID,
                           ' ,SettlementStatusID: ', SettlementStatusID,
                           ' ,ResultSetting: ', ResultSetting,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ResultDetail WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL 

            SELECT 'DBPRO' AS ServerName
                ,  'ResultDetailOS' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,ResultStatusID: ', ResultStatusID,
                           ' ,SettlementStatusID: ', SettlementStatusID,
                           ' ,ResultSetting: ', ResultSetting,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ResultDetailOS WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL 

            SELECT 'DBPRO' AS ServerName
                ,  'ResultDetailES' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,ResultStatusID: ', ResultStatusID,
                           ' ,SettlementStatusID: ', SettlementStatusID,
                           ' ,ResultSetting: ', ResultSetting,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ResultDetailES WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'ProviderExternalResultDetail' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,SourceID: ', SourceID,
                           ' ,MatchId3rd: ', MatchId3rd,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ProviderExternalResultDetail WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'ProviderExternalResultDetailOS' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,SourceID: ', SourceID,
                           ' ,MatchId3rd: ', MatchId3rd,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ProviderExternalResultDetailOS WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'ProviderExternalResultDetailES' AS TableData
                ,   0 AS UserID
                ,   'Add Result -> None'  AS ActionName
                ,   CONCAT('ResourceId: ',ResourceId, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,SourceID: ', SourceID,
                           ' ,MatchId3rd: ', MatchId3rd,
                           ' ,OtherInfo: ', OtherInfo) AS Remark
                ,   CreateDate AS Created
            FROM DBPRO.[bodb02].[dbo].ProviderExternalResultDetailES WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'AutoPayoutResult' AS TableData
                ,   0 AS UserID
                ,   'Write Log Result -> None'  AS ActionName
                ,   CONCAT('CalculationType: ',CalculationType, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,SourceID: ', SourceID,
                           ' ,StatusId: ', StatusId,
                           ' ,TryCount: ', TryCount) AS Remark
                ,   CreatedDate AS Created
            FROM DBPRO.[bodb02].[dbo].AutoPayoutResult WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'AutoPayoutResult' AS TableData
                ,   0 AS UserID
                ,   'Write Log Result -> None'  AS ActionName
                ,   CONCAT('ResourceID: ',ResourceID, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,StatusId: ', StatusId) AS Remark
                ,   CreatedDate AS Created
            FROM DBPRO.[bodb02].[dbo].AutoPayoutResultOS WITH(NOLOCK)
            WHERE MatchId = @MatchID

            UNION ALL

            SELECT 'DBPRO' AS ServerName
                ,  'ProviderResultDetail (soccer only)' AS TableData
                ,   0 AS UserID
                ,   'Write Log Result -> None'  AS ActionName
                ,   CONCAT('TypeID: ',TypeID, 
                           ' ,HomeValue: ', HomeValue,
                           ' ,AwayValue: ', AwayValue,
                           ' ,SourceID: ', SourceID,
                           ' ,IsConfirmed: ', IsConfirmed) AS Remark
                ,   CreatedDate AS Created
            FROM DBPRO.[bodb02].[dbo].ProviderResultDetail WITH(NOLOCK)
            WHERE MatchId = @MatchID
    END
    ELSE IF @MatchType = 4
    BEGIN
        SELECT  @LeagueID   = leagueid
            ,   @EventDate  = eventdate
            ,   @ChangeTime = changetime
            ,   @IsDeadheat = IsDeadheat
            ,   @IsDeleted  = IsDeleted
            ,   @Status     = status
            ,   @OddsStatus = oddsstatus  
        FROM bodb02.dbo.outright WITH(NOLOCK)
        WHERE orid = @Matchid;

        SELECT  @LeagueID       AS LeagueID
            ,   @EventDate      AS EventDate
            ,   @ChangeTime     AS ChangeTime
            ,   @IsDeadheat     AS IsDeadheat
            ,   @IsDeleted      AS IsDeleted
            ,   @Status         AS Status
            ,   @OddsStatus     AS OddsStatus
        
        INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
        SELECT  'DBLOG' AS ServerName
            ,   'UserLog_SettleOutright' AS TableData 
            ,   UserID
	        ,   CASE WHEN ActionID = 136 THEN 'CAL-WON-LOSE'
                     WHEN ActionID = 138 THEN 'CAL-REFUND'
                     WHEN ActionID = 145 THEN 'UNDO'
                     ELSE 'Unknow'
                END AS ActionName
	        ,   Remark
	        ,   LogDate AS Created
        FROM DBLOG.bodb_CustomerLog.dbo.UserLog_SettleOutright WITH(NOLOCK)
        WHERE MatchID = @Matchid;

        /***************TempVariableNumberHistory *********************/
         INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
         SELECT 'DBTXN' AS ServerName
             ,  'TempVariableNumberHistory' AS TableData
             ,   NULL AS UserID
             ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
             ,   'Lock Match' AS Remark
             ,   CreatedDateTime AS Created
         FROM TempVariableNumberHistory WITH(NOLOCK)
         WHERE KeyValue = @MatchID AND KeyID = 2;

         INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
         SELECT 'DBSIG01' AS ServerName
             ,  'TempVariableNumberHistory' AS TableData
             ,   NULL AS UserID
             ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
             ,   'Lock Match' AS Remark
             ,   CreatedDateTime AS Created
         FROM DBSIG01.[bodb02].[dbo].TempVariableNumberHistory WITH(NOLOCK)
         WHERE KeyValue = @MatchID AND KeyID = 2;

         INSERT INTO #MatchLifeCycle(ServerName,TableData, UserID, ActionName, Remark, Created)
         SELECT 'DBSIG02' AS ServerName
             ,  'TempVariableNumberHistory' AS TableData
             ,   NULL AS UserID
             ,   CASE WHEN Action = 'I' THEN 'INSERT'  ELSE 'Delete' END + '-> ' + CASE WHEN SPName IS NULL OR SPName != '' THEN SPName  ELSE 'None' END AS ActionName
             ,   'Lock Match' AS Remark
             ,   CreatedDateTime AS Created
         FROM DBSIG02.[bodb02].[dbo].TempVariableNumberHistory WITH(NOLOCK)
         WHERE KeyValue = @MatchID AND KeyID = 2;
    END

    IF @SelectedResources IS NOT NULL AND @SelectedResources != ''
    BEGIN
        DECLARE @tmpResourcesWeb TABLE(ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000))

        IF OBJECT_ID(N'tempdb..#tmpSelectedRID') IS NOT NULL
        BEGIN
            DROP TABLE #tmpSelectedRID
        END 
        CREATE TABLE #tmpSelectedRID (ResourceID VARCHAR(20), HomeValue VARCHAR(2000), AwayValue VARCHAR(2000),
								  BetType SMALLINT, BetID BIGINT, pfID SMALLINT, RoundID VARCHAR(10), OrdNo SMALLINT,
								  isFinal BIT, RoundName VARCHAR(20), GroupType VARCHAR(2), OddsType SMALLINT, RefResourceId VARCHAR(20)
								  ,PRIMARY KEY (BetType,BetID))
        DECLARE @DummyResourceIds			VARCHAR(MAX) = ''
            ,   @DummyResourceResults		VARCHAR(MAX) = ''
            ,   @TotalPointHomeValue		VARCHAR(50)		= NULL
			,   @TotalPointAwayValue		VARCHAR(50)		= NULL

        EXEC sp_xml_preparedocument @handle OUTPUT, @SelectedResources
		INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
		SELECT Id, ISNULL(Home,''), ISNULL(Away,'')
		FROM OPENXML(@handle,'Resources/Resource',1) WITH( Id	VARCHAR(20)
															,Home VARCHAR(50)
															,Away VARCHAR(50)
											) AS tbl
		EXEC sp_xml_removedocument @handle

        SELECT @LeagueGroupID = ISNULL(l.LeagueGroupID, 0)
            ,  @sportType =  m.sporttype
  	    FROM	DBPRO.BODB02.dbo.match m WITH (NOLOCK)
		    INNER JOIN DBPRO.BODB02.dbo.League l WITH(NOLOCK)  ON m.leagueid = l.leagueid
  	    WHERE   m.matchid = @matchid

        SELECT	@DummyResourceIds = @DummyResourceIds + s.ResourceID + ','
		FROM	dbo.SettlementSpecialBettypeProfile s WITH(NOLOCK)
			INNER JOIN @tmpResourcesWeb t
				ON s.RefResourceId = t.ResourceID
		WHERE	s.SportType = @sportType
				AND s.RefResourceId IS NOT NULL
				AND 1 = CASE WHEN @LeagueGroupID = 113 AND @sportType = 1 THEN 0
						ELSE 1 END
		
		IF @DummyResourceIds <> ''
		BEGIN
			EXEC dbo.NAP_Set_DummyResourceResult
				@MatchID = @MatchID
				,@sportType = @sportType
				,@WebResourceResult = @SelectedResources
				,@DummyResourceIds = @DummyResourceIds
				,@DummyResourceResults = @DummyResourceResults OUTPUT

			EXEC sp_xml_preparedocument @handle OUTPUT, @DummyResourceResults
			INSERT INTO @tmpResourcesWeb(ResourceID, HomeValue, AwayValue)
			SELECT Id, Home, Away
			FROM OPENXML(@handle,'root/r',1) WITH( Id	VARCHAR(20)
																,Home VARCHAR(2000)
																,Away VARCHAR(2000)
												) AS tbl
			EXEC sp_xml_removedocument @handle
		END

        IF (@sportType = 5) AND Exists (SELECT 1 FROM @tmpResourcesWeb WHERE ResourceID = '00')
		BEGIN
			SELECT  @TotalPointHomeValue = CAST(SUM(CAST(HomeValue AS INT)) AS VARCHAR(50)), 
					@TotalPointAwayValue = CAST(SUM(CAST(AwayValue AS INT)) AS VARCHAR(50))
			FROM 
				(
					SELECT	ResourceID, HomeValue, AwayValue
					FROM	DBPRO.bodb02.dbo.ResultDetail r WITH(ROWLOCK)
					WHERE	MatchID = @MatchID 
							AND ResourceID IN ('01','02','03','04','05')
							AND SettlementStatusID = 4
							AND ResultStatusID = 5
				) t
		END

        INSERT INTO #tmpSelectedRID(ResourceID, HomeValue, AwayValue, BetType, BetID, pfID, RoundID, OrdNo, isFinal, RoundName, GroupType, OddsType, RefResourceId)
		SELECT DISTINCT tbl.ResourceID, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointHomeValue, '') ELSE ISNULL(HomeValue,'') END, 
				CASE WHEN sp.BetType = 153 THEN ISNULL(@TotalPointAwayValue, '') ELSE ISNULL(AwayValue,'') END, 
				sp.BetType, sp.BetID, sp.pfID, sp.RoundID, sp.OrdNo, 
				sd.isFinal, 
				sd.RoundName, 
				sp.GroupType, sp.OddsType,
				sp.RefResourceId
		FROM @tmpResourcesWeb tbl
			INNER LOOP JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.ResourceID = tbl.ResourceID
			OUTER APPLY (
				SELECT	sd.RoundName, sd.isFinal
				FROM	dbo.f_Set_MajorRound(sp.SportType) sd
				WHERE	sd.ResourceID = ISNULL(sp.RefResourceId,sp.ResourceID)
			)sd
		WHERE	sp.SportType = @SportType

        select *
            , (SELECT COUNT(1) FROM bettrans AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype and b.SiteDBGroupID = 0) AS TotalTicket_Central
            , (SELECT COUNT(1) FROM DBSIG01.[bodb02].[dbo].bettrans AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype) AS TotalTicket_SiteDB1
            , (SELECT COUNT(1) FROM DBSIG02.[bodb02].[dbo].bettrans AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype) AS TotalTicket_SiteDB2
            , (SELECT COUNT(1) FROM bettransm AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype and b.SiteDBGroupID = 0) AS TotalParlayTicket_Central
            , (SELECT COUNT(1) FROM DBSIG01.[bodb02].[dbo].bettransm AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype) AS TotalParlayTicket_SiteDB1
            , (SELECT COUNT(1) FROM DBSIG02.[bodb02].[dbo].bettransm AS b  With(nolock) where b.matchid = @MatchID and b.bettype = ReS.bettype) AS TotalParlayTicket_SiteDB2
        from #tmpSelectedRID AS ReS;

    ENd


    IF EXISTS (SELECT 1 FROM #MatchLifeCycle)
    BEGIN
        SELECT  ServerName
            ,   TableData
            ,   PARSENAME(REPLACE(ActionName,'->','.'),2) AS ActionName
            ,   PARSENAME(REPLACE(ActionName,'->','.'),1) SPName  
            ,   Remark
            ,   UserID  
            ,   DATEADD(HOUR, 11, Created) AS 'UTC(+7)'
        FROM #MatchLifeCycle
        ORDER BY Created ASC;
    END
END


go



/*********************Clear Log Datas******************************/
DECLARE @MatchID  INT = 70085092

DELETE
FROM DBLOG.bodb_CustomerLog.dbo.UserLog_Settle
WHERE MatchId = @MatchID;

DELETE
FROM DBTXN.bodb_CustomerLog.dbo.UserLog_Settle
WHERE MatchId = @MatchID

DELETE
FROM Single_Calculate_Queue
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG01.[bodb02].[dbo].Single_Calculate_Queue
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG02.[bodb02].[dbo].Single_Calculate_Queue
WHERE MatchId = @MatchID;

DELETE
FROM Parlay_Calculate_Queue 
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG01.[bodb02].[dbo].Parlay_Calculate_Queue 
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG02.[bodb02].[dbo].Parlay_Calculate_Queue 
WHERE MatchId = @MatchID;

DELETE
FROM BalanceNegative
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG01.[bodb02].[dbo].BalanceNegative
WHERE MatchId = @MatchID;

DELETE
FROM DBSIG02.[bodb02].[dbo].BalanceNegative
WHERE MatchId = @MatchID;

DELETE
FROM DBTP.bodb02.dbo.Match_Tracking 
WHERE matchId = @MatchID;

DELETE 
FROM dbo.ParlaySettlement_trace 
WHERE MatchId =@MatchID;

DELETE 
FROM  DBSIG01.[bodb02].[dbo].ParlaySettlement_trace 
WHERE MatchId =@MatchID;

DELETE 
FROM  DBSIG02.[bodb02].[dbo].ParlaySettlement_trace 
WHERE MatchId =@MatchID;

DELETE 
FROM dbo.TempVariableNumberHistory 
WHERE KeyValue =@MatchID;

DELETE 
FROM DBSIG01.[bodb02].dbo.TempVariableNumberHistory 
WHERE KeyValue =@MatchID;


DELETE 
FROM DBSIG02.[bodb02].dbo.TempVariableNumberHistory 
WHERE KeyValue =@MatchID;


DELETE 
FROM dbo.[ParlayLockingHistory] 
WHERE MatchId =@MatchID;

DELETE 
FROM DBSIG01.[bodb02].dbo.[ParlayLockingHistory] 
WHERE MatchId =@MatchID;



DECLARE @sql   NVARCHAR(4000)


SET @sql = CONCAT('DELETE OPENQUERY (DBSIG01,''SELECT 1 FROM  [bodb02].dbo.SiteDB_SettlementService_CalculationLog  WHERE MatchId = ', @MatchID,''' )')
EXEC sp_executesql @sql
 
go

