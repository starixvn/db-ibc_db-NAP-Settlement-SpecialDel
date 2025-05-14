/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
alter PROCEDURE [dbo].[TicketVoiding_VoidTimeByAllowanceSetting_Select]
(	
	 @IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@WrongScoreInfo	  VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo  VARCHAR(MAX) = NULL
	,@RedCardInfo		  VARCHAR(MAX) = NULL
	
)
AS
/*	
	Created by: 20250513@July
	Task: DA/RC/WC - Update the validation to get tickets based on allowance setting [Redmine: #227029]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20250513@July: Create new SP [Redmine: #227029]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SiteDBGroupID			SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MinAccept				TINYINT	= 0	
		   ,@VoidFromTime			DATETIME = NULL
		   ,@VoidToTime				DATETIME = NULL
		   ,@MatchId				INT	= 0
		   ,@FilterFromTransTime	DATETIME = NULL
		   ,@FilterToTransTime		DATETIME = NULL
		   ,@FilterBy				TINYINT = 1
		   ,@SubIssueTypeId			INT	= NULL
		   ,@AATime					TINYINT	= 0 
		   ,@PATime					TINYINT	= 0
		   ,@SATime					TINYINT	= 0
		   ,@VoidFromTime_tmp		DATETIME = NULL
		   ,@CancelCOFromTime		DATETIME = NULL
		   ,@CancelCOToTime		    DATETIME = NULL
		   ,@ScoreId				INT = NULL

	DECLARE @InforXML XML = NULL
	IF @IssueTypeId IN (1,10) --Danger Accept, Red card
	BEGIN
        SET @InforXML = CASE WHEN @IssueTypeId = 1 THEN CONVERT(XML, @DangerAcceptedInfo)
                             ELSE CONVERT(XML, @RedCardInfo) END

	END
	ELSE IF @IssueTypeId = 3 --Wrong score
	BEGIN
		SET @InforXML = CONVERT(XML, @WrongScoreInfo)

	END
	
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterBy				TINYINT
		,ScoreId				INT
		,AATime					TINYINT
		,PATime					TINYINT
		,SATime					TINYINT
		,SubIssueTypeId		    INT
		,VoidFromTime			DATETIME
		,VoidToTime			    DATETIME
		,isFinish				BIT
		,Sporttype				SMALLINT
		,MatchId_tmp			INT
	)

	 -- Insert data into #FilterInfo
    INSERT INTO #FilterInfo (MatchId, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime, ScoreId)
    SELECT
        t.c.value('@MatchId', 'INT'),
        t.c.value('@FilterFromTransTime', 'DATETIME'),
        t.c.value('@FilterToTransTime', 'DATETIME'),
        t.c.value('@FilterBy', 'TINYINT'),
        t.c.value('@SubIssueTypeId', 'INT'),
        CASE WHEN t.c.value('@AATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@AATime', 'TINYINT') END,
        CASE WHEN t.c.value('@PATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@PATime', 'TINYINT') END,
        CASE WHEN t.c.value('@SATime', 'VARCHAR(100)') = '' THEN NULL ELSE t.c.value('@SATime', 'TINYINT') END,
        CASE WHEN @IssueTypeId = 3 THEN t.c.value('@ScoreId', 'INT') ELSE NULL END
    FROM @InforXML.nodes('root/r') t(c);

	UPDATE d
	SET d.Sporttype = m.sporttype, MatchId_tmp = d.MatchId
	FROM #FilterInfo d
		INNER JOIN dbo.match m ON d.MatchId = m.MatchId

    -- Handle child matches for Cricket/Baseball
    IF EXISTS (SELECT 1 FROM #FilterInfo WHERE Sporttype IN (50, 8))
    BEGIN
        INSERT INTO #FilterInfo (MatchId, FilterFromTransTime, FilterToTransTime, FilterBy, SubIssueTypeId, AATime, PATime, SATime, Sporttype, MatchId_tmp, ScoreId)
        SELECT
            f.MatchId,
            f.FilterFromTransTime,
            f.FilterToTransTime,
            f.FilterBy,
            f.SubIssueTypeId,
            f.AATime,
            f.PATime,
            f.SATime,
            m.Sporttype,
            m.MatchId,
			f.ScoreId
        FROM #FilterInfo f
        INNER JOIN dbo.match m ON f.MatchId = m.ParentID
        WHERE m.Sporttype IN (50, 8) AND m.ChildMatchType = 200;
    END

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT 
	  ,Subtransid BIGINT
	  ,transdate DATETIME
	  ,checktime DATETIME
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
	  ,CheckTimeCashOut DATETIME
	  ,AcceptModeCashOut  TINYINT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,Status NVARCHAR(10)
	  ,SubStatus NVARCHAR(10)
      ,bettype SMALLINT
	  ,betdaqid BIGINT
	  ,Subbettype SMALLINT
	)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)
	
	IF @IssueTypeId in (1,10)
	BEGIN
		--Search single tickets
		INSERT INTO #tmpTransInfo(
				matchid 
				,transid
				,Subtransid 
				,transdate 
				,checktime 
				,bettype 
				,betdaqid 
				,LiveBetAcceptTime 
				,SecAcceptTime 
				,Subbettype 
				,Subtransdate 
				,Subchecktime 
				,SubLiveBetAcceptTime 
				,SubSecAcceptTime 
				,IsMixParlay 
				,Status
				,SubStatus 
				,SiteDBGroupID
				,CheckTimeCashOut
				,AcceptModeCashOut
			)
		SELECT DISTINCT d.MatchId
			,b.TransId
			,b.transid AS SubTransID
			,b.transdate
			,b.checktime
			,b.bettype
			,b.betdaqid 
			,bi.LiveBetAcceptTime 
			,bi.SecAcceptTime 
			,b.bettype AS Subbettype 
			,b.transdate AS Subtransdate 
			,b.checktime AS Subchecktime 
			,bi.LiveBetAcceptTime AS SubLiveBetAcceptTime 
			,bi.SecAcceptTime AS SubSecAcceptTime 
			,0 AS IsMixParlay 
			,b.Status
			,b.status AS SubStatus 
			,b.SiteDBGroupID
			,c.CheckTime AS CheckTimeCashOut
			,c.AcceptMode AS AcceptModeCashOut
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
			INNER JOIN @bettype_tmp bt ON b.bettype = bt.bettype
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
			CROSS APPLY (
				SELECT CASE WHEN d.FilterBy = 1 THEN b.transdate 
						WHEN d.FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime 
						WHEN d.FilterBy = 2 AND b.checktime IS NULL THEN b.transdate 
				END AS VoidTime
			)act
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN act.VoidTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
						 ELSE CASE WHEN b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
								   ELSE 0 END
						 END
			AND b.SiteDBGroupID = @SiteDBGroupID
	
		--Search sub-parlay
		IF EXISTS (
						SELECT TOP(1) 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN #FilterInfo d oN d.MatchId_tmp = bm.matchid
						WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  					   WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   					   ELSE 0 END
							AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
						)
		BEGIN		
			INSERT INTO #tmpTransInfo(
					matchid 
					,transid
					,Subtransid 
					,transdate 
					,checktime 
					,bettype 
					,betdaqid 
					,LiveBetAcceptTime 
					,SecAcceptTime 
					,Subbettype 
					,Subtransdate 
					,Subchecktime 
					,SubLiveBetAcceptTime 
					,SubSecAcceptTime 
					,IsMixParlay 
					,Status
					,SubStatus 
					,SiteDBGroupID
				)
			SELECT DISTINCT d.MatchId
				,b.TransId
				,sub.transid AS SubTransID
				,b.transdate
				,b.checktime
				,b.bettype
				,b.betdaqid 
				,NULL AS LiveBetAcceptTime 
				,NULL AS SecAcceptTime 
				,sub.bettype AS Subbettype 
				,sub.transdate AS Subtransdate 
				,sub.checktime AS Subchecktime 
				,sub.LiveBetAcceptTime AS SubLiveBetAcceptTime 
				,sub.SecAcceptTime AS SubSecAcceptTime 
				,1 AS IsMixParlay 
				,b.Status
				,sub.status AS SubStatus 
				,sub.SiteDBGroupID
			FROM #FilterInfo d
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
				INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
				INNER JOIN @bettype_tmp bt ON sub.bettype = bt.bettype
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  		   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
				   		   ELSE 0 END
				AND sub.betfrom <> 'P'
				AND b.matchid = 29 AND b.bettype = 29
				AND CASE WHEN d.FilterBy = 1 THEN sub.transdate
						 WHEN d.FilterBy = 2 AND sub.checktime IS NOT NULL THEN sub.checktime
						 WHEN d.FilterBy = 2 AND sub.checktime IS NULL THEN sub.transdate
					END BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID

		END

		-----Delete ticket check subissuetype exclude bettypes (single & parlay).
		DELETE b
		FROM #tmpTransInfo b
			INNER JOIN #FilterInfo d ON b.matchid = d.MatchId
		WHERE EXISTS (SELECT TOP 1 1 
							FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() f 
							WHERE f.bettype = b.Subbettype AND f.SubIssueTypeId = d.SubIssueTypeId AND f.IssueTypeId = @IssueTypeId)

		------Get Return VoidFromTime/VoidToTime
		WHILE (1=1) 
		BEGIN
			SELECT @MinAccept				= 0	
				, @VoidFromTime				= NULL
				, @VoidToTime				= NULL
				, @MatchId					= 0
				, @FilterFromTransTime		= NULL
				, @FilterToTransTime		= NULL
				, @FilterBy					= 1
				, @SubIssueTypeId			= NULL
				, @AATime					= 0 
				, @PATime					= 0
				, @SATime					= 0
				, @CancelCOFromTime			= NULL
				, @CancelCOToTime			= NULL
				, @VoidFromTime_tmp			= NULL

			UPDATE TOP(1) m SET
				m.isFinish = 1
				,@MatchId = m.MatchId
				,@FilterFromTransTime = m.FilterFromTransTime
				,@FilterToTransTime = m.FilterToTransTime
				,@FilterBy = m.FilterBy
				,@SubIssueTypeId = m.SubIssueTypeId
				,@AATime = m.AATime
				,@PATime = m.PATime
				,@SATime = m.SATime
			FROM #FilterInfo m
			WHERE m.isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
		
			IF @AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL --case AA,PA,SA fields blank
			BEGIN
				UPDATE #FilterInfo
				SET VoidFromTime = @FilterFromTransTime, VoidToTime = @FilterToTransTime
				WHERE MatchId = @MatchId
			END 
			ELSE
			BEGIN
				SELECT @MinAccept = @AATime

				IF @MinAccept > @PATime SET @MinAccept = @PATime
				IF @MinAccept > @SATime SET @MinAccept = @SATime

				SELECT @VoidFromTime_tmp = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

				SELECT @VoidFromTime = MIN(CASE WHEN act.FromDate >= DATEADD (SECOND,CASE WHEN act.AcceptType = 1 THEN @AATime
																						  WHEN act.AcceptType = 2 THEN @SATime
																						  ELSE @PATime --act.AcceptType = 3
																					 END
																					,@FilterFromTransTime
																				  )
													 THEN act.FromDate ELSE NULL END
												)
					  ,@VoidToTime = MAX(act.FromDate)
				FROM (
					SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, b.LiveBetAcceptTime, b.SecAcceptTime
					FROM #tmpTransInfo b
					WHERE b.IsMixParlay = 0
						AND ISNULL(b.betdaqid,-1) NOT IN (1)
					UNION ALL
					SELECT NULL AS transid, bm.Subtransid, bm.Subbettype AS bettype, bm.Subtransdate AS transdate, bm.Subchecktime AS checktime, bm.SubLiveBetAcceptTime AS LiveBetAcceptTime, bm.SubSecAcceptTime AS SecAcceptTime
					FROM #tmpTransInfo bm 
					WHERE bm.IsMixParlay = 1
				)b
				CROSS APPLY (
						SELECT CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
									ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
											  ELSE 3 --Pending Accept
										 END
								END AS AcceptType
							  ,CASE 
									WHEN @FilterBy = 1 THEN b.transdate
									WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
									WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							   END AS FromDate
				)act
				WHERE act.FromDate BETWEEN @VoidFromTime_tmp AND @FilterToTransTime
		
				/*	Get tickets that need to be canceled cash out (with allowance setting). Check AA/PA/SA for cancel cash out tickets based on [cashoutselling.AcceptMode]
					Auto Accept: AcceptMode = 1
					Pending Accept: AcceptMode = 0
					Second Accept: AcceptMode = 2
					AcceptMode = Null means that ticket is not accepted (Rejected or other fail to sell situation) => Not get
				*/
				SELECT @CancelCOFromTime = MIN(CASE WHEN b.CheckTimeCashOut >= DATEADD (SECOND,CASE WHEN b.AcceptModeCashOut = 1 THEN @AATime
																									WHEN b.AcceptModeCashOut = 2 THEN @SATime
																									WHEN b.AcceptModeCashOut = 0 THEN @PATime
																									END
																							,@FilterFromTransTime)
																	THEN b.CheckTimeCashOut ELSE NULL END)
					  ,@CancelCOToTime = MAX(b.CheckTimeCashOut)
				FROM #tmpTransInfo b 
				WHERE b.IsMixParlay = 0
					AND b.betdaqid = -2 AND b.AcceptModeCashOut IS NOT NULL
					AND b.CheckTimeCashOut BETWEEN @VoidFromTime_tmp AND @FilterToTransTime

				IF @VoidFromTime IS NULL
				BEGIN
					SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
				END
				ELSE --Must ticket Void -> have cancel cash out.
				BEGIN
					IF @CancelCOFromTime IS NOT NULL 
					BEGIN
						IF @VoidFromTime > @CancelCOFromTime SET @VoidFromTime = @CancelCOFromTime --From Time: compare the time and get the smallest one

						IF @VoidToTime < @CancelCOToTime SET @VoidToTime = @CancelCOToTime --To Time: compare the time and get the largest one
					END
				END

				UPDATE #FilterInfo
				SET VoidFromTime = @VoidFromTime, VoidToTime = @VoidToTime
				WHERE MatchId = @MatchId
			END 
		END
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		--Search single tickets
		INSERT INTO #tmpTransInfo(
				matchid 
				,transid
				,Subtransid 
				,transdate 
				,checktime 
				,bettype 
				,betdaqid 
				,LiveBetAcceptTime 
				,SecAcceptTime 
				,Subbettype 
				,Subtransdate 
				,Subchecktime 
				,SubLiveBetAcceptTime 
				,SubSecAcceptTime 
				,IsMixParlay 
				,Status
				,SubStatus 
				,SiteDBGroupID
				,CheckTimeCashOut
				,AcceptModeCashOut
			)
		SELECT DISTINCT d.MatchId
			,b.TransId
			,b.transid AS SubTransID
			,b.transdate
			,b.checktime
			,b.bettype
			,b.betdaqid 
			,bi.LiveBetAcceptTime 
			,bi.SecAcceptTime 
			,b.bettype AS Subbettype 
			,b.transdate AS Subtransdate 
			,b.checktime AS Subchecktime 
			,bi.LiveBetAcceptTime AS SubLiveBetAcceptTime 
			,bi.SecAcceptTime AS SubSecAcceptTime 
			,0 AS IsMixParlay 
			,b.Status
			,b.status AS SubStatus 
			,b.SiteDBGroupID
			,c.CheckTime AS CheckTimeCashOut
			,c.AcceptMode AS AcceptModeCashOut
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #FilterInfo d ON d.MatchId_tmp = b.matchid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			LEFT JOIN dbo.BettransInfo bi WITH(NOLOCK) ON b.transid = bi.transid
			LEFT JOIN dbo.CashOutSelling c WITH(NOLOCK) ON b.TransId = c.TransID
		WHERE  1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN b.checktime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1
						 WHEN b.checktime NOT BETWEEN d.FilterFromTransTime AND d.FilterToTransTime 	
						  AND b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
						 WHEN b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime THEN 1	
						 WHEN b.transdate NOT BETWEEN d.FilterFromTransTime AND d.FilterToTransTime 	
						  AND b.betdaqid = -2 AND c.CheckTime IS NOT NULL AND c.CheckTime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime AND c.AcceptMode IS NOT NULL THEN 1
						 ELSE 0 END
			AND b.SiteDBGroupID = @SiteDBGroupID
	
		--Search sub-parlay
		IF EXISTS (
						SELECT TOP(1) 1
						FROM dbo.bettransm AS bm WITH (NOLOCK)
							INNER JOIN #FilterInfo d oN d.MatchId_tmp = bm.matchid
						WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
									   WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
									   ELSE 0 END
							AND bm.betfrom <> 'P' AND bm.SiteDBGroupID = @SiteDBGroupID
						)
		BEGIN		
			INSERT INTO #tmpTransInfo(
					matchid 
					,transid
					,Subtransid 
					,transdate 
					,checktime 
					,bettype 
					,betdaqid 
					,LiveBetAcceptTime 
					,SecAcceptTime 
					,Subbettype 
					,Subtransdate 
					,Subchecktime 
					,SubLiveBetAcceptTime 
					,SubSecAcceptTime 
					,IsMixParlay 
					,Status
					,SubStatus 
					,SiteDBGroupID
				)
			SELECT DISTINCT d.MatchId
				,b.TransId
				,sub.transid AS SubTransID
				,b.transdate
				,b.checktime
				,b.bettype
				,b.betdaqid 
				,NULL AS LiveBetAcceptTime 
				,NULL AS SecAcceptTime 
				,sub.bettype AS Subbettype 
				,sub.transdate AS Subtransdate 
				,sub.checktime AS Subchecktime 
				,sub.LiveBetAcceptTime AS SubLiveBetAcceptTime 
				,sub.SecAcceptTime AS SubSecAcceptTime 
				,1 AS IsMixParlay 
				,b.Status
				,sub.status AS SubStatus 
				,sub.SiteDBGroupID
			FROM #FilterInfo d
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON d.MatchId_tmp = sub.matchid
				INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON b.refno = sub.refno
				INNER JOIN @bettype_tmp bt ON bt.bettype = sub.bettype
			WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						   WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						   ELSE 0 END
				AND sub.betfrom <> 'P'
				AND b.matchid = 29 AND b.bettype = 29
				AND ((sub.checktime BETWEEN d.FilterFromTransTime AND d.FilterToTransTime) OR (sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime))
				AND b.SiteDBGroupID = @SiteDBGroupID AND sub.SiteDBGroupID = @SiteDBGroupID
		END 

		--Delete ticket having subissuetype exclude bettype
		DELETE b
		FROM #tmpTransInfo AS b
		INNER JOIN #FilterInfo AS f ON b.matchid = f.MatchId
		WHERE EXISTS (SELECT TOP 1 1
					  FROM dbo.f_TVS_CheckingSubIssueTypeIdExcludeBettypes() AS d
					  WHERE d.BetType = b.Subbettype AND d.SubIssueTypeId = f.SubIssueTypeId AND d.IssueTypeId = @IssueTypeId)

		WHILE (1=1) 
		BEGIN
			SELECT @MinAccept				= 0	
				, @VoidFromTime				= NULL
				, @VoidToTime				= NULL
				, @FilterFromTransTime		= NULL
				, @FilterToTransTime		= NULL
				, @AATime					= 0 
				, @PATime					= 0
				, @SATime					= 0
				, @ScoreId					= NULL
				, @CancelCOFromTime			= NULL
				, @CancelCOToTime			= NULL
				, @VoidFromTime_tmp			= NULL
				, @Matchid					= 0
				, @FilterBy					= 1

			UPDATE TOP(1) m SET
				m.isFinish = 1
				,@FilterFromTransTime = m.FilterFromTransTime
				,@FilterToTransTime = m.FilterToTransTime
				,@AATime = m.AATime
				,@PATime = m.PATime
				,@SATime = m.SATime
				,@ScoreId = m.ScoreId
				,@MatchId = m.MatchId
				,@FilterBy = m.FilterBy
			FROM #FilterInfo m
			WHERE m.isFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
		
			IF (@FilterBy <> 2) OR (@AATime IS NULL AND @PATime IS NULL AND @SATime IS NULL) --case AA,PA,SA fields blank
			BEGIN
				UPDATE #FilterInfo
				SET VoidFromTime = @FilterFromTransTime, VoidToTime = @FilterToTransTime
				WHERE MatchId = @MatchId AND ScoreId = @ScoreId
			END 
			ELSE
			BEGIN
				SELECT @MinAccept = @AATime

				IF @MinAccept > @PATime SET @MinAccept = @PATime
				IF @MinAccept > @SATime SET @MinAccept = @SATime

				SELECT @VoidFromTime_tmp = DATEADD (SECOND,@MinAccept,@FilterFromTransTime)

				SELECT @VoidFromTime = MIN(CASE WHEN act.FromDate >= DATEADD (SECOND,CASE WHEN act.AcceptType = 1 THEN @AATime
																						  WHEN act.AcceptType = 2 THEN @SATime
																						  ELSE @PATime --act.AcceptType = 3
																					 END
																					,@FilterFromTransTime
																				  )
													 THEN act.FromDate ELSE NULL END
												)
					  ,@VoidToTime = MAX(act.FromDate)
				FROM (
					SELECT b.transid, NULL AS subtransid, b.bettype, b.transdate, b.checktime, b.LiveBetAcceptTime, b.SecAcceptTime
					FROM #tmpTransInfo b 
					WHERE b.IsMixParlay = 0
						AND ISNULL(b.betdaqid,-1) NOT IN (1)
					UNION ALL
					SELECT NULL AS transid, bm.Subtransid, bm.Subbettype AS bettype, bm.Subtransdate AS transdate, bm.Subchecktime AS checktime, bm.SubLiveBetAcceptTime AS LiveBetAcceptTime, bm.SubSecAcceptTime AS SecAcceptTime
					FROM #tmpTransInfo bm 
					WHERE bm.IsMixParlay = 1
				)b
				CROSS APPLY (
						SELECT CASE WHEN b.checktime IS NULL THEN 1 --Auto Accept
									ELSE CASE WHEN b.checktime = DATEADD(SECOND,ISNULL(b.LiveBetAcceptTime,0) + ISNULL(b.SecAcceptTime,0), b.transdate) THEN 2 --Second Accept
											  ELSE 3 --Pending Accept
										 END
								END AS AcceptType
							  ,CASE WHEN @FilterBy = 2 AND b.checktime IS NOT NULL THEN b.checktime
									WHEN @FilterBy = 2 AND b.checktime IS NULL THEN b.transdate
							   END AS FromDate
				)act
				WHERE act.FromDate BETWEEN @VoidFromTime_tmp AND @FilterToTransTime
			
				/*	Get tickets that need to be canceled cash out (with allowance setting). Check AA/PA/SA for cancel cash out tickets based on [cashoutselling.AcceptMode]
					Auto Accept: AcceptMode = 1
					Pending Accept: AcceptMode = 0
					Second Accept: AcceptMode = 2
					AcceptMode = Null means that ticket is not accepted (Rejected or other fail to sell situation) => Not get
				*/
				SELECT @CancelCOFromTime = MIN(CASE WHEN b.CheckTimeCashOut >= DATEADD (SECOND,CASE WHEN b.AcceptModeCashOut = 1 THEN @AATime
																									WHEN b.AcceptModeCashOut = 2 THEN @SATime
																									WHEN b.AcceptModeCashOut = 0 THEN @PATime
																									END
																							,@FilterFromTransTime)
																	THEN b.CheckTimeCashOut ELSE NULL END)
					  ,@CancelCOToTime = MAX(b.CheckTimeCashOut)
				FROM #tmpTransInfo b 
				WHERE b.IsMixParlay = 0
					AND b.betdaqid = -2 AND b.AcceptModeCashOut IS NOT NULL
					AND b.CheckTimeCashOut BETWEEN @VoidFromTime_tmp AND @FilterToTransTime

				IF @VoidFromTime IS NULL
				BEGIN
					SELECT @VoidFromTime = NULL ,@VoidToTime = NULL
				END
				ELSE --Must ticket Void -> have cancel cash out.
				BEGIN
					IF @CancelCOFromTime IS NOT NULL 
					BEGIN
						IF @VoidFromTime > @CancelCOFromTime SET @VoidFromTime = @CancelCOFromTime --From Time: compare the time and get the smallest one

						IF @VoidToTime < @CancelCOToTime SET @VoidToTime = @CancelCOToTime --To Time: compare the time and get the largest one
					END
				END

				UPDATE #FilterInfo
				SET VoidFromTime = @VoidFromTime, VoidToTime = @VoidToTime
				WHERE MatchId = @MatchId
			END 
		END
	END

	SELECT MatchId, ScoreId, VoidFromTime, VoidToTime 
	FROM #FilterInfo

	DROP TABLE #tmpTransInfo
	DROP TABLE #FilterInfo
END
GO

