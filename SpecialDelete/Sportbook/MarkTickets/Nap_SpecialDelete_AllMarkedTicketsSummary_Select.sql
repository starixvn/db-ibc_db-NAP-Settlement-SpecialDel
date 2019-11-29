/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Select]
AS
/*
    Created by: Alan
	Date: 20190325
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20191129@Max: Count Parlay_Wrong Score_Score Info Unmark [Redmine: #124516]
	Explanation's Param:
*/
BEGIN
     SET NOCOUNT ON;
     CREATE TABLE #Tickets
              (MatchId     INT,
               UserId      INT,
               Username    NVARCHAR(100),
               CreatedDate DATETIME,
               Total       INT
              );
     INSERT INTO #Tickets
            (MatchId,
             UserId,
             Username,
             CreatedDate,
             Total
            )
    SELECT m.MatchId,
           UserId,
           c.Username,
           CreatedDate,
           COUNT(m.TransId)
    FROM dbo.MarkedTransaction m WITH (NOLOCK)
         INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON m.UserId = c.CustId
         INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = m.TransId
                                                    AND b.MatchId = m.MatchId
    WHERE b.statusID IN(0, 1) -- running, waiting
    GROUP BY m.MatchId,
             UserId,
             c.Username,
             CreatedDate;
             
     SELECT t.MatchId,
            t.UserId,
			t.Username,
            t.CreatedDate,
            t.Total,
            m.HomeId,
            m.AwayId,
            m.IsNeutral,
            m.SportType,
            m.kickofftime,
            ISNULL(rdHT.HomeValue + '-' + rdHT.AwayValue, '-') AS 'HTScore',
            ISNULL(rdFT.HomeValue + '-' + rdFT.AwayValue, '-') AS 'FTScore'
     FROM #Tickets t
		  INNER JOIN dbo.match m WITH (NOLOCK) ON m.MatchId = t.MatchId
		  LEFT JOIN ResultDetail rdHT WITH (NOLOCK) on m.matchid = rdHT.MatchId AND rdHT.ResourceId = '01'
		  LEFT JOIN ResultDetail rdFT WITH (NOLOCK) on m.matchid = rdFT.MatchId AND rdFT.ResourceId = '00'
     ORDER BY t.MatchId,
              t.CreatedDate,
              t.Username;
              
     DROP TABLE #Tickets;
     SET NOCOUNT OFF;
END
GO


