/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_OU_Select]
(	
	@RequestId			  INT = 0
	,@IssueTypeId		  INT = 6
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
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		
	Param's explanation:
		+ @WrongOUInfo, @Wrong1stOUInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" FilterFromBetId ="" FilterToBetId = "" FilterBy="" WrongMarket ="" SubIssueTypeId=""/></root>

		(Filterby 0: By BetID, 1: By Transdate)
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

	CREATE TABLE #SpecialDeleteBets_OU (
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
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			MainTransId           BIGINT,
			StatusId			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			FilterBy			  TINYINT		
	)

	CREATE TABLE #tmpRefCodeSummary_OU (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT,
			SubIssueTypeId SMALLINT,
			FilterBy TINYINT
	)

	CREATE INDEX IX_SpecialDeleteBets_OU_RefCode ON #SpecialDeleteBets_OU(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_OU_Refcode ON #tmpRefCodeSummary_OU (RefCode)
	
	CREATE TABLE #logInfo_OU (
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
	)

	CREATE TABLE #TransidInRequest_OU (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #CashOuts_OU (RequestId INT, MatchId INT, transid BIGINT, bettype SMALLINT)
	CREATE TABLE #FilterInfo_OU (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,FilterFromBetId		BIGINT
		,FilterToBetId			BIGINT
		,FilterBy				TINYINT
		,SubIssueTypeId			SMALLINT
		,WrongMarket			VARCHAR(50)
	)
	CREATE TABLE #FilterBetId_OU (MatchId INT, totalBetId INT, totalRecord INT, MinTransdate DATETIME, MaxTransdate DATETIME)
	CREATE TABLE #transIdTemp_OU (matchid INT, transid BIGINT, transdate DATETIME)

	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)

	DECLARE @Validation AS TABLE (
			IsInvalidTransId		 BIT 
			,IsInValidTotalTickets   BIT 
			,IsExistedInOtherRequest BIT 
			,IsExistSingle			 BIT 
			,IsExistParlay			 BIT 
			,MatchProcessXML		 XML 
			,MatchParlayProcessXML	 XML
			,MatchId                 INT
		)
	DECLARE @InstantlySettleCount_tmp AS TABLE (InstantlySettleCount BIGINT, SettleCount BIGINT, RequestId INT, MatchId INT)

	SET @WrongOUInfoXML = CONVERT(XML, @WrongOUInfo)
		
	INSERT INTO #FilterInfo_OU(MatchId, FilterFromTransTime, FilterToTransTime, FilterFromBetId, FilterToBetId, FilterBy, WrongMarket, SubIssueTypeId)
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
		  
		CREATE TABLE #InstantSettlementBettypes_OU(matchid INT, bettype SMALLINT)	

		--> Get status of match
		;WITH cte_match AS
		(
			SELECT DISTINCT t.matchid
			FROM #FilterInfo_OU t
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = t.matchid and m.eventstatus <> @eventstatus_completed
		)
		,cte_isCalHT AS
		(
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM cte_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
		)
		--> Build bettype list supported for instant settlement based on settlement status of match
		INSERT INTO #InstantSettlementBettypes_OU (matchid, bettype)
		SELECT c.matchid,  f.bettype
		FROM cte_isCalHT c
			CROSS APPLY (
					SELECT bettype
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId FROM #FilterInfo_OU

	/*Check valid transid*/
	IF EXISTS ( SELECT TOP 1 1 FROM #FilterInfo_OU WHERE FilterBy = 0)
	BEGIN
		INSERT INTO #transIdTemp_OU (matchid, transid, transdate)
		SELECT b.matchid, b.transid, b.transdate
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #FilterInfo_OU f ON b.matchid = f.MatchId        
		WHERE f.FilterBy = 0 AND b.transid IN ( f.FilterFromBetId, f.FilterToBetId)

		INSERT INTO #FilterBetId_OU (MatchId, totalBetId, totalRecord, MinTransdate, MaxTransdate)
		SELECT f.matchid 
				,CASE WHEN f.FilterFromBetId = f.FilterToBetId THEN 1 ELSE 2 END AS totalBetId
				,b.totalRecord
				,MinTransdate
				,MaxTransdate
		FROM #FilterInfo_OU f  
		OUTER APPLY (
						SELECT COUNT (1) totalRecord, MIN (b.transdate) MinTransdate, MAX(transdate) MaxTransdate
						FROM #transIdTemp_OU  b WITH (NOLOCK) 
						WHERE b.matchid = f.MatchId
					)b
		WHERE f.FilterBy = 0

		IF  EXISTS ( SELECT TOP 1 1 FROM #FilterBetId_OU
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
			FROM #FilterBetId_OU f 
			WHERE 1 = CASE WHEN totalBetId = 2 AND totalRecord <> 2 THEN 1
							WHEN totalBetId = 1 AND totalRecord <> 1 THEN 1
							ELSE 0 END
				
			--TransId in request table
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId
			FROM #TransidInRequest_OU r
			
			--Loginfo Table
			SELECT l.MatchId, l.LiveScores, l.VoidFromTime, l.VoidToTime, l.SingleCount, l.MainParlayCount, l.SettleCount, l.MinSingleTransId, l.MaxSingleTransId, l.MinMainParlayTransId, l.MaxMainParlayTransId
			FROM #logInfo_OU l

			RETURN;
		END

		UPDATE w
		SET FilterFromTransTime = t.MinTransdate
			,FilterToTransTime = t.MaxTransdate
		FROM #FilterInfo_OU w
			INNER JOIN #FilterBetId_OU t ON w.MatchId = t.matchid

	END
	
	INSERT INTO #SpecialDeleteBets_OU(
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
			,matchid
			,StatusId
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
			,b.matchid
			,b.statusID
			,d.SubIssueTypeId
			,d.FilterBy
	FROM	bettrans b WITH (NOLOCK)	
		INNER JOIN #FilterInfo_OU d ON d.MatchId = b.matchid
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
					INNER JOIN #FilterInfo_OU d ON d.MatchId = bm.matchid
				WHERE 1 = CASE WHEN @ActionId <> 2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
							ELSE 0 END
					AND bm.betfrom <> 'P')
	BEGIN		
		INSERT INTO #SpecialDeleteBets_OU(
				SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,matchid
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
				,sub.matchid
				,d.SubIssueTypeId
				,d.FilterBy
		FROM	#FilterInfo_OU d
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

	IF EXISTS (SELECT TOP(1) 1 FROM #SpecialDeleteBets_OU WHERE IsMixParlay = 1)
	BEGIN
		UPDATE s SET s.transid = b.transid, s.StatusId = b.statusID
		FROM #SpecialDeleteBets_OU s 
			INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON b.refno = s.refno AND b.bettype = 29 AND b.matchid = 29
	END

	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets_OU WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #SpecialDeleteBets_OU main
				INNER JOIN #SpecialDeleteBets_OU sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets_OU  
		INSERT INTO #tmpRefCodeSummary_OU(RefCode, custid, bettype, transid, MatchId, SubIssueTypeId, FilterBy)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid, SubIssueTypeId, FilterBy
		FROM #SpecialDeleteBets_OU
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid, SubIssueTypeId, FilterBy
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #SpecialDeleteBets_OU(
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
						,matchid
						,StatusId
						,SubIssueTypeId
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
						,b.matchid
						,b.statusID
						,t.SubIssueTypeId
						,t.FilterBy
			FROM #tmpRefCodeSummary_OU t
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
		INSERT INTO #TransidInRequest_OU (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
		FROM #SpecialDeleteBets_OU t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, rs.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId, rp.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId
			AND r.ActionId NOT IN (2)
			
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest_OU)
		BEGIN
			SELECT @IsExistedInOtherRequest = 1

			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest_OU t WHERE t.MatchId = v.MatchId)
		END
	END

	--Data Section
	INSERT INTO #logInfo_OU (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MinSingleTransId, MaxSingleTransId, MainParlayCount, MinMainParlayTransId, MaxMainParlayTransId)
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
	FROM #SpecialDeleteBets_OU b WITH (NOLOCK)
		LEFT JOIN #InstantSettlementBettypes_OU i ON i.bettype = b.bettype AND i.matchid = b.matchid
		OUTER APPLY (
				SELECT TOP 1 t.TransId
				FROM #TransidInRequest_OU t 
				WHERE t.TransId = b.SubTransid
		)tmp
	WHERE tmp.TransId IS NULL
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

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
		FROM #TransidInRequest_OU r

		/*Get log info for Void Page*/
		INSERT INTO #CashOuts_OU (RequestId, MatchId, transid, bettype)
		SELECT @RequestId, s.MatchId, s.TransId, b.bettype
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			CROSS APPLY (
						SELECT CONVERT(XML, r.TransIds)
						FROM dbo.TicketVoiding_RequestDetail r WITH (NOLOCK)
						WHERE r.Id = s.RequestDetailId
							AND r.RequestId = @RequestId
				)AS t(xDATA)
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
			LEFT JOIN #InstantSettlementBettypes_OU i ON i.bettype = b.bettype AND i.matchid = b.matchid
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
					FROM #CashOuts_OU
					WHERE RequestId = rd.RequestId AND MatchId = rd.MatchId
			) c
			LEFT JOIN @InstantlySettleCount_tmp t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo_OU

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
		IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest_OU)
		BEGIN
			SELECT RequestId,
				STUFF((
				SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest_OU
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
				,1,2,'') AS TransIds
				,MatchId
			FROM #TransidInRequest_OU r
			GROUP BY r.RequestId, r.MatchId
		END
		ELSE
		BEGIN 
			SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
				,r.RequestId, r.MatchId
			FROM #TransidInRequest_OU r
		END
			
		--Loginfo Table
		DELETE #logInfo_OU
		SELECT MatchId FROM #logInfo_OU

		RETURN;
	END

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
	FROM @Validation v
		OUTER APPLY( 
			SELECT SUM(SingleCount) AS SingleCount
				,SUM(MainParlayCount) AS MainParlayCount
			FROM #logInfo_OU
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
			FROM #SpecialDeleteBets_OU AS t
			WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest_OU r WHERE r.TransId = t.SubTransid)
				AND t.matchid = v.MatchId
			GROUP BY t.matchid
		)tmp

	SET @MatchProcessXML = (
		SELECT DISTINCT t.matchid "@MatchId"
			,1 AS "@KeyID"
		FROM #SpecialDeleteBets_OU t
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest_OU r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)
	
	--Lock Refno process - SportBook
	EXEC dbo.NAP_Set_GlobalSettingSel 
		@LockName = 'ParlayRefno'
		,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT '' AS MatchId, t.Refno --Many matches with same Refno  
	FROM #SpecialDeleteBets_OU t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest_OU r WHERE r.TransId = t.SubTransid)
			AND t.IsMixParlay = 1
	GROUP BY t.Refno  
	HAVING COUNT(*) > 1

	SET @TotalRefnoParlay = @@ROWCOUNT
	
	INSERT INTO @tblMatchParlay (MatchId, RefNo)
	SELECT  t.MatchId, t.RefNo
	FROM #SpecialDeleteBets_OU t
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest_OU r WHERE r.TransId = t.SubTransid)
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
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest_OU)
	BEGIN
		SELECT RequestId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest_OU
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
			,MatchId
		FROM #TransidInRequest_OU r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT CAST(r.TransId AS VARCHAR(MAX)) AS TransIds
			,r.RequestId, r.MatchId
		FROM #TransidInRequest_OU r
	END

	--Loginfo table
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
	FROM #logInfo_OU l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo_OU rd WITH(NOLOCK)
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
	GROUP BY MatchId, w.scores

	DROP TABLE #SpecialDeleteBets_OU
	DROP TABLE #TransidInRequest_OU
	DROP TABLE #logInfo_OU
	DROP TABLE #tmpRefCodeSummary_OU
	DROP TABLE #CashOuts_OU
	DROP TABLE #InstantSettlementBettypes_OU
	DROP TABLE #FilterInfo_OU
	DROP TABLE #FilterBetId_OU
	DROP TABLE #transIdTemp_OU
END
GO

