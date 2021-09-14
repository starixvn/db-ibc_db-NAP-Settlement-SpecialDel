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
		- 20200910@Louisa: Separate Ticket status: Calculated, Parlay Running and Refunded for MNL [Redmine:#141340]
		- 20201113@Louisa: Add Hold Result - [Redmine:#135097]
		- 20210121@Kathy:  Cricket AIO [Redmine:#148870]
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]
		- 20210524@Louisa: SOP for Badminton, Basketball [Redmine:#155361,#155360]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210514@Louisa: Use OPENQUERY to get remote data [Redmine:#154737]
		- 20210906@Louisa: Settle by profile for Volleyball, Squash, and Sepak Takraw [Redmine:#160478]

*/
BEGIN
	SET NOCOUNT ON
    
	DECLARE @BetTypeList	VARCHAR(MAX) = ''
        	,@isShowAll		BIT = 0
        	,@BestOfMap		TINYINT = NULL
			,@IsMergedParlay BIT = 0
			,@OpenQuery		NVARCHAR(MAX)
			,@ResultTable	TINYINT = 0
			,@betstatus		NVARCHAR(100)
			,@FinalHomeScore INT
			,@FinalAwayScore INT

    DECLARE @tmpTicketStatus TABLE	(
		ResourceID VARCHAR(20)
		, BetCount INT
		, InWaiting INT
		, InRunning INT
		, BetSettledCount INT
		, BetRefundedCount INT
		, BetMarkedCount INT
		, OrdNo INT
		, IsSpecialBettype TINYINT
	) --Add new column IsSpecialBettype to check if there is at least 1 ticket bet on 704/705/706

	DECLARE @tmpBetStatus TABLE 
	(
		 val VARCHAR(20)
		,ResourceID NVARCHAR(50)
		,HomeValue VARCHAR(20)
		,AwayValue VARCHAR(20)
		,ID INT IDENTITY
		,chk int 
	)

    DECLARE @tmpTicketStatusParlay TABLE(ResourceID VARCHAR(20), BetCount INT, InWaiting INT, InRunning INT, BetSettledCount INT, BetRefundedCount INT, BetMarkedCount INT, OrdNo INT, IsSpecialBettype BIT)

	DECLARE @tmbResultDetail TABLE 
	(
			ResourceID			VARCHAR(20)
			,HomeValue			VARCHAR(50)
			,AwayValue			VARCHAR(50)
			,ResultStatusId		TINYINT
			,SettlementStatusId	TINYINT
			,ResultSetting		TINYINT
			,TicketStatus		VARCHAR(20)
			,IsSpecialBettype	BIT
	)

    DECLARE @tblMajorRound TABLE (ResourceID VARCHAR(20), Bettype SMALLINT, BetID BIGINT, OrdNo INT)
	DECLARE @tblOddsES TABLE (ResourceID VARCHAR(20), bettype SMALLINT)

	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT)
    ---------------------------------------------------------------------------------------------

	IF @SportType = 0 OR @SportType IN ( 6, 30, 48 ) 
	SELECT @SportType = SportType 
		, @betstatus =  m.betstatus
		, @FinalHomeScore = m.finalhomescore
		, @FinalAwayScore = m.finalawayscore
	FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK) WHERE m.matchid = @matchid

    --Use @BestOfMap for E-sport only
	SELECT @BestOfMap = BestOfMap
	FROM [dbo].[match_remark] WITH (NOLOCK)
	WHERE matchid = @matchid    

	SELECT @ResultTable =  r.ResultTable
		  ,@IsMergedParlay = r.IsMergedParlay
	FROM   dbo.SettlementResultTableSetting r WITH(NOLOCK)
	WHERE r.Sporttype = @SportType
		/*@ResultTable:
				1: ResultDetail
				2: ResultDetailOS
				3: ResultDetailES
		*/
		
    ---------------------------------------------------------------------------------------------

    --count ticket and group by Bettype and BetID
	IF (@SportType = 43 AND @SettleType = 'EAR')
	BEGIN
		SET @OpenQuery = 'SELECT ResourceId, Bettype
						 FROM OPENQUERY(DBPRO, '' SELECT o.ResourceId, o.Bettype 
												 FROM bodb02.dbo.OddsES o WITH(NOLOCK)
												 WHERE o.Matchid = '+ CAST( @matchid AS VARCHAR) +'	 '')'
		INSERT INTO @tblOddsES (ResourceId, Bettype)
		EXECUTE	sys.sp_executesql @OpenQuery

		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT  sp.ResourceID AS ResourceID,
				SUM(CASE WHEN bt.transid IS NOT NULL THEN 1 ELSE 0 END) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting,
				SUM(CASE WHEN bt.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount,
				SUM(CASE WHEN bt.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount,
				MAX(sp.OrdNo),
				0 AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM (
			SELECT 	DISTINCT o.ResourceID, o.bettype
			FROM 	@tblOddsES o
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
	
	ELSE IF @SportType = 50
	BEGIN
		INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId )
		SELECT	@MatchId , @MatchId
		UNION ALL
		SELECT	m.MatchId , m.ParentID
		FROM	dbo.match m WITH(NOLOCK)
		WHERE	ISNULL(ParentID,0) =  @MatchId
				AND ISNULL(m.ChildMatchType, 0) = 200
				AND m.sporttype = 50
		
		; WITH cte_bettrans AS (
			SELECT  m.ParentId, m.MatchId, bt.StatusID , bt.Bettype,  bt.BetID
			FROM #tmpAllParentChildMatch m
				INNER JOIN dbo.Bettrans bt WITH(NOLOCK)	
					ON bt.MatchID = m.MatchID 
			WHERE bt.statusID NOT IN (101, 102)
		)
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT sp.ResourceID,
				COUNT(1) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting,
				SUM(CASE WHEN bt.StatusID = 0 THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount,
				0 AS betMarkedCount,
				MAX(sp.OrdNo) ,
				0 AS IsSpecialBettype
		FROM cte_bettrans bt
			CROSS APPLY (
				SELECT sp.OrdNo ,  sp.ResourceID, sp.sporttype, sp.Settletype
				FROM  SettlementSpecialBettypeProfile sp WITH (NOLOCK)	
				WHERE bt.Bettype = sp.Bettype
					AND (sp.Betid = 0 OR sp.BetID = bt.BetID)
			) sp
		WHERE sp.sporttype = @SportType
			AND sp.Settletype = @SettleType	
		GROUP BY bt.ParentId, sp.ResourceID
	END

	ELSE 
	BEGIN
		INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo, IsSpecialBettype)
		SELECT  CASE 
					WHEN sp.ResourceID = '70400' THEN '00'
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END AS ResourceID, --Convert ResourceID 70400 (using for bettype 704,705,706) to 00
				COUNT(1) AS BetCount,
				SUM(CASE WHEN bt.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting,
				SUM(CASE WHEN bt.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END) As InRunning,
				SUM(CASE WHEN bt.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount,
				SUM(CASE WHEN bt.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount,
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
					WHEN sp.ResourceID = '70400' THEN '00' 
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END 

		-- insert more result
		IF @SportType = 2
		BEGIN
			INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, BetMarkedCount, OrdNo)
			SELECT  CASE WHEN bt.bettype = 603 THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END,					
					0 AS BetCount,
					0 AS InWaiting,
					0 As InRunning,
					0 AS betSettledCount,
					0 AS betRefundedCount,
					0 AS betMarkedCount,
					MAX(sp.OrdNo)
			FROM (	SELECT DISTINCT bt.bettype, bt.betid
					FROM	dbo.bettrans bt WITH (NOLOCK)
					WHERE	bt.matchid = @matchid
							AND (bt.bettype = 603 OR bt.bettype BETWEEN 627 AND 644)
							AND bt.statusID NOT IN (101, 102) --void/reject
					UNION ALL
					SELECT DISTINCT btm.bettype, btm.betcheck
					FROM	dbo.bettransm btm WITH (NOLOCK)
					WHERE	btm.matchid = @matchid
							AND (btm.bettype = 603 OR btm.bettype BETWEEN 627 AND 644)
							AND btm.statusID	NOT IN (101, 102) --void/reject
				)bt
				INNER JOIN SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bt.Bettype
			WHERE	(sp.Betid = 0 OR sp.BetID = bt.BetID)
				AND sp.sporttype = @SportType
				AND (sp.Settletype = @SettleType)	
			GROUP BY CASE WHEN bt.bettype = 603 THEN sp.ResourceID ELSE CAST(bt.bettype AS VARCHAR(20)) END
		END
	END
	
	IF @SportType = 50
	BEGIN
		;WITH cte_bettransm AS (
			SELECT  m.ParentId, m.MatchId, bm.StatusID , bm.Bettype,  bm.Betcheck, bm.refno
			FROM #tmpAllParentChildMatch m
				INNER JOIN dbo.Bettransm bm WITH(NOLOCK) ON bm.MatchID = m.MatchID 
			WHERE bm.statusID NOT IN (101, 102)
		)
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, OrdNo, BetMarkedCount, IsSpecialBettype)
		SELECT sp.ResourceID     
			,COUNT(1) AS BetCount
			,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting
			,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END)
			,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount
			,SUM(CASE WHEN bm.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount
			,MAX(sp.OrdNo)
			,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
			,0 AS IsSpecialBettype
		FROM cte_bettransm bm
			CROSS APPLY (
							SELECT  sp.ResourceID, sp.OrdNo , sp.sporttype, sp.Settletype
							FROM dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) 
							WHERE sp.Bettype = bm.Bettype
							AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
							AND sp.sporttype = 50
							AND sp.Settletype = @Settletype
						) sp
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29		
					AND b.bettype = 29
					AND b.refno = bm.refno
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
					AND mt.matchid = bm.matchid
		WHERE	sp.sporttype = @SportType
				AND sp.Settletype = @SettleType
				AND bm.statusID NOT IN (101, 102)
		GROUP BY bm.ParentId, sp.ResourceID
	END
	ELSE
	BEGIN
		INSERT INTO @tmpTicketStatusParlay(ResourceID, BetCount, InWaiting, InRunning, BetSettledCount, BetRefundedCount, OrdNo, BetMarkedCount, IsSpecialBettype)
		SELECT CASE 
					WHEN sp.ResourceID = '70400' THEN '00'  
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END     
				,COUNT(1) AS BetCount
				,SUM(CASE WHEN bm.StatusID = 1 THEN 1 ELSE 0 END) As InWaiting
				,SUM(CASE WHEN bm.StatusID = 0 AND mt.TransId IS NULL THEN 1 ELSE 0 END)
				,SUM(CASE WHEN bm.statusID BETWEEN 111 AND 113 THEN 1 ELSE 0 END) AS betSettledCount
				,SUM(CASE WHEN bm.statusID = 103 THEN 1 ELSE 0 END) AS betRefundedCount
				,MAX(sp.OrdNo)
				,SUM(CASE WHEN bm.statusId BETWEEN 0 AND 1 AND mt.TransId IS NOT NULL THEN 1 ELSE 0 END) AS betMarkedCount
				,MAX(CASE WHEN sp.ResourceID  = '70400' OR bm.bettype = 153 THEN 1 ELSE 0 END) AS IsSpecialBettype -- 1 = there is at least 1 ticket bet on 704/705/706
		FROM    dbo.Bettransm bm WITH (NOLOCK)
			INNER JOIN dbo.SettlementSpecialBettypeProfile sp WITH (NOLOCK) ON sp.Bettype = bm.Bettype
			LEFT HASH JOIN dbo.bettrans b WITH(NOLOCK)
				ON	b.matchid = 29
					AND b.bettype = 29
					AND b.refno = bm.refno
			LEFT JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
				ON	b.transid = mt.TransId
					AND mt.matchid = @matchid
		WHERE   bm.matchID = @MatchID
	    		AND bm.statusId NOT IN (101, 102)
	    		AND (sp.Betid = 0 OR sp.BetID = bm.Betcheck)
				AND sp.sporttype = @sporttype
				AND sp.Settletype = @Settletype
		GROUP BY CASE 
						WHEN sp.ResourceID = '70400' THEN '00' 
					WHEN sp.RefResourceId IS NOT NULL THEN sp.RefResourceId
					ELSE sp.ResourceID 
				END
			
	END
	---INSERT for Major score
	INSERT INTO @tmpTicketStatus (ResourceID, BetCount, InWaiting, InRunning, OrdNo)
	SELECT mr.ResourceID, 0, 0, 0, mr.OrdNo
	FROM dbo.f_Set_MajorRound(@Sporttype) mr
		LEFT JOIN @tmpTicketStatus bt ON bt.ResourceID = mr.ResourceID
	WHERE bt.ResourceID IS NULL

    ---return
    IF @ResultTable = 3 --E-Sports only
    BEGIN
	
		IF @BestOfMap IS NOT NULL
		BEGIN
			DELETE t
			FROM @tmpTicketStatus t
			INNER JOIN dbo.f_Set_MajorRound(@Sporttype) mr ON mr.ResourceID = t.ResourceID
			WHERE mr.OrdNo > @BestOfMap AND mr.ResourceID <> '00'
		END

		INSERT INTO @tmbResultDetail 
		(
				ResourceID			
				,HomeValue			
				,AwayValue			
				,ResultStatusId		
				,SettlementStatusId	
				,ResultSetting		
				,TicketStatus	
		)
	    SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
				,ISNULL(rs.ResultSetting, 0) AS ResultSetting
	           ,CASE 
					WHEN (ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0) 
						OR (ISNULL(bt.InWaiting,0) + ISNULL(p.InWaiting,0) = ISNULL(bt.BetCount, 0) + ISNULL(p.BetCount, 0)) THEN 'No Ticket'
					WHEN ISNULL(bt.InRunning,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.InRunning,0) ELSE 0 END > 0 THEN 'Running'
					WHEN ISNULL(bt.betMarkedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetMarkedCount,0) ELSE 0 END  > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetSettledCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetSettledCount,0) ELSE 0 END > 0 THEN 'Calculated'
					WHEN ISNULL(bt.BetRefundedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetRefundedCount,0) ELSE 0 END > 0 THEN CASE WHEN @SettleType = 'EAR' THEN 'Calculated' ELSE 'Refunded' END
					END AS TicketStatus 
	  	FROM @tmpTicketStatus bt
	  			FULL JOIN @tmpTicketStatusParlay p ON bt.resourceId = p.ResourceID
		  		LEFT JOIN DBPRO.bodb02.dbo.ResultDetailES rs WITH (NOLOCK)  
					ON COALESCE(bt.ResourceID,p.ResourceID) = rs.ResourceID
		  				AND rs.matchid = @matchid
	  	ORDER BY COALESCE(bt.OrdNo,p.OrdNo)
	END
	
	ELSE IF @ResultTable = 2 ---dbo.ResultDetailOS
	BEGIN
		INSERT INTO @tmbResultDetail
		(
				ResourceID			
				,HomeValue			
				,AwayValue			
				,ResultStatusId		
				,SettlementStatusId	
				,ResultSetting		
				,TicketStatus		
				,IsSpecialBettype	
		)
		SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
				,rs.ResultSetting
	           ,CASE 
					WHEN (ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0) 
						OR (ISNULL(bt.InWaiting,0) + ISNULL(p.InWaiting,0) = ISNULL(bt.BetCount, 0) + ISNULL(p.BetCount, 0)) THEN 'No Ticket'
					WHEN ISNULL(bt.InRunning,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.InRunning,0) ELSE 0 END > 0 THEN 'Running'
					WHEN ISNULL(bt.betMarkedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetMarkedCount,0) ELSE 0 END  > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetSettledCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetSettledCount,0) ELSE 0 END > 0 THEN 'Calculated'
					WHEN ISNULL(bt.BetRefundedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetRefundedCount,0) ELSE 0 END > 0 THEN CASE WHEN @SettleType = 'EAR' THEN 'Calculated' ELSE 'Refunded' END
					END AS TicketStatus 
	           ,CASE WHEN ISNULL(bt.IsSpecialBettype,0) + ISNULL(p.IsSpecialBettype,0) > 0 THEN 1 ELSE 0 END AS IsSpecialBettype --flag column for Badminton AIO only
	  	FROM @tmpTicketStatus bt
	  			FULL JOIN @tmpTicketStatusParlay p ON	bt.resourceId = p.ResourceID
		  		OUTER  APPLY(
		  			SELECT HomeValue, 
		    			AwayValue, 
		    			ResultStatusID, 
		    			SettlementStatusID,
						ISNULL(rd.ResultSetting, 0) AS ResultSetting
		  			FROM DBPRO.bodb02.dbo.ResultDetailOS rd WITH (NOLOCK) 
		  			WHERE COALESCE(bt.ResourceID,p.ResourceID) = rd.ResourceID
		  				AND rd.matchid = @matchid
		  		) AS rs
	  	ORDER BY COALESCE(bt.OrdNo,p.OrdNo)


		---This block code support until Adminsite confirmed result to ResultDetailOS for Volleyball, Squash, Sepak Takrow
		IF 	(	@SportType IN ( 6, 30, 48 )
				AND EXISTS (SELECT TOP 1 1 FROM @tmbResultDetail r WHERE r.HomeValue IS NULL AND r.ResultSetting IS NULL)
			)
		BEGIN
			INSERT INTO @tmpBetStatus (val, chk )
			SELECT f.val , CHARINDEX('-', val)  
			FROM dbo.f_SplitString( @betstatus, ',') f
			WHERE ISNULL(@betstatus,'') <>''
				AND @betstatus NOT LIKE '%Refund%'
			OPTION (MAXRECURSION 0)

			UPDATE @tmpBetStatus
			SET  HomeValue = CASE WHEN chk = 0 THEN '' ELSE LEFT (val, chk-1) END
				,AwayValue = CASE WHEN chk = 0 THEN '' ELSE RIGHT ( val , len(val)-chk ) END

			UPDATE @tmpBetStatus 
				SET ResourceID = '010' + CAST(Id AS VARCHAR(1))

			INSERT INTO @tmpBetStatus ( ResourceID, HomeValue, AwayValue )
			SELECT '00', CAST( @FinalHomeScore AS VARCHAR(20) ), CAST( @FinalAwayScore AS VARCHAR(20) )
			WHERE @FinalHomeScore IS NOT NULL

			UPDATE r
			SET HomeValue = b.HomeValue			
				,AwayValue = b.AwayValue			
			FROM @tmbResultDetail r
			INNER JOIN @tmpBetStatus b ON r.ResourceID = b.ResourceID
			WHERE r.HomeValue IS NULL
		END
	END
	
	ELSE
	BEGIN
		INSERT INTO @tmbResultDetail (
				ResourceID			
				,HomeValue			
				,AwayValue			
				,ResultStatusId		
				,SettlementStatusId	
				,ResultSetting		
				,TicketStatus		
				,IsSpecialBettype	
		)
		SELECT COALESCE(bt.ResourceID, p.ResourceID) AS ResourceID
	    		,rs.HomeValue
				,rs.AwayValue
				,rs.ResultStatusId
				,SettlementStatusId
				,rs.ResultSetting
	          ,CASE 
					WHEN (ISNULL(bt.BetCount, 0) = 0 AND ISNULL(p.BetCount, 0) = 0) 
						OR (ISNULL(bt.InWaiting,0) + ISNULL(p.InWaiting,0) = ISNULL(bt.BetCount, 0) + ISNULL(p.BetCount, 0)) THEN 'No Ticket'
					WHEN ISNULL(bt.InRunning,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.InRunning,0) ELSE 0 END > 0 THEN 'Running'
					WHEN ISNULL(bt.betMarkedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetMarkedCount,0) ELSE 0 END  > 0 THEN 'Marked'
					WHEN ISNULL(bt.BetSettledCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetSettledCount,0) ELSE 0 END > 0 THEN 'Calculated'
					WHEN ISNULL(bt.BetRefundedCount,0) + CASE WHEN @IsMergedParlay = 1 THEN ISNULL(p.BetRefundedCount,0) ELSE 0 END > 0 THEN CASE WHEN @SettleType = 'EAR' THEN 'Calculated' ELSE 'Refunded' END
					END AS TicketStatus 
				,CASE WHEN ISNULL(bt.IsSpecialBettype,0) + ISNULL(p.IsSpecialBettype,0) > 0 THEN 1 ELSE 0 END AS IsSpecialBettype --flag column for tennis
	  	FROM @tmpTicketStatus bt
	  			 FULL JOIN @tmpTicketStatusParlay p ON	bt.resourceId = p.ResourceID
				 OUTER  APPLY(
		  			SELECT HomeValue, 
		    			AwayValue, 
		    			ResultStatusID, 
		    			SettlementStatusID,
						ISNULL(rd.ResultSetting, 0) AS ResultSetting
		  			FROM DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
		  			WHERE COALESCE(bt.ResourceID,p.ResourceID) = rd.ResourceID
		  				AND rd.matchid = @matchid
		  		) AS rs
	  	ORDER BY COALESCE(bt.OrdNo, p.OrdNo) 
	END

	SELECT ResourceID			
		  ,HomeValue			
		  ,AwayValue			
		  ,ResultStatusId		
		  ,SettlementStatusId	
		  ,ResultSetting		
		  ,TicketStatus		
		  ,IsSpecialBettype	
	FROm @tmbResultDetail

	-- number of ticket
	SELECT	0 AS GroupId 
			,SUM(betRunningCount) AS betRunningCount
			,SUM(betSettledCount) AS betSettledCount
			,SUM(betMarkedCount) AS betMarkedCount
	FROM (
		SELECT	SUM(InRunning) AS betRunningCount
				,SUM(betSettledCount) + SUM(BetRefundedCount) AS betSettledCount
				,SUM(betMarkedCount) AS betMarkedCount
		FROM	@tmpTicketStatus	
		UNION ALL
		SELECT	SUM(InRunning) AS betRunningCount
				,SUM(betSettledCount) + SUM(BetRefundedCount) AS betSettledCount
				,SUM(betMarkedCount) AS betMarkedCount
		FROM	@tmpTicketStatusParlay
		WHERE	@IsMergedParlay = 1
	)t

END
GO