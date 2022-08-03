/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LogInfo_KO_Select]
(	
	 @RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@KickOffInfo		  VARCHAR(MAX) = NULL
	,@TransInfo		      XML = NULL
)
AS
/*	
	Created by: July
	Date 20220720
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220720@July: Create new SP - Refactor code issue type EKO & WKO [Redmine: #175412]

	Param's explanation:
	+ @KickOffInfo: 
			<root><r MatchId="0" KickOffTime=""/></root>
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE  @IsExistedInOtherRequest BIT = 0
			,@KickOffInfoXML	   XML = NULL	
			,@MatchId			   INT
			,@KickOffTime		   DATETIME = NULL

	SET @KickOffInfoXML = CONVERT(XML, @KickOffInfo)
	SELECT @MatchId = t.c.value('@MatchId','INT') 
		  ,@KickOffTime = t.c.value('@KickOffTime','DATETIME')
	FROM @KickOffInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@KickOffInfoXML = NULL))

	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			MainTransId           BIGINT,
			LiveIndicator		  BIT DEFAULT(0),
			StatusId			  TINYINT,
			SiteDBGroupID		  SMALLINT,
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode		BIGINT,
			custid		INT,
			bettype		SMALLINT,
			transid		BIGINT,
			MatchId		INT
	)

	CREATE INDEX IX_TVSTicketBets_RefCode ON #TVSTicketBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary(RefCode)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT PRIMARY KEY
      ,Maintransid BIGINT
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
	  ,WalletType TINYINT
	  ,RefCode BIGINT
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
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)

	INSERT INTO #tmpTransInfo( 
		    matchid 
	       ,transid 
           ,Maintransid
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
	       ,WalletType 
	       ,RefCode 
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
		,t.c.value('@m_t','BIGINT') AS Maintransid
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
		,t.c.value('@checkt','DATETIME') AS checktime
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
		,t.c.value('@s_checkt','DATETIME') AS Subchecktime
		,t.c.value('@s_tdes','NVARCHAR(1000)') AS SubTransdesc
		,t.c.value('@s_sid', 'MONEY') AS SubstatusID
		,t.c.value('@sre','INT') AS srecommend
		,t.c.value('@mre','INT') AS mrecommend
		,t.c.value('@re','INT') AS recommend
		,t.c.value('@cr','INT') AS creator
		,t.c.value('@wt','TINYINT') AS WalletType
		,t.c.value('@refc','BIGINT') AS RefCode
		,t.c.value('@stake','MONEY') AS stake
		,t.c.value('@ost','TINYINT') AS oddstype
		,t.c.value('@curr','NVARCHAR(50)') AS CurrencyName
		,t.c.value('@bdaq','BIGINT') AS betdaqid
		,t.c.value('@ex','VARCHAR(1000)') AS ExtraInfo
		,t.c.value('@bo','INT') AS BonusID
		,t.c.value('@w','MONEY') AS winlost
		,t.c.value('@acstake','MONEY') AS actual_stake
		,t.c.value('@wld', 'SMALLDATETIME') AS winlostdate
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

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid					
			,transdate		
			,bettype 				
			,livehomescore 	
			,liveawayscore 		
			,WalletType
			,RefCode
			,LiveIndicator
			,matchid
			,StatusId
			,SiteDBGroupID
		)
	SELECT   b.transid
			,b.Subtransid
			,b.refno
			,b.custid
			,b.transdate
			,b.bettype
			,b.livehomescore
			,b.liveawayscore
			,b.WalletType
			,b.RefCode
			,b.liveindicator
			,@MatchId
			,b.statusID
			,b.SiteDBGroupID
	FROM #tmpTransInfo b
	WHERE	b.matchid = @MatchId AND b.IsMixParlay = 0
			AND b.transdate >= @KickOffTime
			AND 1= CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
			AND b.liveindicator = 0
			AND b.betfrom <> 'P'	
						
	---get sub ticket of a mix parlay	
	IF EXISTS (
			SELECT TOP 1 1
			FROM #tmpTransInfo bm 
			WHERE bm.matchid = @matchid
				AND bm.Subtransdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND bm.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND bm.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND bm.Subliveindicator = 0
				AND bm.Subbetfrom <> 'P'
			)
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
				,LiveIndicator
				,matchid
				,StatusId
				,SiteDBGroupID
			)
		SELECT   b.transid
				,b.Subtransid
				,b.refno
				,b.Subcustid				
				,b.Subtransdate
				,b.bettype
				,b.Sublivehomescore
				,b.Subliveawayscore
				,b.IsMixParlay
				,b.Subliveindicator
				,@MatchId
				,b.statusID
				,SiteDBGroupID
		FROM #tmpTransInfo b	
		WHERE	b.matchid = @matchid AND b.IsMixParlay = 1 
		        AND b.Subtransdate >= @KickOffTime
				AND 1= CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1
							WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
							ELSE 0 END
				AND b.liveindicator = 0 AND b.Subliveindicator = 0
				AND b.Subbetfrom <> 'P'
				AND b.transdate >= @KickOffTime
				AND b.statusID NOT IN (101, 102, 103)
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
		  
		INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, transid, MatchId)
		SELECT RefCode, custid, bettype
				, MAX(transid) AS transid
				, matchid
		FROM #TVSTicketBets
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, bettype, matchid
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
						,WalletType
						,RefCode
						,MainTransId
						,LiveIndicator
						,matchid
						,StatusId
					)
				SELECT   b.transid
						,b.SubTransID
						,b.refno
						,b.custid
						,b.transdate
						,b.bettype
						,b.livehomescore
						,b.liveawayscore
						,b.WalletType
						,b.RefCode
						,t.transid AS MainTransId
						,b.liveindicator
						,b.matchid
						,b.statusID
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
		SELECT tmp.transid, r.RequestId, tmp.MainTransId, @MatchId
		FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
			CROSS APPLY (
						SELECT rs.TransId, rs.TransId AS MainTransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.RequestId = r.RequestId AND rs.MatchId = @MatchId
						UNION ALL
						SELECT rp.TransId, rp.MainTransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.RequestId = r.RequestId AND rp.MatchId = @MatchId
				)tmp
			INNER JOIN #TVSTicketBets t ON tmp.TransId = t.transid
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

		IF @@ROWCOUNT <> 0
		BEGIN
			SELECT @IsExistedInOtherRequest = 1
		END
	END

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		SELECT  @IsExistedInOtherRequest AS IsExistedInOtherRequest

		--TransId in request table
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

		RETURN;
	END
	
	--Error Table
	SELECT @IsExistedInOtherRequest AS IsExistedInOtherRequest

	--TransId in request table
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

	SET @TransInfo = (
	SELECT DISTINCT 
			t.matchid AS "@mid"
		    ,t.transid AS "@t"
			,t.Subtransid AS "@s_t"
			,b.Maintransid AS "@m_t"
			,t.refno AS "@ref"
			,b.custid AS "@c"
			,b.hdp1 AS "@hdp1"
		    ,b.hdp2 AS "@hdp2"
		    ,b.livehomescore AS "@lh" 
		    ,b.liveawayscore AS "@la"  
		    ,b.liveindicator AS "@li"  
			,b.odds AS "@o" 
		    ,b.oddsspread AS "@os" 
		    ,b.betfrom AS "@bfr" 
		    ,b.betteam AS "@bteam" 
			,b.bettype AS "@btype"
		    ,b.betcheck AS "@bcheck" 
		    ,b.Status AS "@s" 
			,b.transdate AS "@tdate"
			,b.betid AS "@bid"
		    ,b.Transdesc AS "@tdesc" 
		    ,b.statusID AS "@sid" 
		    ,b.Subcustid AS "@s_c"  
		    ,b.Subhdp1 AS "@s_hdp1" 
		    ,b.Subhdp2 AS "@s_hdp2" 
			,b.Sublivehomescore AS "@s_lh"   
		    ,b.Subliveawayscore AS "@s_la"   
		    ,b.Subliveindicator AS "@s_li" 
		    ,b.Subodds AS "@s_o"  
		    ,b.Suboddsspread AS "@s_os" 
		    ,b.Subbetfrom AS "@s_bfr" 
		    ,b.Subbetteam AS "@s_bteam" 
		    ,b.Subbettype AS "@s_btype" 
		    ,b.Subbetcheck AS "@s_bcheck" 
		    ,b.SubStatus AS "@s_s" 
		    ,b.Subtransdate AS "@s_tdate"
		    ,b.SubTransdesc AS "@s_tdes"
			,b.SubstatusID AS "@s_sid" 
		    ,b.srecommend AS "@sre" 
		    ,b.mrecommend AS "@mre" 
		    ,b.recommend AS "@re" 
		    ,b.creator AS "@cr" 
		    ,b.WalletType AS "@wt"  
		    ,b.RefCode AS "@refc" 
		    ,b.stake AS "@s" 
		    ,b.oddstype AS "@ost"  
		    ,b.CurrencyName AS "@curr"  
		    ,b.betdaqid AS "@bdaq"  
		    ,b.ExtraInfo AS "@ex"  
		    ,b.BonusID AS "@bo"  
		    ,b.winlost AS "@w" 	
		    ,b.actual_stake AS "@acstake" 
			,b.modds AS "@m"  
			,b.IsMixParlay AS "@isP"
			,b.SiteDBGroupID AS "@sitedb"
		FROM #TVSTicketBets t
			INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
		WHERE NOT EXISTS (SELECT 1 FROM #TransidInRequest r WHERE r.TransId = t.SubTransid)
		FOR XML PATH('r'), ROOT('root')
		)

	SELECT @TransInfo AS TransInfo

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #tmpTransInfo

END
GO

