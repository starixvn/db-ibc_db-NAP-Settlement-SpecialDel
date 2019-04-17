
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
     CREATE TABLE #Match(MatchId INT);
     INSERT INTO #Match
            SELECT DISTINCT
                   m.MatchId
            FROM #TransIds t
                 INNER JOIN dbo.MarkedTransaction m WITH (NOLOCK) ON m.TransId = t.TransId;
	
	-- Delete Transaction
     DELETE m
     FROM dbo.MarkedTransaction m
     WHERE m.TransId IN
(
    SELECT TransId
    FROM #TransIds
);

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
