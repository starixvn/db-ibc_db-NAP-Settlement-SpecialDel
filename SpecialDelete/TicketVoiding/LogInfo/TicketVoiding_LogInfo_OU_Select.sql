/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_OU_Select]
(	
	@RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 6
	,@WrongOUInfo		  VARCHAR(MAX) = NULL
	,@TransInfo		      VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20220510
	Task: Refactor code issue type Wrong OU & Wrong 1st OU [Redmine: #172281]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220510@Max: Create new SP [Redmine: #172281]
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220720@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:
		+ @WrongOUInfo, @Wrong1stOUInfo:
			<root>
				<r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" WrongMarket ="" SubIssueTypeId=""/>
			</root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
	
	DECLARE	 @WrongOUInfoXML		  XML = NULL
			,@TransInfoXML         XML = NULL

	CREATE TABLE #TVSTicketBets (
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
			SubIssueTypeId		  SMALLINT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT,
			SubIssueTypeId SMALLINT
	)

	CREATE INDEX IX_TVSTicketBets_RefCode ON #TVSTicketBets (RefCode)
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
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,WrongMarket			VARCHAR(50)
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,Subtransid BIGINT
	  ,custid	INT	
      ,transdate DATETIME
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
      ,betteam NVARCHAR(10)
      ,refno BIGINT
      ,bettype SMALLINT
      ,betdaqid BIGINT
      ,betfrom NVARCHAR(1)
      ,statusID TINYINT
      ,WalletType TINYINT
	  ,RefCode BIGINT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Subbetfrom NVARCHAR(1)
	  ,Subbettype SMALLINT
	  ,SubstatusID TINYINT
	  ,Subtransdate DATETIME
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	DECLARE @Validation AS TABLE (
			IsInvalidTransId		 BIT 
			,IsInValidTotalTickets   BIT 
			,IsExistedInOtherRequest BIT 
			,MatchId                 INT
		)
	DECLARE @InstantlySettleCount_tmp AS TABLE (InstantlySettleCount BIGINT, SettleCount BIGINT, RequestId INT, MatchId INT)

	SET @WrongOUInfoXML = CONVERT(XML, @WrongOUInfo)
		
	INSERT INTO #FilterInfo(MatchId, FilterFromTransTime, FilterToTransTime, WrongMarket, SubIssueTypeId)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@WrongMarket','VARCHAR(50)') AS WrongMarket
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM	@WrongOUInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOUInfoXML = NULL ))

	BEGIN -- Instant Settlement declaration
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT)	

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
					FROM dbo.f_TVS_GetInstantBettypes() 
					WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
								WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
							ELSE 0 END
			)f	 	
	END	
	
	SET @TransInfoXML = CONVERT(XML, @TransInfo)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,refno
		  ,custid		
		  ,transdate 
		  ,hdp1 
		  ,hdp2 
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,bettype
		  ,betdaqid 
		  ,betfrom
		  ,statusID
		  ,WalletType 
		  ,RefCode 
		  ,Subbetfrom
		  ,Subbettype
		  ,Subtransdate
		  ,Subhdp1
		  ,Subhdp2
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT t.c.value('@matchid','INT') AS matchid
			,t.c.value('@transid','BIGINT') AS transid
			,t.c.value('@Subtransid','BIGINT') AS Subtransid
			,t.c.value('@refno','BIGINT') AS refno
			,t.c.value('@custid','INT') AS custid
			,t.c.value('@transdate','DATETIME') AS transdate
			,t.c.value('@hdp1','SMALLMONEY') AS hdp1
			,t.c.value('@hdp2','SMALLMONEY') AS hdp2
			,t.c.value('@livehomescore','SMALLINT') AS livehomescore
			,t.c.value('@liveawayscore','SMALLINT') AS liveawayscore
			,t.c.value('@liveindicator','BIT') AS liveindicator
			,t.c.value('@bettype','SMALLINT') AS bettype
			,t.c.value('@betdaqid','BIGINT') AS betdaqid
			,t.c.value('@betfrom','NVARCHAR(1)') AS betfrom
			,t.c.value('@statusID','TINYINT') AS statusID
			,t.c.value('@WalletType','TINYINT') AS WalletType
			,t.c.value('@RefCode','BIGINT') AS RefCode
			,t.c.value('@Subbetfrom','NVARCHAR(1)') AS Subbetfrom
			,t.c.value('@Subbettype','SMALLINT') AS Subbettype
			,t.c.value('@Subtransdate','SMALLINT') AS Subtransdate
			,t.c.value('@Subhdp1','SMALLMONEY') AS Subhdp1
			,t.c.value('@Subhdp2','SMALLMONEY') AS Subhdp2
			,t.c.value('@IsMixParlay','BIT') AS IsMixParlay
			,t.c.value('@SiteDBGroupID','SMALLINT') AS SiteDBGroupID
	FROM @TransInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfoXML = NULL))

	--Init Validation
	INSERT INTO @Validation (MatchId)
	SELECT MatchId FROM #FilterInfo
	
	INSERT INTO #TVSTicketBets(
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
	FROM #tmpTransInfo b 
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		CROSS APPLY (
			SELECT DISTINCT value AS WrongMarket
			FROM STRING_SPLIT(d.WrongMarket, '&')
			WHERE value <> ''				
		)xHDPou
	WHERE b.betfrom <> 'P'  
		AND b.hdp1 = xHDPou.WrongMarket
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
		AND 1 = CASE WHEN @IssueTypeId = 6 AND b.bettype = 3 THEN 1
					 WHEN @IssueTypeId = 7 AND b.bettype = 8 THEN 1
					 ELSE 0 END
		
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT 1
				FROM #tmpTransInfo bm
					INNER JOIN #FilterInfo d ON d.MatchId = bm.matchid
				WHERE 1 = CASE WHEN @ActionId <> 2 AND bm.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
							WHEN @ActionId = 2 AND bm.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
					AND bm.Subbetfrom <> 'P')
	BEGIN		
		INSERT INTO #TVSTicketBets(
				 transid
				,SubTransid		
				,refno			
				,custid						
				,transdate		
				,bettype					
				,livehomescore	
				,liveawayscore			
				,IsMixParlay
				,matchid
				,StatusId
				,SubIssueTypeId
			)
		SELECT  b.transid
				,b.SubTransID
				,b.refno
				,b.custid				
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,1 AS IsMixParlay
				,b.matchid
				,b.statusID
				,d.SubIssueTypeId
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				CROSS APPLY (
					SELECT DISTINCT value AS WrongMarket
					FROM STRING_SPLIT(d.WrongMarket, '&')
					WHERE value <> ''				
				)xHDPou
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.Subtransdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND b.Subhdp1 = xHDPou.WrongMarket
				AND 1 = CASE WHEN @IssueTypeId = 6 AND b.Subbettype = 3 THEN 1
								WHEN @IssueTypeId = 7 AND b.Subbettype = 8 THEN 1
								ELSE 0 END
	END  

	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE RefCode IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #TVSTicketBets main
				INNER JOIN #TVSTicketBets sub
						ON main.RefCode = sub.RefCode
						AND main.transid <> sub.transid	
						AND main.custid = sub.custid
						AND main.bettype = sub.bettype
		WHERE main.WalletType = 1					
		  
		-- Insert more bonus or cash ticket in case only one ticket appears in #TVSTicketBets  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, transid, MatchId, SubIssueTypeId)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid, SubIssueTypeId
		FROM #TVSTicketBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid, SubIssueTypeId
		HAVING COUNT(*) = 1

		IF @@ROWCOUNT > 0
		BEGIN	
			INSERT INTO #TVSTicketBets(
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
					)
				SELECT   b.transid
						,b.SubTransID
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
			FROM #tmpRefCodeSummary t
					INNER JOIN #tmpTransInfo b 
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
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
		FROM #TVSTicketBets t
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
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)
			
		IF @@ROWCOUNT <> 0
		BEGIN
			UPDATE v SET v.IsExistedInOtherRequest = 1
			FROM @Validation v
			WHERE EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest t WHERE t.MatchId = v.MatchId)
		END
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, SingleCount, CashOutCount, InstantlySettleCount, SettleCount, MainParlayCount)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid THEN b.transid ELSE NULL END) AS SingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS CashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS MainParlayCount
	FROM #TVSTicketBets b WITH (NOLOCK)
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		LEFT JOIN #TransidInRequest tmp ON tmp.TransId = b.SubTransid
	WHERE tmp.TransId IS NULL
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2))

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		
		SELECT MatchId
			,IsInvalidTransId
			,1 AS IsInValidTotalTickets
			,IsExistedInOtherRequest
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
			SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
			FROM #TransidInRequest 
		END
			
		--Loginfo Table
		DELETE #logInfo
		SELECT MatchId FROM #logInfo

		RETURN;
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		SELECT MatchId
			,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
			,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
			,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
		FROM @Validation

		--TransId in request table
		SELECT RequestId, MatchId, 
			   STUFF((SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
				FROM #TransidInRequest
				WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
				ORDER BY TransId
				FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId

		/*Get log info for Void Page*/
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, CashOutCount, InstantlySettleCount, SettleCount)
		SELECT @RequestId
			  ,b.matchid
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) = -2 THEN s.TransId ELSE NULL END) AS CashOutCount
			  ,COUNT(CASE WHEN i.bettype IS NOT NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS InstantlySettleCount
			  ,COUNT(CASE WHEN i.bettype IS NULL AND ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpTransInfo b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		WHERE s.RequestId = @RequestId AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid

		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,t.CashOutCount
			,t.InstantlySettleCount
			,t.SettleCount
			,rd.MainParlayCount
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId

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

	--Error Table
	SELECT MatchId
		,ISNULL(IsInvalidTransId,0) AS IsInvalidTransId
		,ISNULL(IsInValidTotalTickets, 0) AS IsInValidTotalTickets
		,ISNULL(IsExistedInOtherRequest,0) AS IsExistedInOtherRequest
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
	FROM #logInfo l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo rd WITH(NOLOCK)
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
	GROUP BY MatchId, w.scores

	SET @TransInfoXML = (
	SELECT DISTINCT 
			t.matchid AS "@matchid"
		    ,t.transid AS "@transid"
			,t.Subtransid AS "@Subtransid"
			,t.custid AS "@custid"
			,t.transdate AS "@transdate"
			,t.refno AS "@refno"
			,b.hdp1 AS "@hdp1"
			,b.hdp2 AS "@hdp2"
			,t.livehomescore AS "@livehomescore"
			,t.liveawayscore AS "@liveawayscore"
			,b.liveindicator AS "@liveindicator"
			,t.statusID AS "@statusID"
			,b.betfrom AS "@betfrom"
			,b.betdaqid AS "@betdaqid"
			,b.bettype AS "@bettype"
			,b.WalletType AS "@WalletType"
			,b.RefCode AS "@RefCode"
			,b.Subhdp1 AS "@Subhdp1"
			,b.Subhdp2 AS "@Subhdp2"
			,b.Subbettype AS "@Subbettype"
			,b.Subbetfrom AS "@Subbetfrom"
			,b.SubstatusID AS "@SubstatusID"
			,b.Subtransdate AS "@Subbetfrom"
			,b.IsMixParlay AS "@IsMixParlay"
			,b.SiteDBGroupID AS "@SiteDBGroupID"
		FROM #TVSTicketBets t
			INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)

	SELECT @TransInfoXML AS TransInfo

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO

