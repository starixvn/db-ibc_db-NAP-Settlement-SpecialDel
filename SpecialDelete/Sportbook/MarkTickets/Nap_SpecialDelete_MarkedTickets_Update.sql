
/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/

ALTER PROCEDURE dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds VARCHAR(MAX)  = NULL,
                                                           @UserId   INT           = 0,
                                                           @Username NVARCHAR(100) = '',
                                                           @IP       VARCHAR(15)   = NULL,
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
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion	
*/

     SET NOCOUNT ON;
     CREATE TABLE #TransIds
                  (TransId BIGINT
                   PRIMARY KEY
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
     CREATE TABLE #Match(MatchId INT);
     INSERT INTO #Match
            SELECT DISTINCT
                   m.MatchId
            FROM #TransIds t
                 INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId;
	
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
                 INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.transid;
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
				    ) AS b
    END;
-- Delete Transaction
	WHILE (0=0)
	BEGIN
		DELETE TOP (2000) m 
		FROM dbo.MarkedTransaction m WITH (ROWLOCK, UPDLOCK)
        INNER JOIN #TransIds t ON t.TransId = m.TransId;
		IF @@ROWCOUNT = 0 BREAK	  
	END 

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
				) mt ON mt.MatchId = t.MatchId
            WHERE mt.MatchId IS NULL;
     DELETE b
     FROM #Match b
          INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON b.MatchId = m.MatchId;
     SELECT b.MatchId,
            m.HomeId,
            m.AwayId,
            m.SportType,
            m.IsNeutral
     FROM #Match b
          LEFT JOIN match m WITH (NOLOCK) ON b.MatchId = m.MatchId;
     DROP TABLE #TransIds;
     DROP TABLE #Match;
     SET NOCOUNT OFF;
GO
