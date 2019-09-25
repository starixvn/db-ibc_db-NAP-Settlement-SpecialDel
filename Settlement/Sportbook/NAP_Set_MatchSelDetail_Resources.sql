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
		
*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @BetTypeList VARCHAR(MAX) = ''
        	,@isShowAll BIT = 0
        	,@BestOfMap TINYINT = NULL
    DECLARE @tmpTicketStatus TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT,  OrdNo INT)
    DECLARE @tmpTicketStatusParlay TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT,  OrdNo INT)
    DECLARE @tblResult TABLE(ResourceID VARCHAR(20), BetCount INT, InRunning INT, TicketStatus VARCHAR(20), OrdNo SMALLINT)
    DECLARE @tblMajorRound TABLE (ResourceID VARCHAR(20), Bettype SMALLINT, BetID BIGINT, OrdNo INT)

    ---------------------------------------------------------------------------------------------
    IF @SportType =0
        SELECT @SportType = SportType FROM Match WHERE matchID = @matchid
        
    ---------------------------------------------------------------------------------------------

    --count ticket and group by Bettype and BetID
    INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, OrdNo)
    SELECT  sp.ResourceID,
            COUNT(1) AS BetCount,
            SUM(CASE WHEN bt.StatusID = 0 THEN 1 ELSE 0 END) As InRunning,
            MAX(sp.OrdNo)
    FROM bettrans bt WITH (NOLOCK)
		INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
    WHERE bt.matchid = @matchid
    	AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
		AND bt.statusID NOT IN (101, 102) --void/reject
		AND sp.sporttype = @sporttype
		AND (sp.Settletype = 'MNL' OR sp.Settletype = @Settletype)	
    GROUP BY sp.ResourceID
    
	
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
	
    /*DELETE p
    FROM @tmpTicketStatusParlay p
    	INNER JOIN dbo.f_Set_MajorRound(@sporttype) mr ON mr.ResourceID = p.ResourceID
    WHERE mr.isFinal <> 1
    */
	
	---INSERT for Major score
	INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InRunning, OrdNo)
	SELECT mr.ResourceID, 0, 0, mr.OrdNo
	FROM dbo.f_Set_MajorRound (@Sporttype) mr
		LEFT JOIN @tmpTicketStatus bt ON bt.ResourceID = mr.ResourceID
	WHERE bt.ResourceID IS NULL 	
	
	--Use @BestOfMap for E-sport only
	IF @Sporttype = 43	
	BEGIN
		SELECT @BestOfMap = BestOfMap
		FROM [dbo].[match_remark] WITH (NOLOCK) 
		WHERE matchid = @matchid
	
		IF @BestOfMap IS NOT NULL
			BEGIN
				DELETE t
				FROM @tmpTicketStatus t
				INNER JOIN dbo.f_Set_MajorRound (@Sporttype) mr ON mr.ResourceID = t.ResourceID
				WHERE mr.OrdNo > @BestOfMap AND mr.ResourceID <> '00'
			END
	END		
	
    ---return
    IF @Sporttype = 43
    BEGIN
	    SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
	           ,CASE 
					WHEN ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0 THEN 'No Ticket'
					WHEN bt.InRunning > 0 THEN 'Running'
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus 
	  	FROM @tmpTicketStatus bt
	  			FULL JOIN @tmpTicketStatusParlay p ON	bt.resourceId = p.ResourceID
		  		OUTER  APPLY(
		  			SELECT HomeValue, 
		    			AwayValue, 
		    			ResultStatusID, 
		    			SettlementStatusID
		  			FROM DBPRO.bodb02.dbo.ResultDetailES rd WITH (NOLOCK) 
		  			WHERE COALESCE(bt.ResourceID,p.ResourceID) = rd.ResourceID
		  				AND rd.matchid = @matchid
		  		) AS rs
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
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus 
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
					WHEN ISNULL(bt.BetCount, 0) = 0 AND p.InRunning > 0 THEN 'Parlay Running'
	                ELSE 'Calculated' END AS TicketStatus 
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
END
GO
