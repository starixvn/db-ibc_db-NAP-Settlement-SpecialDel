/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds VARCHAR(MAX)  = NULL,
                                                           @UserId   INT           = 0,
                                                           @Username NVARCHAR(100) = '',
                                                           @IP       VARCHAR(15)   = NULL,
														   @RequestId INT		   = NULL,
														   @LogActionId	  INT			= 90501,
                                                           @ErrMsg   NVARCHAR(200) = '' OUTPUT,
                                                           @ErrCode  INT           = 0 OUTPUT
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Explanation's Param:
		
	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	[108826]
		- 20190606@Raymond.Le: Mark Tickets Enhancement - Phase 4, change write log for mark/unmark [114596]
		- 20200216@Max: Abnormal Void Bets Automation - Log [Redmine: #128359]
		- 20200304@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200415@Raymond: Mark/Unmark Parlay Tickets and remaing sports [131670]
*/
BEGIN
     SET NOCOUNT ON;

	DECLARE @xmlLog VARCHAR(MAX)
			,@LogData VARCHAR(MAX) = '';

    CREATE TABLE #TransIds -- single + parlay tickets
                  (TransId BIGINT
                   PRIMARY KEY
                  );

	CREATE TABLE #ParlayTransIds (TransId BIGINT PRIMARY KEY);

	CREATE TABLE #MarkedTransactionDeleted (
		TransId BIGINT
		,MatchId INT
		);

     INSERT INTO #TransIds(TransId)
            SELECT DISTINCT
                   val
            FROM dbo.f_SplitString(@TransIds, ',')
            WHERE val <> '' OPTION(MAXRECURSION 0);

     CREATE TABLE #Tickets
                  (TransId   BIGINT,
                   MatchId   INT,
                   CustId    INT,
                   BetType   SMALLINT,
                   Betdaqid  BIGINT,
                   ExtraInfo VARCHAR(1000),
                   RefCode   BIGINT,
				   refno	 BIGINT,
				   IsParlay  BIT DEFAULT(0),
				   SubTransId BIGINT
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
     CREATE TABLE #Match(MatchId INT);
	
	-- Get tickets insert into transaction
	INSERT INTO #Tickets (
		TransId
		,MatchId
		,BetType
		,CustId
		,Betdaqid
		,ExtraInfo
		,RefCode
		,refno
		,IsParlay
		,SubTransId
		)
	SELECT t.TransId
		,b.MatchId
		,b.BetType
		,b.custid
		,b.betdaqid
		,b.ExtraInfo
		,b.RefCode
		,b.refno
		,0
		,NULL
	FROM #transIds t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid
	WHERE b.matchid <> 29

	-- get only parlay tickets from @input transid
	INSERT INTO #ParlayTransIds (
		TransId
	)
	SELECT tmp.TransId
	FROM #transIds AS tmp
	WHERE NOT EXISTS (
		SELECT TOP 1 1
		FROM #Tickets AS t
		WHERE t.TransId = tmp.TransId
	)

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
                     INSERT INTO #TransIds(TransId)
                            SELECT b.transid
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
             INSERT INTO #TransIds(TransId)
                    SELECT b.transid
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
						AND NOT EXISTS (SELECT TOP 1 1 FROM #TransIds r WHERE r.TransId = b.transid)
				    ) AS b
    END;

	-- get parlay tickets
	IF EXISTS (SELECT TOP 1 1
				FROM #ParlayTransIds)
	BEGIN
		INSERT INTO #Tickets (
			TransId
			,MatchId
			,BetType
			,CustId
			,Betdaqid
			,ExtraInfo
			,RefCode
			,refno
			,IsParlay
			,SubTransId
			)
		SELECT b.transid
			,bm.matchid
			,bm.bettype
			,bm.custid
			,NULL
			,NULL
			,NULL
			,bm.refno
			,1
			,bm.transid
		FROM #ParlayTransIds t
			INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON bm.transid = t.TransId
			INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.refno = bm.refno
				AND b.matchid = 29
	END

	-- Delete Transaction
	WHILE (0=0)
	BEGIN
		DELETE TOP (2000) m 
		OUTPUT DELETED.TransId
			,DELETED.MatchId
		INTO #MarkedTransactionDeleted (TransId, MatchId)
		FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
        INNER JOIN #Tickets t ON t.TransId = m.TransId AND t.MatchId = m.MatchId;

		IF @@ROWCOUNT = 0 BREAK	  
	END 

    INSERT INTO #Match
    SELECT DISTINCT
            t.MatchId
    FROM #Tickets t;

	-- Write Log
	SET @xmlLog = CAST((
				SELECT @LogActionId AS '@LogActionId' -- 90501: Action Unmark, 90510: Unmark by autovoid System
					,@UserId AS '@UserId'
					,@IP AS '@IP'
					,@RequestId AS '@RequestId'
					,m.matchid AS '@MatchId'
					,STUFF((
							SELECT ',' + CAST(d.TransId AS NVARCHAR(100))
							FROM #MarkedTransactionDeleted AS d
							WHERE d.MatchId = m.MatchId
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
                   'UNMARK',
                   'has all tickets unmarked by '+@Username,
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
					WHERE b.matchid <> 29

					UNION
					SELECT bm.matchid
					FROM dbo.MarkedTransaction AS m WITH (NOLOCK)
						INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON b.transid = m.TransId
						INNER JOIN dbo.bettransm AS bm WITH (NOLOCK) ON b.matchid = 29
						AND bm.refno = b.refno
					WHERE m.MatchId = bm.matchid
				) mt ON mt.MatchId = t.MatchId
            WHERE mt.MatchId IS NULL;

     DELETE b
     FROM #Match b
          INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON b.MatchId = m.MatchId;

	-- Return matches don't have marked ticket ??
     SELECT b.MatchId,
            m.HomeId,
            m.AwayId,
            m.SportType,
            m.IsNeutral
     FROM #Match b
          LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;

     DROP TABLE #TransIds;
     DROP TABLE #Match;
     DROP TABLE #MarkedTransactionDeleted;
	 DROP TABLE #ParlayTransIds

     SET NOCOUNT OFF;
END