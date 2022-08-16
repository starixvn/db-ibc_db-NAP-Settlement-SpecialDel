/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_HDP_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 4
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@TransInfo		      XML = NULL
)
AS
/*	
	Created by: Max
	Date 20220510
	Task: Refactor code issue type Wrong OU & Wrong 1st OU [Redmine: #172281]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220510@Max: Create new SP [Redmine: #172281]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:
		+ @WrongHDPInfo, @Wrong1stHDPInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" HomeFavorite ="" AwayFavorite ="" HdpValue ="" SubIssueTypeId=""/></root>

*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
			,@WrongHDPInfoXML		  XML = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) =''
	 		,@OldActionId			  TINYINT

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
			StatusId			  TINYINT,
			SubIssueTypeId		  SMALLINT
	)

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
		,HomeFavorite			VARCHAR(50)
		,AwayFavorite			VARCHAR(50)
		,HdpValue				VARCHAR(50)
	)
	CREATE TABLE #logInfoVoidPage (RequestId INT, MatchId INT, CashOutCount INT, InstantlySettleCount INT, SettleCount INT)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT 
	  ,Subtransid BIGINT
	  ,refno BIGINT
	  ,custid INT	
      ,hdp1 SMALLMONEY
      ,hdp2 SMALLMONEY
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
	  ,odds MONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(1)
      ,bettype SMALLINT
      ,betteam NVARCHAR(10)
	  ,betcheck NVARCHAR(50)
	  ,Status NVARCHAR(10)
      ,transdate DATETIME
	  ,checktime DATETIME
	  ,betid BIGINT
	  ,Transdesc NVARCHAR(1000)
	  ,statusID TINYINT
	  ,Subcustid INT
	  ,Subhdp1 SMALLMONEY
      ,Subhdp2 SMALLMONEY
	  ,Sublivehomescore SMALLINT
      ,Subliveawayscore SMALLINT
	  ,Subliveindicator BIT
	  ,Subodds MONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(1)
	  ,Subbettype SMALLINT
	  ,Subbetteam  NVARCHAR(10)
	  ,Subbetcheck NVARCHAR(50)
	  ,SubStatus NVARCHAR(10)
	  ,Subtransdate DATETIME
	  ,Subchecktime DATETIME
	  ,SubTransdesc  NVARCHAR(1000)
	  ,SubstatusID TINYINT
	  ,srecommend INT
	  ,mrecommend INT
	  ,recommend INT
      ,creator INT
	  ,stake MONEY
	  ,oddstype TINYINT
	  ,CurrencyName NVARCHAR(50)
	  ,betdaqid BIGINT
	  ,ExtraInfo VARCHAR(1000)
	  ,BonusID INT
	  ,winlost	MONEY
	  ,actual_stake MONEY
	  ,winlostdate SMALLDATETIME
	  ,modds MONEY
	  ,statuswinlost MONEY
	  ,LiveBetAcceptTime SMALLINT
	  ,SecAcceptTime TINYINT
	  ,SubLiveBetAcceptTime SMALLINT
	  ,SubSecAcceptTime TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsMove14 BIT
	)

	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,MatchId                 INT
		)

	SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
	INSERT INTO #FilterInfo( 
			MatchID				
			,FilterFromTransTime	
			,FilterToTransTime			
			,HomeFavorite
			,AwayFavorite
			,HdpValue
			,SubIssueTypeId
		)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,CASE WHEN ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') ='' THEN NULL ELSE t.c.value('@HomeFavorite','VARCHAR(50)')  END AS HomeFavorite
			,CASE WHEN ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@AwayFavorite','VARCHAR(50)')  END AS AwayFavorite
			,CASE WHEN ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') = '' THEN NULL ELSE t.c.value('@HdpValue','VARCHAR(50)')  END AS HdpValue
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM @WrongHDPInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))

	INSERT INTO #tmpTransInfo( 
		    matchid 
	       ,transid 
		   ,Subtransid 
	       ,refno 
	       ,custid 	
           ,hdp1 
           ,hdp2 
           ,livehomescore 
           ,liveawayscore 
           ,liveindicator 
	       ,odds 
	       ,oddsspread 
           ,betfrom 
           ,bettype 
           ,betteam 
	       ,betcheck 
	       ,Status 
           ,transdate 
	       ,checktime 
	       ,betid 
	       ,Transdesc 
	       ,statusID 
	       ,Subcustid 
	       ,Subhdp1 
           ,Subhdp2 
	       ,Sublivehomescore 
           ,Subliveawayscore 
	       ,Subliveindicator 
	       ,Subodds 
	       ,Suboddsspread 
	       ,Subbetfrom 
	       ,Subbettype 
	       ,Subbetteam  
	       ,Subbetcheck 
	       ,SubStatus 
	       ,Subtransdate 
	       ,Subchecktime 
	       ,SubTransdesc  
	       ,SubstatusID 
	       ,srecommend 
	       ,mrecommend 
	       ,recommend 
           ,creator 
	       ,stake 
	       ,oddstype 
	       ,CurrencyName 
	       ,betdaqid 
	       ,ExtraInfo 
	       ,BonusID 
	       ,winlost	
	       ,actual_stake 
	       ,winlostdate 
	       ,modds 
	       ,statuswinlost 
	       ,LiveBetAcceptTime 
	       ,SecAcceptTime 
	       ,SubLiveBetAcceptTime 
	       ,SubSecAcceptTime 
           ,IsMixParlay 
	       ,SiteDBGroupID 
	       ,IsMove14 
	)
	SELECT t.c.value('@mid','INT') AS matchid	
		,t.c.value('@t','BIGINT') AS transid
		,t.c.value('@s_t','BIGINT') AS Subtransid
		,t.c.value('@ref','BIGINT') AS refno
		,t.c.value('@c','INT') AS custid
		,t.c.value('@hdp1','SMALLMONEY') AS hdp1
		,t.c.value('@hdp2','SMALLMONEY') AS hdp2
		,t.c.value('@lh','SMALLINT') AS livehomescore
		,t.c.value('@la','SMALLINT') AS liveawayscore
		,t.c.value('@li','BIT') AS liveindicator
		,t.c.value('@o','MONEY') AS odds
		,t.c.value('@os','MONEY') AS oddsspread
		,t.c.value('@bfr','NVARCHAR(1)') AS betfrom
		,t.c.value('@btype','SMALLINT') AS bettype
		,t.c.value('@bteam','NVARCHAR(10)') AS betteam
		,t.c.value('@bcheck','NVARCHAR(50)') AS betcheck
		,t.c.value('@s','NVARCHAR(10)') AS Status
		,t.c.value('@tdate','DATETIME') AS transdate
		,CASE WHEN t.c.value('@checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@checkt','DATETIME') END AS checktime
		,t.c.value('@bid','BIGINT') AS betid
		,t.c.value('@tdes','NVARCHAR(1000)') AS Transdesc
		,t.c.value('@sid','TINYINT') AS statusID
		,t.c.value('@s_c','INT') AS Subcustid
		,t.c.value('@s_hdp1','SMALLMONEY') AS Subhdp1
		,t.c.value('@s_hdp2','SMALLMONEY') AS Subhdp2
		,t.c.value('@s_lh','SMALLINT') AS Sublivehomescore
		,t.c.value('@s_la','SMALLINT') AS Subliveawayscore
		,t.c.value('@s_li','BIT') AS Subliveindicator
		,t.c.value('@s_o','MONEY') AS Subodds
		,t.c.value('@s_os','MONEY') AS Suboddsspread
		,t.c.value('@s_bfr','NVARCHAR(1)') AS Subbetfrom
		,t.c.value('@s_btype','SMALLINT') AS Subbettype
		,t.c.value('@s_bteam','NVARCHAR(10)') AS Subbetteam
		,t.c.value('@s_bcheck','NVARCHAR(50)') AS Subbetcheck
		,t.c.value('@s_s','NVARCHAR(10)') AS SubStatus
		,t.c.value('@s_tdate','DATETIME') AS Subtransdate
		,CASE WHEN t.c.value('@s_checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@s_checkt','DATETIME') END AS Subchecktime
		,t.c.value('@s_tdes','NVARCHAR(1000)') AS SubTransdesc
		,t.c.value('@s_sid', 'MONEY') AS SubstatusID
		,t.c.value('@sre','INT') AS srecommend
		,t.c.value('@mre','INT') AS mrecommend
		,t.c.value('@re','INT') AS recommend
		,t.c.value('@cr','INT') AS creator
		,t.c.value('@stake','MONEY') AS stake
		,t.c.value('@ost','TINYINT') AS oddstype
		,t.c.value('@curr','NVARCHAR(50)') AS CurrencyName
		,t.c.value('@bdaq','BIGINT') AS betdaqid
		,t.c.value('@ex','VARCHAR(1000)') AS ExtraInfo
		,t.c.value('@bo','INT') AS BonusID
		,t.c.value('@w','MONEY') AS winlost
		,t.c.value('@acstake','MONEY') AS actual_stake
		,CASE WHEN t.c.value('@wld','SMALLDATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@wld','SMALLDATETIME') END AS winlostdate
		,t.c.value('@m', 'MONEY') AS modds
		,t.c.value('@statuswl', 'MONEY') AS statuswinlost
		,t.c.value('@lbat', 'SMALLINT') AS LiveBetAcceptTime
		,t.c.value('@sat', 'TINYINT') AS SecAcceptTime
		,t.c.value('@s_lbat', 'SMALLINT') AS SubLiveBetAcceptTime
		,t.c.value('@s_sat', 'TINYINT') AS SubSecAcceptTime
		,t.c.value('@isP','BIT') AS IsMixParlay
		,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
		,t.c.value('@isM','BIT') AS IsMoved14 
	FROM @TransInfo.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

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
			,b.matchid
			,b.statusID
			,d.SubIssueTypeId
	FROM	#tmpTransInfo b 
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		OUTER APPLY (
			SELECT DISTINCT value AS HomeFavorite
			FROM STRING_SPLIT(d.HomeFavorite, '&')
			WHERE value <> ''				
		)xHDPHome
		OUTER APPLY (
			SELECT DISTINCT value AS AwayFavorite
			FROM STRING_SPLIT(d.AwayFavorite, '&')
			WHERE value <> ''				
		)xHDPAway
		OUTER APPLY (
			SELECT DISTINCT value AS HdpValue
			FROM STRING_SPLIT(d.HdpValue, '&')
			WHERE value <> ''				
		)xHDPvalue
	WHERE b.betfrom <> 'P'  
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
		AND 1 = CASE WHEN @IssueTypeId = 4 AND b.bettype = 1 THEN 1
						WHEN @IssueTypeId = 5 AND b.bettype = 7 THEN 1 
						ELSE 0 END
		AND 1 = CASE WHEN d.SubIssueTypeId IN (8,9) AND b.hdp1 = xHDPHome.HomeFavorite AND d.HomeFavorite IS NOT NULL THEN 1
						WHEN d.SubIssueTypeId IN (8,9) AND b.hdp2 = xHDPAway.AwayFavorite AND d.AwayFavorite IS NOT NULL THEN 1
						WHEN d.SubIssueTypeId IN (22,24) AND b.hdp2 = xHDPvalue.HdpValue AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
						WHEN d.SubIssueTypeId IN (23,25) AND b.hdp1 = xHDPvalue.HdpValue AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
						ELSE 0 END
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo bm  WHERE bm.IsMixParlay = 1)
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
				,b.Subtransid 
				,b.refno
				,b.custid				
				,b.transdate
				,b.bettype
				,b.livehomescore
				,b.liveawayscore
				,b.IsMixParlay
				,b.matchid
				,b.statusID
				,d.SubIssueTypeId
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				OUTER APPLY (
					SELECT DISTINCT value AS HomeFavorite
					FROM STRING_SPLIT(d.HomeFavorite, '&')
					WHERE value <> ''				
				)xHDPHome
				OUTER APPLY (
					SELECT DISTINCT value AS AwayFavorite
					FROM STRING_SPLIT(d.AwayFavorite, '&')
					WHERE value <> ''				
				)xHDPAway
				OUTER APPLY (
					SELECT DISTINCT value AS HdpValue
					FROM STRING_SPLIT(d.HdpValue, '&')
					WHERE value <> ''				
				)xHDPvalue
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.Subtransdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND 1 = CASE WHEN @IssueTypeId = 4 AND b.Subbettype = 1 THEN 1
							 WHEN @IssueTypeId = 5 AND b.Subbettype = 7 THEN 1 
							 ELSE 0 END
				AND 1 = CASE WHEN d.SubIssueTypeId IN (8,9) AND b.Subhdp1 = xHDPHome.HomeFavorite AND d.HomeFavorite IS NOT NULL THEN 1
							 WHEN d.SubIssueTypeId IN (8,9) AND b.Subhdp2 = xHDPAway.AwayFavorite AND d.AwayFavorite IS NOT NULL THEN 1
							 WHEN d.SubIssueTypeId IN (22,24) AND b.Subhdp2 = xHDPvalue.HdpValue AND d.HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
							 WHEN d.SubIssueTypeId IN (23,25) AND b.Subhdp1 = xHDPvalue.HdpValue AND d.HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
							 ELSE 0 END
	END  

	/*Get Transid in Request of range Transid*/
	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, t.matchid
		FROM #TVSTicketBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId, RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId , RequestId
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
		,0 AS InstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) <> -2 THEN  b.transid ELSE NULL END) AS SettleCount --Exclude InstantlySettleCount,CO
		,COUNT(CASE WHEN b.transid <> b.SubTransid THEN b.transid ELSE NULL END) AS MainParlayCount
	FROM #TVSTicketBets b
		LEFT JOIN #TransidInRequest tmp ON tmp.TransId = b.SubTransid
	WHERE tmp.TransId IS NULL
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ASC

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(SingleCount),0)
		,@MainParlayCount = ISNULL(SUM(MainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId, 1 AS IsInValidTotalTickets, IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
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
			
		-- 3. Loginfo Table
		DELETE #logInfo
		SELECT MatchId FROM #logInfo

		-- 4. Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table
		DELETE #tmpTransInfo
		SELECT Matchid FROM #tmpTransInfo

		RETURN;
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId, IsInValidTotalTickets, IsExistedInOtherRequest
		FROM @Validation

		-- 2. TransId in request table
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
			  ,0 AS InstantlySettleCount
			  ,COUNT(CASE WHEN ISNULL(b.betdaqid, -1) <> -2 THEN s.TransId ELSE NULL END) AS SettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpTransInfo b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
		WHERE s.RequestId = @RequestId AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid

		-- 3. Loginfo Table
		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,rd.SingleCount
			,t.CashOutCount AS CashOutCount
			,t.InstantlySettleCount
			,t.SettleCount
			,rd.MainParlayCount
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId

		-- 4. Unmark table
		SELECT NULL AS UnmarkTransIds
		
		-- 5. Transinfo table (No need return data)
		DELETE #tmpTransInfo
		SELECT Matchid FROM #tmpTransInfo

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

	IF @RequestId = 0
	BEGIN
		--Mark ticket when add request
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 0 
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

		IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 1 
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId NOT IN (2)
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.transid AND tp.IsMixParlay = 0
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL AND tr.TransId is NULL
												AND rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')

			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','

			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
													LEFT JOIN #TVSTicketBets tp ON rdt.TransId=tp.SubTransid AND tp.IsMixParlay = 1
													LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											  WHERE tp.SubTransid IS NULL AND tr.TransId IS NULL
													  AND rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')

			IF @OldActionId <> 2
			BEGIN
				--Add mark ticket when edit request
				SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
												FROM #TVSTicketBets t
													LEFT JOIN #TransidInRequest tr on tr.TransId = t.SubTransid
												WHERE t.IsMixParlay = 0 AND tr.TransId IS NULL
													AND NOT EXISTS( SELECT TOP 1 1 FROM TicketVoiding_RequestDetailTicket_Single rdt WHERE t.transid = rdt.transid AND rdt.RequestId = @RequestId)
												FOR XML PATH('')), 1, 1, '')
										, '')

				IF @MarkTransIds <> ''
					SET @MarkTransIds = @MarkTransIds + ','

				SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
												FROM #TVSTicketBets t
													LEFT JOIN #TransidInRequest tr on tr.TransId = t.TransId
												WHERE t.IsMixParlay = 1
													AND NOT EXISTS( SELECT TOP 1 1 FROM TicketVoiding_RequestDetailTicket_SubParlay rdt WHERE t.SubTransid = rdt.transid AND rdt.RequestId = @RequestId)
												FOR XML PATH('')), 1, 1, '')
										, '')
			END
			ELSE IF @OldActionId = 2
			BEGIN
				--Mark ticket when add request
				SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
													FROM #TVSTicketBets tp   
													WHERE tp.IsMixParlay = 0 
													AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
													FOR XML PATH('')), 1,1,'')
												,'')

				IF @MarkTransIds <> ''
						SET @MarkTransIds = @MarkTransIds + ','

				SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
													FROM #TVSTicketBets tp   
													WHERE tp.IsMixParlay = 1 
													AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
													FOR XML PATH('')), 1,1,'')
												,'')
			END
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
										,'')
			IF @UnmarkTransIds <> ''
				SET @UnmarkTransIds = @UnmarkTransIds + ','
			
			SELECT @UnmarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rdt WITH(NOLOCK)
											  WHERE rdt.RequestId=@RequestId
											  FOR XML PATH('')
											), 1,1,'')
										,'')
		END

	END
	/*****************Return table **************************/
	-- 1. Validate table
	SELECT MatchId
		,IsInValidTotalTickets
		,IsExistedInOtherRequest
	FROM @Validation

	-- 2. TransId exists in other request table
	IF EXISTS (SELECT TOP (1) 1 FROM #TransidInRequest)
	BEGIN
		SELECT RequestId, MatchId,
			STUFF((
			SELECT ', ' + CAST(MainTransId AS VARCHAR(MAX)) 
			FROM #TransidInRequest
			WHERE (RequestId = r.RequestId AND MatchId = r.MatchId)
			ORDER BY TransId
			FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)')
			,1,2,'') AS TransIds
		FROM #TransidInRequest r
		GROUP BY r.RequestId, r.MatchId
	END
	ELSE
	BEGIN
		SELECT RequestId, MatchId, CAST(TransId AS VARCHAR(MAX)) AS TransIds
		FROM #TransidInRequest
	END

	-- 3. Loginfo table
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
					FROM #logInfo rd
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
	GROUP BY MatchId, w.scores

	-- 4. List ticket unmark/mark   (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
	      ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SELECT  t.matchid
		    ,t.transid
			,t.Subtransid
			,t.refno
			,b.custid 
			,b.bettype 
			,b.betid 
			,b.statusID 
			,b.Subcustid 
			,b.Subbettype
			,b.IsMixParlay 
			,b.SiteDBGroupID 
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO

