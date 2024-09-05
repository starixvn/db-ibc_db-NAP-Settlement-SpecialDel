/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Select]
(
	@MarkedBy	INT	= 0
)
AS
/*
    Created by: 20190325@Alan
	Task: Mark Ticket for Settlement Exclusion
	DB: DBTXN/BODB02

	Revisions:
		- 20190325@Alan: - Mark Ticket for Settlement Exclusion [108826]
		- 20191129@Max: Count Parlay_Wrong Score_Score Info Unmark [Redmine: #124516]
		- 20200207@Max: Mark & Unmark tickets for Othersports [Redmine: #127035]
		- 20201504@Charles: Implement parlay tickets for Mark ticket [131670]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		- 20200831@Zane: TVS - Enhance for Danger Accept. [Redmine: #140339]
		- 20220627@Max: [TVS] Tuning perforamance of Unmark All function [Redmine: #174560]
		- 20220829@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: [TVS] Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]

	Explanation's Param:
*/
BEGIN
     SET NOCOUNT ON;
     DECLARE @SiteDBGroupID		SMALLINT = 0
	 SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	 CREATE TABLE #Tickets(
			MatchId     INT,
            UserId      INT,
            CreatedDate DATETIME,
            Total       INT,
			ChildMatchId INT
     );
	CREATE TABLE #tmp_TransId (transid BIGINT, matchid INT, userid INT, createddate DATETIME, refno BIGINT,statusID TINYINT)

	 -- get all tickets 
	INSERT INTO #tmp_TransId (transid, matchid, userid, createddate, refno, statusID)
	SELECT mt.TransId
		,mt.MatchId
		,mt.UserId
		,mt.CreatedDate
		,CASE WHEN b.matchid = 29 THEN b.refno ELSE NULL end as refno
		,b.statusID
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON mt.TransId = b.transid AND b.SiteDBGroupID = @SiteDBGroupID
	WHERE ((mt.UserId = @MarkedBy) OR @MarkedBy = 0)
		AND 1 = CASE WHEN mt.MatchId = 29 THEN 0 --not support main parlay
					 WHEN b.matchid <> 29 AND b.statusID NOT IN (0,1) THEN 0 
				ELSE 1 END
	OPTION (MAXDOP 1)
     
    ;WITH CTE_FilterByTicketStatus
	AS(
		SELECT t.TransId
			,t.MatchId
			,t.UserId
			,t.CreatedDate
		FROM #tmp_TransId AS t
		WHERE t.refno IS NULL

		UNION ALL
			
		SELECT f.TransId
			,f.MatchId
			,f.UserId
			,f.CreatedDate
		FROM #tmp_TransId AS f
			INNER JOIN bettransm AS m WITH (NOLOCK, INDEX = IX_refno) ON f.MatchId = m.matchid AND f.refno = m.refno AND m.SiteDBGroupID = @SiteDBGroupID
		WHERE m.statusID IN (0, 1)													
	)
	INSERT INTO #Tickets
            (MatchId,
             UserId,
             CreatedDate,
             Total
            )
	SELECT m.MatchId,
           m.UserId,
           m.CreatedDate,
           COUNT(m.TransId)
    FROM CTE_FilterByTicketStatus m        
    GROUP BY m.MatchId,
             m.UserId,
             m.CreatedDate
	OPTION (MAXDOP 1)

	UPDATE t
	SET  MatchId = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.ParentID ELSE t.MatchId END
	    ,ChildMatchId = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN t.MatchId ELSE NULL END
	FROM #Tickets t
		  INNER JOIN dbo.match m WITH (NOLOCK) ON t.MatchId = m.matchid

     -- return final results   
     SELECT t.MatchId,
            t.ChildMatchId,
			t.UserId,
            c.Username,
            t.CreatedDate,
            t.Total,
            m.HomeId,
            m.AwayId,
            m.IsNeutral,
            m.SportType,
            m.kickofftime,
            ISNULL(CAST(rdHT.hthomescore AS CHAR(10)) + '-' + CAST(rdHT.htawayscore AS CHAR(10)), '-') AS 'HTScore',
            ISNULL(CAST(rdFT.finalhomescore AS CHAR(10)) + '-' + CAST(rdFT.finalawayscore AS CHAR(10)), '-') AS 'FTScore',
			@SiteDBGroupID AS SiteDBGroupID
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
		 INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON t.UserId = c.CustId
     ORDER BY m.kickofftime
		, t.CreatedDate
              
     DROP TABLE #Tickets;
	 DROP TABLE #tmp_TransId

     SET NOCOUNT OFF;
END
GO
