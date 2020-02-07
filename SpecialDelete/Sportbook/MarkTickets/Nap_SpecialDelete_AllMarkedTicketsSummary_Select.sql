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
		- 20200207@Max: Mark & Unmark tickets for Othersports [Redmine: #127035]
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
            ISNULL(CAST(rdHT.hthomescore AS CHAR(10)) + '-' + CAST(rdHT.htawayscore AS CHAR(10)), '-') AS 'HTScore',
            ISNULL(CAST(rdFT.finalhomescore AS CHAR(10)) + '-' + CAST(rdFT.finalawayscore AS CHAR(10)), '-') AS 'FTScore'
     FROM #Tickets t
		  INNER JOIN dbo.match m WITH (NOLOCK) ON m.MatchId = t.MatchId
		  OUTER APPLY (
						SELECT TOP 1 m.hthomescore, m.htawayscore
						FROM dbo.match_remark mr WITH (NOLOCK)
						WHERE IsHTCal = 1 
							AND mr.matchid = m.matchid			
					)rdHT
	      OUTER APPLY (
						SELECT TOP 1 m.finalhomescore, m.finalawayscore
						FROM dbo.match_remark mr WITH (NOLOCK)
						WHERE mr.calculate = 1 
							AND mr.matchid = m.matchid			
					)rdFT
     ORDER BY m.kickofftime
		, t.CreatedDate
              
     DROP TABLE #Tickets;
     SET NOCOUNT OFF;
END
GO


