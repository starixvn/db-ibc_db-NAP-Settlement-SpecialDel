/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_OU_Select]
(	
	@MatchId              INT = 0
	,@RequestId			  INT = 0
	,@UserID			  INT
	,@IssueTypeId		  INT = 1
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@SubIssueTypeId	  INT = NULL
	,@WrongOUInfo		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20220510
	Task: Refactor code issue type Wrong OU & Wrong 1st OU [Redmine: #172281]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #172281]

	Param's explanation:
		+ @WrongOUInfo, @Wrong1stOUInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterFromBetId ="" FilterToBetId = "" FilterBy="" WrongMarket ="" SubIssueTypeId=""/></root>

		(Filterby 0: By BetID, 1: By Transdate, 2: By Checktime, 4: Filter by Transdate & Checktime)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @IsInvalidTransId		  BIT = 0
			,@IsInValidTotalTickets   BIT = 0
			,@IsExistedInOtherRequest BIT = 0
			,@SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@IsExistSingle			  BIT = 0
			,@IsExistParlay			  BIT = 0
			,@MatchProcessXML		  XML = NULL
			,@MatchParlayProcessXML	  XML = NULL
			,@TotalRefnoParlay		  INT = 0
			,@ThreadHold			  INT = 0-- over threadhold, the parlay process will be locked in systemsetting
			,@FilterBy				  TINYINT = 0
	
	DECLARE	 @WrongOUInfoXML		  XML = NULL

	CREATE TABLE #SpecialDeleteBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			sporttype             SMALLINT,
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			MainTransId           BIGINT,
			LiveIndicator		  BIT,
			StatusId			  TINYINT,
			checktime			  DATETIME,
			accepttype			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			ScoreId				  INT,
			FilterBy			  TINYINT		
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT,
			SubIssueTypeId SMALLINT,
			ScoreId		INT,
			FilterBy TINYINT
	)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	CREATE TABLE #logInfo (
		 MatchId				INT
		,LiveScores				NVARCHAR(300)
		,VoidFromTime			DATETIME
		,VoidToTime				DATETIME
		,SingleCount			INT
		,CashOutCount			INT
		,InstantlySettleCount	INT
		,SettleCount            INT
		,MainParlayCount		INT
		,MinSingleTransId		BIGINT
		,MaxSingleTransId		BIGINT
		,MinMainParlayTransId	BIGINT
		,MaxMainParlayTransId	BIGINT
		,HighLightTransId		BIGINT
		,HighlightAcceptType	TINYINT
		,ScoreId				INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT, ScoreId INT, Refno BIGINT)
	CREATE TABLE #CashOuts (RequestId INT, MatchId INT, transid BIGINT, bettype SMALLINT, ScoreId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterFromBetId		BIGINT
		,FilterToBetId			BIGINT
		,FilterBy				TINYINT
		,SubIssueTypeId			SMALLINT
		,ScoreId				INT
		,LiveHomeScore			SMALLINT
		,LiveAwayScore			SMALLINT
		,HomeFavorite			VARCHAR(50)
		,AwayFavorite			VARCHAR(50)
		,HdpValue				VARCHAR(50)
		,WrongMarket			VARCHAR(50) --Wrong OU & 1H OU
	)
	CREATE TABLE #FilterBetId (MatchId INT, totalBetId INT, totalRecord INT, MinTransdate DATETIME, MaxTransdate DATETIME)
	CREATE TABLE #transIdTemp (matchid INT, transid BIGINT, transdate DATETIME)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)

	DECLARE @Validation AS TABLE (
			livehomescore			 SMALLINT
			,liveawayscore			 SMALLINT
			,IsInvalidTransId		 BIT 
			,IsInValidTotalTickets   BIT 
			,IsExistedInOtherRequest BIT 
			,IsExistSingle			 BIT 
			,IsExistParlay			 BIT 
			,MatchProcessXML		 XML 
			,MatchParlayProcessXML	 XML
			,LiveScores				 NVARCHAR(300)
			,MatchId                 INT
			,ScoreId                 INT
		)
	DECLARE @InstantlySettleCount_tmp AS TABLE (InstantlySettleCount BIGINT, SettleCount BIGINT, ScoreId INT, RequestId INT, MatchId INT)

	SET @WrongOUInfoXML = CONVERT(XML, @WrongOUInfo)
		
	INSERT INTO #FilterInfo(MatchId, FilterFromTransTime, FilterToTransTime, FilterFromBetId, FilterToBetId, FilterBy, WrongMarket, SubIssueTypeId)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,CASE WHEN t.c.value('@FilterFromBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterFromBetId','BIGINT') END AS FilterFromBetId
			,CASE WHEN t.c.value('@FilterToBetId','BIGINT') = 0 THEN NULL ELSE t.c.value('@FilterToBetId','BIGINT') END AS FilterToBetId
			,t.c.value('@FilterBy','TINYINT') AS FilterBy
			,t.c.value('@WrongMarket','VARCHAR(50)') AS WrongMarket
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM	@WrongOUInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOUInfoXML = NULL ))

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
	
		DECLARE @IsHTCal BIT = 0
			  , @eventstatus NVARCHAR(50) = ''
		  
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	
		CREATE CLUSTERED INDEX IDX_InstantSettlementBettypes_bettype_matchid ON #InstantSettlementBettypes(bettype, matchid)

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT DISTINCT t.matchid
			FROM #FilterInfo t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_Set_Instant_GetBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId FROM #FilterInfo

	/*Check valid transid*/
	IF EXISTS ( SELECT TOP 1 1 FROM #FilterInfo WHERE FilterBy = 0)
	BEGIN
		INSERT INTO #transIdTemp (matchid, transid, transdate)
		SELECT b.matchid, b.transid, b.transdate
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #FilterInfo f ON b.matchid = f.MatchId        
		WHERE f.FilterBy = 0 AND b.transid IN ( f.FilterFromBetId, f.FilterToBetId)

		INSERT INTO #FilterBetId (MatchId, totalBetId, totalRecord, MinTransdate, MaxTransdate)
		SELECT f.matchid 
				,CASE WHEN f.FilterFromBetId = f.FilterToBetId THEN 1 ELSE 2 END AS totalBetId
				,b.totalRecord
				,MinTransdate
				,MaxTransdate
		FROM #FilterInfo f  
		OUTER APPLY (
						SELECT COUNT (1) totalRecord, MIN (b.transdate) MinTransdate, MAX(transdate) MaxTransdate
						FROM #transIdTemp  b WITH (NOLOCK) 
						WHERE b.matchid = f.MatchId
					)b
		WHERE f.FilterBy = 0

		IF  EXISTS ( SELECT TOP 1 1 FROM #FilterBetId
									WHERE 1 = CASE WHEN totalBetId = 2 AND totalRecord <> 2 THEN 1
													WHEN totalBetId = 1 AND totalRecord <> 1 THEN 1
													ELSE 0 END
					)
		BEGIN
			SELECT @IsInvalidTransId = 1
			
			--Error Table
			SELECT f.MatchId AS MatchId
				,@IsInvalidTransId AS IsInvalidTransId
				,@IsInValidTotalTickets AS IsInValidTotalTickets
				,@IsExistedInOtherRequest AS IsExistedInOtherRequest
				,@IsExistSingle AS IsExistSingle
				,@IsExistParlay AS IsExistParlay
				,@MatchProcessXML AS MatchProcessXML
				,@MatchParlayProcessXML AS MatchParlayProcessXML
			FROM #FilterBetId f 
			WHERE 1 = CASE WHEN totalBetId = 2 AND totalRecord <> 2 THEN 1
							WHEN totalBetId = 1 AND totalRecord <> 1 THEN 1
							ELSE 0 END
				
			--TransId in request table
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
			FROM #TransidInRequest r
			
			--Loginfo Table
			SELECT l.MatchId, l.LiveScores, l.VoidFromTime, l.VoidToTime, l.SingleCount, l.MainParlayCount, l.SettleCount, l.MinSingleTransId, l.MaxSingleTransId, l.MinMainParlayTransId, l.MaxMainParlayTransId
			FROM #logInfo l

			RETURN;
		END

		UPDATE w
		SET FilterFromTransTime = t.MinTransdate
			,FilterToTransTime = t.MaxTransdate
		FROM #FilterInfo w
			INNER JOIN #FilterBetId t ON w.MatchId = t.matchid

	END
	
	INSERT INTO #SpecialDeleteBets(
			transid		
			,SubTransid		
			,refno			
			,custid				
			,transdate		
			,bettype 					
			,livehomescore 	
			,liveawayscore 			
			,betdaqid	
			,WalletType
			,RefCode
			,LiveIndicator
			,matchid
			,StatusId
			,checktime
			,SubIssueTypeId
			,FilterBy
		)
	SELECT  b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.betdaqid
			,b.WalletType
			,b.RefCode
			,b.liveindicator
			,b.matchid
			,b.statusID
			,b.checktime
			,d.SubIssueTypeId
			,d.FilterBy
	FROM	bettrans b WITH (NOLOCK)	
		INNER JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid AND m.sporttype = 1 --soccer
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		OUTER APPLY (
			SELECT DISTINCT value AS WrongMarket
			FROM STRING_SPLIT(d.WrongMarket, '&')
			WHERE value <> ''				
		)xHDPou
	WHERE b.betfrom <> 'P'  
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
		AND 1 = CASE WHEN @IssueTypeId = 6 AND b.bettype = 3 THEN 1
						WHEN @IssueTypeId = 7 AND b.bettype = 8 THEN 1
						ELSE 0 END
		AND 1 = CASE WHEN d.SubIssueTypeId IN (10,11) AND b.hdp1 = xHDPou.WrongMarket THEN 1 --Wrong OU & 1H OU
						ELSE 0 END
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT 1
				FROM dbo.bettransm AS bm WITH (NOLOCK)
					INNER JOIN #FilterInfo d ON d.MatchId = bm.matchid
				WHERE 1 = CASE WHEN @ActionId <> 2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
					AND bm.betfrom <> 'P')
	BEGIN		
		INSERT INTO #SpecialDeleteBets(
				SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,LiveIndicator
				,matchid
				,checktime
				,SubIssueTypeId
				,FilterBy
			)
		SELECT  sub.transid AS SubTransID
				,sub.refno
				,sub.custid				
				,sub.transdate
				,29
				,sub.livehomescore
				,sub.liveawayscore
				,1 AS IsMixParlay
				,sub.liveindicator
				,sub.matchid
				,sub.checktime
				,d.SubIssueTypeId
				,d.FilterBy
		FROM	#FilterInfo d
				INNER LOOP JOIN dbo.bettransm sub WITH (NOLOCK) ON sub.matchid = d.MatchId
				OUTER APPLY (
					SELECT DISTINCT value AS WrongMarket
					FROM STRING_SPLIT(d.WrongMarket, '&')
					WHERE value <> ''				
				)xHDPou
		WHERE 1 = CASE WHEN @ActionId <>2 AND sub.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND sub.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND sub.betfrom <> 'P'
				AND sub.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND 1 = CASE WHEN @IssueTypeId = 6 AND sub.bettype = 3 THEN 1
								WHEN @IssueTypeId = 7 AND sub.bettype = 8 THEN 1
								ELSE 0 END
				AND 1 = CASE WHEN d.SubIssueTypeId IN (10,11) AND sub.hdp1 = xHDPou.WrongMarket THEN 1 --Wrong OU & 1H OU
								ELSE 0 END
	END  

	IF EXISTS (SELECT TOP(1) 1 FROM #SpecialDeleteBets WHERE IsMixParlay = 1)
	BEGIN
		UPDATE s SET s.transid = b.transid, s.StatusId = b.statusID
		FROM #SpecialDeleteBets s 
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = s.refno AND b.bettype = 29 AND b.matchid = 29
	END

	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #SpecialDeleteBets main
				INNER JOIN #SpecialDeleteBets sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, transid, MatchId, SubIssueTypeId, ScoreId, FilterBy)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid, SubIssueTypeId, ScoreId, FilterBy
		FROM #SpecialDeleteBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid, SubIssueTypeId, ScoreId, FilterBy
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #SpecialDeleteBets(
						transid		
						,SubTransid		
						,refno			
						,custid					
						,transdate		
						,bettype 					
						,livehomescore 	
						,liveawayscore 			
						,betdaqid
						,WalletType
						,RefCode
						,MainTransId
						,LiveIndicator
						,matchid
						,StatusId
						,checktime
						,SubIssueTypeId
						,ScoreId
						,FilterBy
					)
				SELECT   b.transid
						,b.transid AS SubTransID
						,b.refno
						,b.custid
						,b.transdate
						,b.bettype
						,b.livehomescore
						,b.liveawayscore
						,b.betdaqid
						,b.WalletType
						,b.RefCode
						,t.transid AS MainTransId
						,b.liveindicator
						,b.matchid
						,b.statusID
						,b.checktime
						,t.SubIssueTypeId
						,t.ScoreId
						,t.FilterBy
			FROM #tmpRefCodeSummary t
					INNER JOIN dbo.bettrans b WITH (NOLOCK)
							ON b.RefCode = t.RefCode
							AND b.transid <> t.transid
							AND b.matchid = t.MatchId
							AND b.custid = t.custid
							AND b.bettype = t.bettype 
			WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
		END  			    				    					    				    					    	
	END
	
	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId,Refno)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid,tmp.Refno
		FROM #SpecialDeleteBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, RequestId, NULL AS Refno
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid
							AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.TransId, 0 AS MainTransId, RequestId, bm.refno
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
							INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = rp.TransId
						WHERE rp.TransId = t.SubTransid
							AND rp.MatchId = t.matchid
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId
			AND r.ActionId NOT IN (2)
			
		IF EXISTS (SELECT TOP 1 1 FROM #TransidInRequest t WHERE t.Refno IS NOT NULL)
		BEGIN
			UPDATE   t
				SET MainTransId = b.transid
			FROM   #TransidInRequest  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			WHERE t.Refno IS NOT NULL
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1

			IF EXISTS (SELECT TOP (1) 1 FROM @Validation)
			BEGIN
				UPDATE v SET v.IsExistedInOtherRequest = 1
				FROM @Validation v
				WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
			END
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId, ScoreId)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,MIN(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS MinSingleTransId
		,MAX(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS MaxSingleTransId
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MainParlayCount
		,MIN(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MinMainParlayTransId
		,MAX(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MaxMainParlayTransId
		,b.ScoreId
	FROM #SpecialDeleteBets b WITH (NOLOCK)
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		OUTER APPLY (
				SELECT TOP 1 t.TransId
				FROM #TransidInRequest t 
				WHERE t.TransId = b.SubTransid
		)tmp
	WHERE tmp.TransId IS NULL
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))
		, b.matchid, b.ScoreId
	ORDER BY b.ScoreId, CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		SELECT MatchId
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,MatchProcessXML AS MatchProcessXML
			,MatchParlayProcessXML AS MatchParlayProcessXML
		FROM @Validation

		--TransId in request table
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId, r.MatchId
		FROM #TransidInRequest r

		/*Get log info for Void Page*/
		INSERT INTO #CashOuts (RequestId, MatchId, transid, bettype, ScoreId)
		SELECT @RequestId, s.MatchId, s.TransId, b.bettype, NULL
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			CROSS APPLY (
						SELECT CONVERT(XML, r.TransIds)
						FROM dbo.TicketVoiding_RequestDetail r WITH (NOLOCK)
						WHERE r.Id = s.RequestDetailId
							AND r.RequestId = @RequestId
				)AS t(xDATA)
			CROSS APPLY (
					SELECT t.c.value('@ScoreId','INT') AS ScoreId
					FROM t.xDATA.nodes('/r') t(c)
				) tmp (ScoreId)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND b.matchid = s.MatchId
		WHERE s.RequestId = @RequestId
			AND b.betdaqid = -2 AND b.StatusId IN (111, 112, 113)

		/*Get Instant settlement*/
		INSERT INTO @InstantlySettleCount_tmp (InstantlySettleCount, SettleCount, RequestId, MatchId)
		SELECT COUNT(CASE WHEN i.bettype IS NOT NULL THEN s.TransId ELSE NULL END) AS InstantlySettleCount
				,COUNT(CASE WHEN i.bettype IS NULL THEN s.TransId ELSE NULL END) AS SettleCount
			, @RequestId, b.matchid
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.transid AND s.MatchId =  b.matchid
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		WHERE s.RequestId = @RequestId
			AND b.statusID IN (111,112,113) AND ISNULL(b.betdaqid, -1) <> -2
		GROUP BY b.matchid

		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,c.CashOutCount AS CashOutCount
			,t.InstantlySettleCount
			,t.SettleCount
			,rd.MainParlayCount
			,rd.MinSingleTransId
			,rd.MaxSingleTransId
			,rd.MinMainParlayTransId
			,rd.MaxMainParlayTransId
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			OUTER APPLY (
					SELECT COUNT(transid) AS CashOutCount
					FROM #CashOuts
					WHERE RequestId = rd.RequestId AND MatchId = rd.MatchId
			) c
			LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo

	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		SELECT @IsInValidTotalTickets = 1

		SELECT MatchId
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,@IsInValidTotalTickets AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
			,ISNULL(IsExistSingle,0) AS IsExistSingle
			,ISNULL(IsExistParlay,0) AS IsExistParlay
			,MatchProcessXML AS MatchProcessXML
			,MatchParlayProcessXML AS MatchParlayProcessXML
		FROM @Validation

		--TransId in request table
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
			FROM #TransidInRequest r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE
		BEGIN 
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest r
		END
			
		--Loginfo Table
		DELETE #logInfo
		SELECT MatchId, ScoreId FROM #logInfo

		RETURN;
	END

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
		OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l

	---Prepare for lock match---
	UPDATE v SET 
			v.IsExistSingle = tmp.IsExistSingle
		, v.IsExistParlay = tmp.IsExistParlay
	FROM @Validation v
	CROSS APPLY (
			SELECT   MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) THEN 1 ELSE 0 END) AS IsExistSingle
					, MAX (CASE WHEN t.IsMixParlay = 1 THEN 1 ELSE 0 END) AS IsExistParlay
			FROM #SpecialDeleteBets AS t
			WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
				AND t.matchid = v.MatchId
			GROUP BY t.matchid
		)tmp

	SET @MatchProcessXML = (
		SELECT DISTINCT t.matchid "@MatchId"
			,1 AS "@KeyID"
		FROM #SpecialDeleteBets t
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)
	
	--Lock Refno process - SportBook
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT '' AS MatchId, t.Refno --Many matches with same Refno  
	FROM #SpecialDeleteBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
			AND t.IsMixParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1

	SET @TotalRefnoParlay = @@ROWCOUNT
	
	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT  t.MatchId, t.RefNo
	FROM #SpecialDeleteBets t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	  AND NOT EXISTS (SELECT 1 FROM @tblMatchParlay m WHERE m.RefNo = t.refno) 
			AND t.IsMixParlay = 1
	
	SELECT @TotalRefnoParlay = @TotalRefnoParlay + @@ROWCOUNT

	IF @TotalRefnoParlay <= @ThreadHold
	BEGIN
		SET @MatchParlayProcessXML = (
		SELECT  DISTINCT MatchId "@MatchId"
				,refno AS "@RefNo"
		FROM @tblMatchParlay 
		FOR XML PATH('r'), ROOT('root'))
	END	
	ELSE
	BEGIN
		SET @MatchParlayProcessXML = NULL
	END

	UPDATE @Validation SET MatchProcessXML = @MatchProcessXML, MatchParlayProcessXML = @MatchParlayProcessXML

	--Error Table
	SELECT MatchId
		,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
		,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
		,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
		,ISNULL(IsExistSingle,0) AS IsExistSingle
		,ISNULL(IsExistParlay,0) AS IsExistParlay
		,MatchProcessXML AS MatchProcessXML
		,MatchParlayProcessXML AS MatchParlayProcessXML
	FROM @Validation

	--TransId in request table
	--For EKO check transid exists in request		
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,MatchId
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId, r.MatchId
		FROM #TransidInRequest r
	END

	--Loginfo table
	;WITH _cte AS (
			SELECT MatchId
				,STUFF(w.scores,1,1,'') AS LiveScores
				,MIN(VoidFromTime) AS VoidFromTime
				,MAX(VoidToTime) AS VoidToTime
				,SUM(SingleCount) AS SingleCount
				,SUM(CashOutCount) AS CashOutCount
				,SUM(InstantlySettleCount) AS InstantlySettleCount
				,SUM(SettleCount) AS SettleCount
				,SUM(MainParlayCount) AS MainParlayCount
				,MIN(MinSingleTransId) AS MinSingleTransId
				,MAX(MaxSingleTransId) AS MaxSingleTransId
				,MIN(MinMainParlayTransId) AS MinMainParlayTransId
				,MAX(MaxMainParlayTransId) AS MaxMainParlayTransId
			FROM #logInfo l
				CROSS APPLY(
							SELECT '|' + LiveScores
							FROM #logInfo rd WITH(NOLOCK)
							where l.MatchId = rd.MatchId
							FOR XML PATH('')
							)w (scores) 
			GROUP BY MatchId, w.scores
		)
	SELECT MatchId
		, LiveScores
		,VoidFromTime
		,VoidToTime
		,SingleCount
		,CashOutCount
		,InstantlySettleCount
		,SettleCount
		,MainParlayCount
		,MinSingleTransId
		,MaxSingleTransId
		,MinMainParlayTransId
		,MaxMainParlayTransId
	FROM _cte l

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #CashOuts
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #FilterBetId
	DROP TABLE #transIdTemp
END
GO

