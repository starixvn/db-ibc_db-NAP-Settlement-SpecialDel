/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_HDP_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 4
	,@WrongHDPInfo		  VARCHAR(MAX) = NULL
	,@TransInfoJson0	  VARBINARY(MAX) = NULL
	,@TransInfoJson1	  VARBINARY(MAX) = NULL
	,@TransInfoJson2	  VARBINARY(MAX) = NULL
)
AS
/*	
	Created by: 20220510@Max
	Task: Refactor code issue type Wrong HDP & Wrong 1st HDP [Redmine: #172281]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220510@Max: Create new SP [Redmine: #172281]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]

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
	
	DECLARE @Decompress_TransInfoJson0 NVARCHAR(MAX) = NULL
		   ,@Decompress_TransInfoJson1 NVARCHAR(MAX) = NULL
		   ,@Decompress_TransInfoJson2 NVARCHAR(MAX) = NULL
		   ,@TransInfoJson			   VARBINARY(MAX) = NULL

	SET @Decompress_TransInfoJson0 = CAST(DECOMPRESS(@TransInfoJson0) AS NVARCHAR(MAX))
	SET @Decompress_TransInfoJson1 = CAST(DECOMPRESS(@TransInfoJson1) AS NVARCHAR(MAX))
	SET @Decompress_TransInfoJson2 = CAST(DECOMPRESS(@TransInfoJson2) AS NVARCHAR(MAX))

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
			SubStatusId			  TINYINT,
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
	  ,odds SMALLMONEY
	  ,oddsspread MONEY
      ,betfrom NVARCHAR(3)
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
	  ,Subodds SMALLMONEY
	  ,Suboddsspread MONEY
	  ,Subbetfrom NVARCHAR(3)
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
	  ,modds SMALLMONEY
	  ,statuswinlost TINYINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
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
           ,IsMixParlay 
	       ,SiteDBGroupID 
	)
	/*0:Central*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson0) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
	) tbl0
	UNION ALL /*1: Sitedb1*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson1) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
	) tbl1
	UNION ALL /*2: Sitedb2*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson2) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
	) tbl2

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
			,SubStatusId
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
			,b.SubstatusID
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
				,SubStatusId
				,SubIssueTypeId
			)
		SELECT  b.transid
				,b.Subtransid 
				,b.refno
				,b.custid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.matchid
				,b.statusID
				,b.SubstatusID
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
		SELECT @TransInfoJson AS TransInfoJson

		RETURN;
	END

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
		SELECT @TransInfoJson AS TransInfoJson

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

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

		IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

		SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
											FROM #TVSTicketBets tp   
											WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
											AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
											FOR XML PATH('')), 1,1,'')
										,'')

	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
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

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.transid
											WHERE tp.IsMixParlay = 0 AND tr.TransId IS NULL AND tp.StatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')

			IF @MarkTransIds <> ''
				SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50))
											FROM #TVSTicketBets tp
												LEFT JOIN #TransidInRequest tr on tr.TransId = tp.SubTransid
											WHERE tp.IsMixParlay = 1 AND tr.TransId IS NULL AND tp.SubStatusId IN (0,1)
											FOR XML PATH('')), 1, 1, '')
									, '')
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(tp.transid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 0 AND tp.StatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')

			IF @MarkTransIds <> ''
					SET @MarkTransIds = @MarkTransIds + ','

			SELECT @MarkTransIds += ISNULL(STUFF((SELECT ',' + CAST(tp.SubTransid AS VARCHAR(50)) 
												FROM #TVSTicketBets tp   
												WHERE tp.IsMixParlay = 1 AND tp.SubStatusId IN (0,1)
												AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.SubTransid)-- exist in # request
												FOR XML PATH('')), 1,1,'')
											,'')
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
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
	FOR JSON PATH))
	
	SELECT @TransInfoJson AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO

