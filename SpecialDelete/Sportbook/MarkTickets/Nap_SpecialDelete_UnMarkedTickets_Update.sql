
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds        VARCHAR(MAX)  = NULL,
                                                             @UserId          INT           = 0,
                                                             @Username        NVARCHAR(100) = '',
                                                             @IP              VARCHAR(15)   = NULL,
                                                             @InvalidTransIds VARCHAR(MAX)  = '' OUTPUT,
                                                             @ErrMsg          NVARCHAR(200) = '' OUTPUT,
                                                             @ErrCode         INT           = 0 OUTPUT
AS


/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	
*/

     SET NOCOUNT ON;
     CREATE TABLE #transIds
                  (TransId BIGINT
                   PRIMARY KEY
                  );
     INSERT INTO #transIds(TransId)
            SELECT DISTINCT
                   val
            FROM dbo.f_SplitString(@TransIds, ',')
            WHERE val <> '' OPTION(MAXRECURSION 0);
     DECLARE @tblInvalidTrans TABLE(transid BIGINT);
     CREATE TABLE #Match(matchid INT);
     CREATE TABLE #tblMatchProcess
                  (matchid INT,
                   KeyID   TINYINT
                  );
     CREATE TABLE #tblCashOutProcess
                  (transid     BIGINT,
                   refno       BIGINT,
                   IsAvailable BIT DEFAULT 0
                  );
     CREATE TABLE #Tickets
                  (TransId   BIGINT,
                   MatchId   INT,
                   CustId    INT,
                   BetType   SMALLINT,
                   Betdaqid  BIGINT,
                   ExtraInfo VARCHAR(1000)
                  );

	-- Get tickets insert into transaction
     INSERT INTO #Tickets
            (TransId,
             MatchId,
             BetType,
             CustId,
             Betdaqid,
             ExtraInfo
            )
            SELECT t.TransId,
                   b.MatchId,
                   b.BetType,
                   b.custid,
                   b.betdaqid,
                   b.ExtraInfo
            FROM #transIds t
                 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
                 LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId
            WHERE m.TransId IS NULL;

	-- checking cash-out process
     INSERT INTO #tblCashOutProcess(transid)
            SELECT transid
            FROM #Tickets
            WHERE betdaqid = 0
                  AND CHARINDEX('p25', extrainfo) > 0;
     EXEC dbo.NAP_Admin_CheckingCashOutProcess
          @Mode = 'Original',
          @Action = 'Void',
          @IsReleased = 0;
     DELETE t
     FROM #Tickets t
          INNER JOIN #tblCashOutProcess rp ON t.TransId = rp.transid
                                              AND rp.IsAvailable = 0;	

--check no data
     IF NOT EXISTS
(
    SELECT TOP 1 1
    FROM #Tickets
)
         BEGIN
             SELECT @ErrCode = 99,
                    @ErrMsg = 'No ticket found.';		
		-------> releasing cash-out process
             EXEC dbo.NAP_Admin_CheckingCashOutProcess
                  @Mode = 'Original',
                  @Action = 'Void',
                  @IsReleased = 1;
             RETURN;
         END;
	
	-- Check Lock Match
         BEGIN
             DECLARE @avaiableProcess BIT, @isExistMatch BIT= 0, @IsExistFM BIT= 0, @isExistCashOut BIT= 0;
             SELECT @isExistMatch = MAX(CASE
                                            WHEN BetType NOT BETWEEN 221 AND 227
                                            THEN 1
                                            ELSE 0
                                        END),
                    @IsExistFM = MAX(CASE
                                         WHEN BetType BETWEEN 221 AND 227
                                         THEN 1
                                         ELSE 0
                                     END),
                    @isExistCashOut = MAX(CASE
                                              WHEN betdaqid = 0
                                                   AND CHARINDEX('p25', extrainfo) > 0
                                              THEN 1
                                              ELSE 0
                                          END)
             FROM #Tickets;
             INSERT INTO #tblMatchProcess
                    (MatchId,
                     KeyID
                    )
                    SELECT DISTINCT
                           MatchId,
                           CASE
                               WHEN BetType NOT BETWEEN 221 AND 227
                               THEN 1 --SB
                               WHEN BetType BETWEEN 221 AND 227
                               THEN 6 -- Fast Market
                               ELSE 0
                           END AS KeyID
                    FROM #Tickets;
             EXEC dbo.NAP_Admin_CheckingProcess
                  @isExistMatch = @isExistMatch,
                  @IsExistFM = @IsExistFM,
                  @avaiableProcess = @avaiableProcess OUTPUT,
                  @ErrCode = @ErrCode OUTPUT,
                  @ErrMsg = @ErrMsg OUTPUT;
             IF(@ErrCode <> 0
                OR @avaiableProcess = 0)
                 BEGIN		
			-- releasing cash-out process
                     EXEC dbo.NAP_Admin_CheckingCashOutProcess
                          @Mode = 'Original',
                          @Action = 'Void',
                          @IsReleased = 1;
                     RETURN;
                 END;
         END;
     INSERT INTO #Match
            SELECT DISTINCT
                   t.MatchId
            FROM #Tickets t;
	  	  
     -- Insert Settled_Message
     INSERT INTO [dbo].[Settled_Message]
            ([AdminId],
             [MatchId],
             [IP],
             [Starttime],
             [Action],
             [Message],
             [IsRead],
             [Warning],
             [IsSent]
            )
            SELECT 111,
                   t.matchid,
                   @IP,
                   GETDATE(),
                   'MARK',
                   'has some tickets marked by '+@Username,
                   0,
                   NULL,
                   0
            FROM #Match t
                 LEFT JOIN
(
    SELECT m.matchid
    FROM dbo.MarkedTransaction m WITH (NOLOCK)
         INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = m.TransId
                                                    AND b.statusID IN(0, 1)
) mt ON mt.MatchId = t.MatchId
            WHERE mt.MatchId IS NULL;
    
	-- Insert Transaction
     INSERT INTO dbo.MarkedTransaction
            (TransId,
             MatchId,
             BetType,
             CustId,
             UserId,
             CreatedDate
            )
            SELECT t.TransId,
                   t.MatchId,
                   t.BetType,
                   t.CustId,
                   @UserId,
                   CURRENT_TIMESTAMP
            FROM #Tickets t; 

	-- Release Match
     EXEC dbo.NAP_Admin_CheckingProcess
          @isExistMatch = @isExistMatch,
          @IsExistFM = @IsExistFM,
          @IsReleased = 1;
	-- releasing cash-out process
     EXEC dbo.NAP_Admin_CheckingCashOutProcess
          @Mode = 'Original',
          @Action = 'Void',
          @IsReleased = 1;
     SELECT b.MatchId,
            m.HomeId,
            m.AwayId,
            m.SportType,
            m.IsNeutral
     FROM #Match b
          LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	-- invalid trans
     SELECT @InvalidTransIds = @InvalidTransIds+CASE
                                                    WHEN @InvalidTransIds <> ''
                                                    THEN ','
                                                    ELSE ''
                                                END+CAST(transid AS VARCHAR(100))
     FROM #transIds t
     WHERE NOT EXISTS
(
    SELECT 1
    FROM #Tickets b
    WHERE b.transid = t.transid
);
     DROP TABLE #Tickets;
     DROP TABLE #transIds;
     DROP TABLE #Match;
     DROP TABLE #tblMatchProcess;
     DROP TABLE #tblCashOutProcess;
     SET NOCOUNT OFF;
GO
