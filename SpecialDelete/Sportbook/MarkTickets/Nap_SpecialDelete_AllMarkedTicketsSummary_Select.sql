/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_SpecialDelete_AllMarkedTicketsSummary_Select]
(
	@MarkedBy				INT	= 0
   ,@OnlineServerId	  		VARCHAR(10) = NULL
)
AS
/*
    Created by: 20190325@Alan
	Task: Mark Ticket for Settlement Exclusion
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

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
		- 20250828@July: [TVS] ScaleOut DBTrans [Phase 7] Manage Request page [Redmine: #236438]

	Explanation's Param:
*/
BEGIN
    SET NOCOUNT ON;
     
	DECLARE @SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @tmpOnlineServerId AS TABLE (ServerId SMALLINT)

	IF @OnlineServerId IS NULL SET @OnlineServerId = '0,1,2,3' -- Not get sitedb down for function

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmpOnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	 CREATE TABLE #Tickets(
			MatchId     INT,
            UserId      INT,
            CreatedDate DATETIME,
            Total       INT,
			ChildMatchId INT,
			SiteDBGroupID SMALLINT
     );
	CREATE TABLE #tmp_TransId (transid BIGINT, matchid INT, userid INT, createddate DATETIME, refno BIGINT,statusID TINYINT, SiteDBGroupID SMALLINT)

	 -- get all tickets 
	INSERT INTO #tmp_TransId (transid, matchid, userid, createddate, refno, statusID, SiteDBGroupID)
	SELECT mt.TransId
		,mt.MatchId
		,mt.UserId
		,mt.CreatedDate
		,CASE WHEN b.matchid = 29 THEN b.refno ELSE NULL END AS refno
		,b.statusID
		,b.SiteDBGroupID
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON mt.TransId = b.transid
	WHERE ((mt.UserId = @MarkedBy) OR @MarkedBy = 0)
		AND 1 = CASE WHEN mt.MatchId = 29 THEN 0 --not support main parlay
					 WHEN b.matchid <> 29 AND b.statusID NOT IN (0,1) THEN 0 
				ELSE 1 END
		AND 1 = CASE WHEN b.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = b.SiteDBGroupID) THEN 1
					 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = b.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
					 ELSE 0 END
	OPTION (MAXDOP 1)

	--Remove invalid tickets
	DELETE m
	FROM #tmp_TransId AS m
		LEFT JOIN dbo.bettransm AS bm WITH (NOLOCK, INDEX = IX_refno) ON m.refno = bm.refno AND m.matchid = bm.matchid
	WHERE m.refno IS NOT NULL AND (bm.matchid IS NULL OR bm.statusID NOT IN (0,1))
	
	INSERT INTO #Tickets
            (MatchId,
             UserId,
             CreatedDate,
             SiteDBGroupID,
			 Total
            )
	SELECT m.MatchId,
           m.UserId,
           m.CreatedDate,
           m.SiteDBGroupID,
		   COUNT(m.TransId)
    FROM #tmp_TransId m        
    GROUP BY m.MatchId,
             m.UserId,
             m.CreatedDate,
			 m.SiteDBGroupID
	OPTION (MAXDOP 1)
	
	UPDATE t
	SET  MatchId = m.ParentID
	    ,ChildMatchId = t.MatchId
	FROM #Tickets t
		  INNER JOIN dbo.match m WITH (NOLOCK) ON t.MatchId = m.matchid
	WHERE m.ChildMatchType IN (200) AND m.sporttype IN (50,8)

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
            mr.HTScore,
            mr.FTScore,
			t.SiteDBGroupID AS SiteDBGroupID
	 FROM #Tickets t
		  INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON t.UserId = c.CustId
		  INNER JOIN dbo.match m WITH (NOLOCK) ON m.MatchId = t.MatchId
		  OUTER APPLY (
						SELECT CASE WHEN mr.IsHTCal = 1 THEN CAST(m.hthomescore AS CHAR(10)) + '-' + CAST(m.htawayscore AS CHAR(10)) ELSE '-' END AS HTScore
							  ,CASE WHEN mr.calculate = 1 THEN CAST(m.finalhomescore AS CHAR(10)) + '-' + CAST(m.finalawayscore AS CHAR(10)) ELSE '-' END AS FTScore
						FROM dbo.match_remark mr WITH (NOLOCK)
						WHERE mr.matchid = m.matchid	
					)mr
     ORDER BY m.kickofftime ASC
		    , t.CreatedDate ASC
              
     DROP TABLE #Tickets;
	 DROP TABLE #tmp_TransId

     SET NOCOUNT OFF;
END
GO
