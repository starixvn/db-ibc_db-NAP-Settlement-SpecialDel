/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds        VARCHAR(MAX)  = NULL,
                                                             @UserId          INT           = 0,
                                                             @Username        NVARCHAR(100) = '',
                                                             @IP              VARCHAR(15)   = NULL,
                                                             @MarkType		  TINYINT		= 0,
															 @RequestId		  INT			= NULL,
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
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200216@Max: Abnormal Void Bets Automation - Log [Redmine: #128359]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		
*/
BEGIN
     SET NOCOUNT ON;

	 DECLARE @xmlLog VARCHAR(MAX)
			,@LogData VARCHAR(MAX) = '';

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
     CREATE TABLE #Tickets
                  (TransId   BIGINT,
                   MatchId   INT,
                   CustId    INT,
                   BetType   SMALLINT,
                   Betdaqid  BIGINT,
                   ExtraInfo VARCHAR(1000),
                   RefCode   BIGINT,
				   refno	 BIGINT
                  );
     CREATE TABLE #Cashout911Tickets
                  (TransId BIGINT,
                   MatchId INT
                  );
     CREATE TABLE #tmpRefCodeSummary
                  (RefCode BIGINT,
                   custid  INT,
                   matchid INT,
                   bettype SMALLINT,
                   transid BIGINT
                  );
     CREATE INDEX IX_Data_RefCode ON #Tickets(RefCode);
     CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary(RefCode);
    
	-- Get tickets insert into transaction
     INSERT INTO #Tickets
            (TransId,
             MatchId,
             BetType,
             CustId,
             Betdaqid,
             ExtraInfo,
             RefCode,
			 refno
            )
            SELECT t.TransId,
                   b.MatchId,
                   b.BetType,
                   b.custid,
                   b.betdaqid,
                   b.ExtraInfo,
                   b.RefCode,
				   b.refno
            FROM #transIds t
                 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
                 LEFT JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId
            WHERE m.TransId IS NULL;
			
	-- delete cash-out member bet tickets
	DELETE t
	FROM #Tickets t
	WHERE EXISTS (SELECT TOP (1) 1
				  FROM bettrans sub911 (NOLOCK)
				  WHERE sub911.bettype = 911 AND sub911.transid = t.refno)
	-- Bonus
    IF EXISTS
	   (
		  SELECT TOP (1) 1
		  FROM #Tickets
		  WHERE RefCode IS NOT NULL
	   )
    BEGIN
             -- Insert more bonus or cash ticket in case only one ticket appears in #Tickets	
             INSERT INTO #tmpRefCodeSummary
                    (RefCode,
                     custid,
                     matchid,
                     bettype,
                     transid
                    )
                    SELECT RefCode,
                           custid,
                           matchid,
                           bettype,
                           MAX(transid) AS transid
                    FROM #Tickets
                    WHERE RefCode IS NOT NULL
                    GROUP BY RefCode,
                             custid,
                             matchid,
                             bettype
                    HAVING COUNT(*) = 1;
             IF @@ROWCOUNT > 0
                 BEGIN
                     INSERT INTO #Tickets
                            (TransId,
                             MatchId,
                             BetType,
                             CustId,
                             Betdaqid,
                             ExtraInfo,
                             RefCode
                            )
                            SELECT b.transid,
                                   b.matchid,
                                   b.bettype,
                                   b.custid,
                                   b.betdaqid,
                                   b.ExtraInfo,
                                   b.RefCode
                            FROM #tmpRefCodeSummary t
                                 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.RefCode = t.RefCode
                                                                            AND b.transid <> t.transid
                                                                            AND b.matchid = t.matchid
                                                                            AND b.custid = t.custid
                                                                            AND b.bettype = t.bettype
                            WHERE b.statusID IN(0, 1); -- running, waiting
                 END;
    END;	

	-- get sub ticket of Cash-out (911) and cash-out member bet tickets
    IF(EXISTS
	   (
		  SELECT TOP (1) 1
		  FROM #Tickets
		  WHERE betdaqid = 0
			   AND CHARINDEX('p25', extrainfo) > 0
	   ))
    BEGIN
	-- get sub ticket of Cash-out (911)	
        INSERT INTO #Cashout911Tickets
        (TransId,
            MatchId
        )
        SELECT sub911.transid,
                sub911.matchid
        FROM #Tickets main
                INNER JOIN dbo.bettrans sub911 WITH (NOLOCK) ON main.transid = sub911.refno
                                                                AND sub911.matchid = main.MatchId
                                                                AND sub911.custid = main.custid
                                                                AND main.betdaqid = 0
                                                                AND CHARINDEX('p25', main.extrainfo) > 0
                                                                AND sub911.bettype = 911;			 

	-- get cash-out member bet tickets
	   INSERT INTO #Tickets
		  (TransId,
			 MatchId,
			 BetType,
			 CustId,
			 Betdaqid,
			 ExtraInfo
		  )
		  SELECT b.transid,
				b.matchid,
				b.bettype,
				b.custid,
				b.betdaqid,
				b.ExtraInfo
		  FROM #Cashout911Tickets sub911
				CROSS APPLY
			 (
				SELECT b.bettype
					   ,b.transid
					   ,b.matchid
					   ,b.BetID
					   ,b.refno
					   ,b.hdp1
					   ,b.hdp2
					   ,b.odds
					   ,b.oddsspread
					   ,b.OddsType
					   ,b.status
					   ,b.SecAcceptFlag
					   ,b.checktime
					   ,b.stake
					   ,b.transdate
					   ,b.betteam
					   ,b.betcheck
					   ,b.liveindicator
					   ,b.custid
					   ,b.livehomescore
					   ,b.liveawayscore
					   ,b.winlost
					   ,b.actual_stake
					   ,b.transdesc
					   ,b.betdaqid
					   ,b.username
					   ,b.recommend
					   ,b.ExtraInfo
					   ,b.CurrencyName
					   ,b.WalletType
					   ,b.RefCode
					   ,b.BonusID
					   ,b.currency
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.refno = sub911.transid
					 AND b.matchid = sub911.MatchId
					 AND b.bettype NOT IN(911, 912, 913)
			 ) AS b
    END;

	--check no data
    IF NOT EXISTS
    (
	   SELECT TOP (1) 1
	   FROM #Tickets
    )
    BEGIN
        SELECT @ErrCode = 99,
            @ErrMsg = 'No ticket found.';
        RETURN;
    END;
	
	-- Check Lock Match
    BEGIN
        DECLARE @avaiableProcess BIT, @isExistMatch BIT= 0, @IsExistFM BIT= 0;
        SELECT @isExistMatch = MAX(CASE
                                    WHEN BetType NOT BETWEEN 221 AND 227
                                    THEN 1
                                    ELSE 0
                                END),
            @IsExistFM = MAX(CASE
                                    WHEN BetType BETWEEN 221 AND 227
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
             CreatedDate,
             MarkType 
            )
    SELECT t.TransId,
            t.MatchId,
            t.BetType,
            t.CustId,
            @UserId,
            CURRENT_TIMESTAMP,
            @MarkType
    FROM #Tickets t; 
	-- Release Match
     EXEC dbo.NAP_Admin_CheckingProcess
          @isExistMatch = @isExistMatch,
          @IsExistFM = @IsExistFM,
          @IsReleased = 1;

     SELECT b.MatchId,
            m.HomeId,
            m.AwayId,
            m.SportType,
            m.IsNeutral
     FROM #Match b
          LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	-- invalid trans
     SELECT @InvalidTransIds = @InvalidTransIds + CASE
                                                    WHEN @InvalidTransIds <> ''
                                                    THEN ','
                                                    ELSE ''
                                                END + CAST(transid AS VARCHAR(100))
     FROM #transIds t
     WHERE NOT EXISTS
	   (
		  SELECT 1
		  FROM #Tickets b
		  WHERE b.transid = t.transid
	   );


	-- Write Log
	SET @xmlLog = CAST((
				SELECT 90500 AS '@LogActionId' -- 90500: Action Mark
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,@RequestId AS '@RequestId'
					,m.matchid AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(t.TransId AS NVARCHAR(100))
							FROM #Tickets AS t
							WHERE t.MatchId = m.MatchId
							FOR XML PATH('')
							), 1, 1, '')  AS '@LogData'
				FROM #Match AS m
				FOR XML PATH('r')
					,ROOT('root')
					,TYPE
				) AS VARCHAR(MAX));

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @xmlLog
		,@functionName = 'TicketVoiding'
		,@MessageType = 'MessageType_TicketVoiding_Log';

     DROP TABLE #Tickets;
     DROP TABLE #Cashout911Tickets;
     DROP TABLE #tmpRefCodeSummary;
     DROP TABLE #transIds;
     DROP TABLE #Match;
     DROP TABLE #tblMatchProcess;
     SET NOCOUNT OFF;
END