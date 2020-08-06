/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelDetail_Resources] 
	@matchid 			   INT
	,@SportType            INT = 0
	,@SettleType		   VARCHAR(10) = 'MNL'
AS
/*
    Created by: 20180802@Vicky
    Task: get ResourceID info
    DB: DBTXN/BODB02 
    
    Revisions:            
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190925@Tiara: BMAIO - Badminton All In One [Redmine: #120324]
		- 20200212@Sol: Show all bet option for Early of Esport based on OddsES table - [#128069]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - [Redmine:#127698]
		- 20200318@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200601@Kathy: Wrong ticket count for eSports [Redmine:#132401]
		- 20200703@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20200721@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @BetTypeList VARCHAR(MAX) = ''
        	,@isShowAll BIT = 0
        	,@BestOfMap TINYINT = NULL
    DECLARE @tmpTicketStatus TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT, BetSettledCount INT, BetMarkedCount INT, OrdNo INT, IsSpecialBettype TINYINT) --Add new column IsSpecialBettype to check if there is at least 1 ticket bet on 704/705/706
    DECLARE @tmpTicketStatusParlay TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT, OrdNo INT)
    DECLARE @tblResult TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT, TicketStatus VARCHAR(20), OrdNo SMALLINT)
    DECLARE @tblMajorRound TABLE (ResourceID VARCHAR(20), Bettype SMALLINT, BetID BIGINT, OrdNo INT)

    ---------------------------------------------------------------------------------------------
    IF @SportType =0
        SELECT @SportType = SportType FROM Match WHERE matchID = @matchid

    --Use @BestOfMap for E-sport only
	SELECT @BestOfMap = BestOfMap
	FROM [dbo].[match_remark] WITH (NOLOCK) 
	WHERE matchid = @matchid    
    ---------------------------------------------------------------------------------------------

    --count ticket and group by Bettype and BetID
	IF (@SportType = 43 AND @SettleType = 'EAR')
	BEGIN
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, BetSettledCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT  sp.ResourceID AS ResourceID,
				SUM(CASE WHEN bt.transid IS NOT NULL THEN 1 ELSE 0 END) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 OR bt.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount,
				MAX(sp.OrdNo),
				0 AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM (
			SELECT 	DISTINCT o.ResourceID, o.bettype
			FROM 	DBPRO.bodb02.dbo.oddsES o WITH(NOLOCK)
			WHERE	o.matchID = @matchID
		)o
			INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = o.Bettype and sp.BetID = '8' + o.Resourceid 
			OUTER APPLY 
			(
				SELECT bt.transid, bt.statusID
				FROM bettrans bt WITH (NOLOCK) 
				WHERE bt.matchid = @matchid
					AND bt.bettype = o.bettype
					AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
					AND bt.statusID NOT IN (101, 102) --void/reject
			) bt
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	bt.transid = mt.TransId
		WHERE sp.sporttype = @SportType
			AND sp.Settletype = @SettleType
			AND SUBSTRING(sp.ResourceID, 5, 2) <= @BestOfMap
		GROUP BY sp.ResourceID
	END
	ELSE 
	BEGIN
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, BetSettledCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT  CASE 
					WHEN sp.ResourceID = '70400'
						OR sp.ResourceID = '605' THEN '00' 
					WHEN sp.ResourceID LIKE '6170[1-4]' THEN 'Q' + SUBSTRING(CAST(bt.betid AS VARCHAR),3,3)
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END AS ResourceID, --Convert ResourceID 70400 (using for bettype 704,705,706) to 00
				COUNT(1) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 OR bt.statusID = 103 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount,
				MAX(sp.OrdNo),
				MAX(CASE WHEN SP.ResourceID  = '70400' OR bt.bettype = 153 THEN 1 ELSE 0 END) AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM bettrans bt WITH (NOLOCK)
			INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	bt.transid = mt.TransId
		WHERE bt.matchid = @matchid
    		AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
			AND bt.statusID NOT IN (101, 102) --void/reject
			AND sp.sporttype = @SportType
			AND (sp.Settletype = @SettleType)	
		GROUP BY CASE 
					WHEN sp.ResourceID = '70400'
						OR sp.ResourceID = '605' THEN '00' 
					WHEN sp.ResourceID LIKE '6170[1-4]' THEN 'Q' + SUBSTRING(CAST(bt.betid AS VARCHAR),3,3)
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END 

		-- insert more result
		IF @SportType = 2
		BEGIN
			INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, BetSettledCount, BetMarkedCount, OrdNo)
			SELECT  CASE WHEN bt.bettype IN (603, 605, 617) THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END,					
					0 AS BetCount,
					0 As InRunning,
					0 AS betSettledCount,
					0 AS betMarkedCount,
					MAX(sp.OrdNo)
			FROM (	SELECT DISTINCT bt.bettype, bt.betid
					FROM	dbo.bettrans bt WITH (NOLOCK)
					WHERE	bt.matchid = @matchid
							AND (bt.bettype IN (603, 605, 617) OR bt.bettype BETWEEN 627 AND 644)
							AND bt.statusID NOT IN (101, 102) --void/reject
					UNION ALL
					SELECT DISTINCT btm.bettype, btm.betcheck
					FROM	dbo.bettransm btm WITH (NOLOCK)
					WHERE	btm.matchid = @matchid
							AND (btm.bettype IN (603, 605, 617) OR btm.bettype BETWEEN 627 AND 644)
							AND btm.statusID	NOT IN (101, 102) --void/reject
				)bt
				INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
			WHERE	(sp.Betid = 0 OR sp.BetID = bt.BetID)
				AND sp.sporttype = @SportType
				AND (sp.Settletype = @SettleType)	
			GROUP BY CASE WHEN bt.bettype IN (603, 605, 617) THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END
		END
	END
	
	IF @Settletype <> 'MNL'
	BEGIN
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InRunning, OrdNo)
	    SELECT sp.ResourceID      
	            ,COUNT(1) AS BetCount
	            ,SUM(CASE WHEN bm.StatusID = 0 THEN 1 ELSE 0 END)
	            ,MAX(sp.OrdNo)
	    FROM    dbo.Bettransm bm WITH (NOLOCK)
	        INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bm.Bettype
	    WHERE   matchID = @MatchID
	    		AND bm.statusId NOT IN (101, 102)
	    		AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
				AND sp.sporttype = @sporttype
				AND sp.Settletype = @Settletype
	    GROUP BY sp.ResourceID
	END
	
	---INSERT for Major score
	INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, OrdNo)
	SELECT mr.ResourceID, 0, 0, mr.OrdNo
	FROM dbo.f_Set_MajorRound (@Sporttype) mr
		LEFT JOIN @tmpTicketStatus bt ON bt.ResourceID = mr.ResourceID
	WHERE bt.ResourceID IS NULL 	
	
    ---return
    IF @Sporttype = 43
    BEGIN
	
		IF @BestOfMap IS NOT NULL
		BEGIN
			DELETE t
			FROM @tmpTicketStatus t
			INNER JOIN dbo.f_Set_MajorRound (@Sporttype) mr ON mr.ResourceID = t.ResourceID
			WHERE mr.OrdNo > @BestOfMap AND mr.ResourceID <> '00'
		END

	    SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
	           ,CASE 
					WHEN ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0 THEN 'No Ticket'
					WHEN bt.InRunning > 0 THEN 'Running'
					WHEN bt.betMarkedCount > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus 
	  	FROM @tmpTicketStatus bt
	  			FULL JOIN @tmpTicketStatusParlay p ON bt.resourceId = p.ResourceID
		  		LEFT JOIN DBPRO.bodb02.dbo.ResultDetailES rs WITH (NOLOCK)  
					ON COALESCE(bt.ResourceID,p.ResourceID) = rs.ResourceID
		  				AND rs.matchid = @matchid
	  	ORDER BY COALESCE(bt.OrdNo,p.OrdNo)
	END
	
	---Badminton AIO - get data from dbo.ResultDetailOS
	ELSE IF @SportType = 9
	BEGIN
		SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
	           ,CASE 
					WHEN ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0 THEN 'No Ticket'
					WHEN bt.InRunning > 0 THEN 'Running'
					WHEN bt.betMarkedCount > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus
	           ,bt.IsSpecialBettype --flag column for Badminton AIO only
	  	FROM @tmpTicketStatus bt
	  			FULL JOIN @tmpTicketStatusParlay p ON	bt.resourceId = p.ResourceID
		  		OUTER  APPLY(
		  			SELECT HomeValue, 
		    			AwayValue, 
		    			ResultStatusID, 
		    			SettlementStatusID
		  			FROM DBPRO.bodb02.dbo.ResultDetailOS rd WITH (NOLOCK) 
		  			WHERE COALESCE(bt.ResourceID,p.ResourceID) = rd.ResourceID
		  				AND rd.matchid = @matchid
		  		) AS rs
	  	ORDER BY COALESCE(bt.OrdNo,p.OrdNo)
	END
	
	ELSE
	BEGIN
		SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
	           ,CASE 
					WHEN ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0 THEN 'No Ticket'
					WHEN bt.InRunning > 0 THEN 'Running'
					WHEN bt.betMarkedCount > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus 
				,bt.IsSpecialBettype --flag column for tennis
	  	FROM @tmpTicketStatus bt
	  			 FULL JOIN @tmpTicketStatusParlay p ON	bt.resourceId = p.ResourceID
				 OUTER  APPLY(
		  			SELECT HomeValue, 
		    			AwayValue, 
		    			ResultStatusID, 
		    			SettlementStatusID
		  			FROM DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
		  			WHERE COALESCE(bt.ResourceID,p.ResourceID) = rd.ResourceID
		  				AND rd.matchid = @matchid
		  		) AS rs
	  	ORDER BY COALESCE(bt.OrdNo, p.OrdNo) 
	END

	-- number of ticket
	SELECT	0 AS GroupId 
			,SUM(InRunning) AS betRunningCount
			,SUM(betSettledCount) AS betSettledCount
			,SUM(betMarkedCount) AS betMarkedCount
	FROM	@tmpTicketStatus	

END
GO
