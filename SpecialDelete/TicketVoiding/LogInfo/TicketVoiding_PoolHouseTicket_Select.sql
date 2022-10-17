/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_PoolHouseTicket_Select]
(	
	@MatchId              INT = 0
	,@RequestId			  INT = 0
	,@IssueTypeId		  INT = 4
	,@ActionId			  INT = 5
	,@IsShowPHOnly		  BIT = 0
	,@SubIssueTypeId	  INT = NULL
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime	  DATETIME = NULL
	,@HomeFavorite		  VARCHAR(50) = NULL
	,@AwayFavorite		  VARCHAR(50) = NULL
	,@HdpValue			  VARCHAR(50) = NULL
	,@IsLinkGroup1X2	  BIT = 0
	,@IsLinkGroupAIO	  BIT = 0
	,@TransInfo		      XML = NULL
)
AS
/*	
	Created by: 20220523@July
	Task: Affected Pool House Ticket popup  [Redmine: #172486]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220523@July: TVS - Wrong HDP affects to PH bet types [Redmine: #172486]

	Param's explanation:


*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TVSTicketBets (
        transid               BIGINT,
        SubTransid            BIGINT,
        refno                 BIGINT,
        custid                INT,
        odds                  SMALLMONEY,
        SubOdds               SMALLMONEY,
        oddsspread            MONEY,
        OddsType              INT,
        transdate             DATETIME,
        bettype               SMALLINT,
        SubBetType			  SMALLINT,
		betteam               NVARCHAR(10),
        SubBetTeam            NVARCHAR(10),
        betcheck              NVARCHAR(50),
        SubBetcheck           NVARCHAR(50),
        Subhdp1               SMALLMONEY,
        Subhdp2               SMALLMONEY,
        hdp1                  SMALLMONEY,
        hdp2                  SMALLMONEY,
        livehomescore         SMALLINT,
        liveawayscore         SMALLINT,
        creator               INT,
        creatorName           VARCHAR(30),
        Stake                 MONEY,
        currencyname          VARCHAR(20),
        STATUS                NVARCHAR(10),
        SubStatus             NVARCHAR(10),
        betid                 BIGINT DEFAULT(0),
        Transdesc             NVARCHAR(1000),
        betdaqid              BIGINT,
        IsMixParlay           BIT DEFAULT(0),
        modds                 SMALLMONEY,
        ExtraInfo             VARCHAR(1000),
		IsCashOut			  BIT DEFAULT(0), 
        matchid               INT,
        WalletType            TINYINT,
        RefCode               BIGINT,
        BonusID               INT,
        MainTransId           BIGINT,
        WinLost               MONEY,
        LiveIndicator		  BIT,
		ActualStake			  MONEY,
		oddsid                INT,
		statusID			  TINYINT,
		winlostdate			  DATETIME,
		GroupName			  VARCHAR(50)
	)
	CREATE TABLE #TransidInRequest (TransId BIGINT)
	CREATE TABLE #tmpTransInfo(
	   matchid				INT
	  ,transid				BIGINT 
	  ,Subtransid			BIGINT
	  ,refno				BIGINT
	  ,custid				INT	
      ,hdp1					SMALLMONEY
      ,hdp2					SMALLMONEY
      ,livehomescore		SMALLINT
      ,liveawayscore		SMALLINT
      ,liveindicator		BIT
	  ,odds					SMALLMONEY
	  ,oddsspread			MONEY
      ,betfrom				NVARCHAR(3)
      ,bettype				SMALLINT
      ,betteam				NVARCHAR(10)
	  ,betcheck				NVARCHAR(50)
	  ,Status				NVARCHAR(10)
      ,transdate			DATETIME
	  ,checktime			DATETIME
	  ,betid				BIGINT
	  ,Transdesc			NVARCHAR(1000)
	  ,statusID				TINYINT
	  ,Subcustid			INT
	  ,Subhdp1				SMALLMONEY
      ,Subhdp2				SMALLMONEY
	  ,Sublivehomescore		SMALLINT
      ,Subliveawayscore		SMALLINT
	  ,Subliveindicator		BIT
	  ,Subodds				SMALLMONEY
	  ,Suboddsspread		MONEY
	  ,Subbetfrom			NVARCHAR(3)
	  ,Subbettype			SMALLINT
	  ,Subbetteam			NVARCHAR(10)
	  ,Subbetcheck			NVARCHAR(50)
	  ,SubStatus			NVARCHAR(10)
	  ,Subtransdate			DATETIME
	  ,Subchecktime			DATETIME
	  ,SubTransdesc			NVARCHAR(1000)
	  ,SubstatusID			TINYINT
	  ,srecommend			INT
	  ,mrecommend			INT
	  ,recommend			INT
      ,creator				INT
	  ,WalletType			TINYINT
	  ,RefCode				BIGINT
	  ,stake				MONEY
	  ,oddstype				TINYINT
	  ,CurrencyName			NVARCHAR(50)
	  ,betdaqid				BIGINT
	  ,ExtraInfo			VARCHAR(1000)
	  ,BonusID				INT
	  ,winlost				MONEY
	  ,actual_stake			MONEY
	  ,winlostdate			SMALLDATETIME
	  ,modds				SMALLMONEY
	  ,statuswinlost		TINYINT
      ,IsMixParlay			BIT
	  ,SiteDBGroupID		SMALLINT
	)

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
        ,IsMixParlay 
	    ,SiteDBGroupID 
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
		,t.c.value('@o','SMALLMONEY') AS odds
		,t.c.value('@os','MONEY') AS oddsspread
		,t.c.value('@bfr','NVARCHAR(3)') AS betfrom
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
		,t.c.value('@s_o','SMALLMONEY') AS Subodds
		,t.c.value('@s_os','MONEY') AS Suboddsspread
		,t.c.value('@s_bfr','NVARCHAR(3)') AS Subbetfrom
		,t.c.value('@s_btype','SMALLINT') AS Subbettype
		,t.c.value('@s_bteam','NVARCHAR(10)') AS Subbetteam
		,t.c.value('@s_bcheck','NVARCHAR(50)') AS Subbetcheck
		,t.c.value('@s_s','NVARCHAR(10)') AS SubStatus
		,t.c.value('@s_tdate','DATETIME') AS Subtransdate
		,CASE WHEN t.c.value('@s_checkt','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@s_checkt','DATETIME') END AS Subchecktime
		,t.c.value('@s_tdes','NVARCHAR(1000)') AS SubTransdesc
		,t.c.value('@s_sid', 'TINYINT') AS SubstatusID
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
		,CASE WHEN t.c.value('@wld','SMALLDATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@wld','SMALLDATETIME') END AS winlostdate
		,t.c.value('@m', 'SMALLMONEY') AS modds
		,t.c.value('@statuswl', 'TINYINT') AS statuswinlost
		,t.c.value('@isP','BIT') AS IsMixParlay
		,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)	
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	INSERT INTO #TVSTicketBets(
			transid		
			,SubTransid		
			,refno			
			,custid			
			,odds			
			,SubOdds	
			,oddsspread			
			,OddsType		
			,transdate		
			,bettype 		
			,SubBetType
			,betteam 		
			,SubBetTeam
			,betcheck	
			,SubBetcheck	
			,hdp1 			
			,hdp2 			
			,livehomescore 	
			,liveawayscore 	
			,creator		
			,Stake			
			,currencyname		
			,STATUS			
			,SubStatus	
			,betid			
			,Transdesc		
			,betdaqid	
			,IsCashOut
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,WinLost
			,LiveIndicator
			,ActualStake
			,matchid
			,GroupName
			,statusID
			,modds
			,ExtraInfo
			,winlostdate
		)
	SELECT DISTINCT
			 b.transid
			,b.transid AS SubTransID
			,b.refno
			,b.custid
			,b.odds
			,b.odds AS SubOdds
			,b.oddsspread			
			,b.OddsType
			,b.transdate
			,b.bettype
			,b.bettype AS SubBettype
			,b.betteam
			,b.betteam AS SubBetteam
			,b.betcheck
			,b.betcheck AS SubBetcheck
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.creator
			,b.stake
			,b.CurrencyName
			,b.Status
			,b.SubStatus
			,b.betid
			,b.Transdesc
			,b.betdaqid
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,b.transid AS MainTransId
			,b.WinLost - b.actual_stake AS WinLost
			,b.liveindicator
			,b.actual_stake AS ActualStake
			,b.matchid
			,CASE WHEN @IssueTypeId IN (4) AND f.GroupMatch = 0 THEN '1X2' 
				  WHEN @IssueTypeId IN (5) AND f.GroupMatch = 0 THEN '1H 1X2'
			      ELSE 'AIO' END AS GroupName
			,b.statusID
			,b.modds
			,b.ExtraInfo
			,b.winlostdate
	FROM #tmpTransInfo b WITH (NOLOCK)
		CROSS APPLY(
					SELECT f.GroupMatch
					FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
					WHERE f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType
						AND 1 = CASE WHEN @IsLinkGroup1X2 = 1 AND f.GroupMatch = 0 THEN 1
									 WHEN @IsLinkGroupAIO = 1 AND f.GroupMatch <> 0 THEN 1 ELSE 0 END
					)f
	WHERE b.matchid = @MatchId AND b.betfrom <> 'P'  
		AND b.IsMixParlay = 0
		AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo  WHERE IsMixParlay = 1)
	BEGIN		
		INSERT INTO #TVSTicketBets(
					transid		
					,SubTransid		
					,refno			
					,custid					
					,odds			
					,SubOdds	
					,oddsspread
					,OddsType		
					,transdate		
					,bettype		
					,SubBetType
					,betteam		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,Subhdp1
					,Subhdp2
					,hdp1 			
					,hdp2 			
					,livehomescore	
					,liveawayscore	
					,creator		
					,Stake			
					,currencyname						
					,STATUS			
					,SubStatus	
					,Transdesc		
					,IsMixParlay
					,modds
					,MainTransId
					,WinLost
					,LiveIndicator
					,ActualStake
					,matchid
					,GroupName
					,statusID
					,ExtraInfo
					,winlostdate
			)
			SELECT DISTINCT
					b.transid 
					,b.Subtransid
					,b.refno
					,b.Subcustid				
					,b.odds
					,b.SubOdds
					,b.Suboddsspread
					,b.OddsType
					,b.Subtransdate
					,b.bettype
					,b.SubBettype
					,b.betteam
					,b.SubBetteam
					,b.betcheck				
					,b.SubBetcheck
					,b.Subhdp1
					,b.Subhdp2
					,b.hdp1
					,b.hdp2
					,b.Sublivehomescore
					,b.Subliveawayscore
					,b.creator
					,b.stake
					,b.currencyname				
					,b.STATUS
					,b.SubStatus
					,b.SubTransdesc
					,1 AS IsMixParlay
					,b.modds
					,b.transid AS MainTransId
					,b.winlost - b.actual_stake AS WinLost
					,b.Subliveindicator
					,b.actual_stake AS ActualStake
					,@MatchId
					,CASE WHEN (@IssueTypeId = 4 AND b.Subbettype = 1) OR (@IssueTypeId = 5 AND b.Subbettype = 7) THEN 'HDP'
						  WHEN @IssueTypeId IN (4) AND f.GroupMatch = 0 THEN '1X2' 
						  WHEN @IssueTypeId IN (5) AND f.GroupMatch = 0 THEN '1H 1X2'
						  ELSE 'AIO'	 
					 END AS GroupName
					,b.SubstatusID
					,b.ExtraInfo
					,b.winlostdate
		  FROM #tmpTransInfo b
				OUTER APPLY (
					SELECT DISTINCT value AS HomeFavorite
					FROM STRING_SPLIT(@HomeFavorite, '&')
					WHERE value <> ''				
				)xHDPHome
				OUTER APPLY (
					SELECT DISTINCT value AS AwayFavorite
					FROM STRING_SPLIT(@AwayFavorite, '&')
					WHERE value <> ''				
				)xHDPAway
				OUTER APPLY (
					SELECT DISTINCT value AS HdpValue
					FROM STRING_SPLIT(@HdpValue, '&')
					WHERE value <> ''				
				)xHDPvalue
				LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.Subbettype = f.BetType
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.IsMixParlay = 1
				AND b.Subtransdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
				AND 1 = CASE WHEN ((@IssueTypeId = 4 AND b.Subbettype = 1) OR (@IssueTypeId = 5 AND b.Subbettype = 7)) AND @SubIssueTypeId IN (8,9) AND b.Subhdp1 = xHDPHome.HomeFavorite AND @HomeFavorite IS NOT NULL THEN 1
							 WHEN ((@IssueTypeId = 4 AND b.Subbettype = 1) OR (@IssueTypeId = 5 AND b.Subbettype = 7)) AND @SubIssueTypeId IN (8,9) AND b.Subhdp2 = xHDPAway.AwayFavorite AND @AwayFavorite IS NOT NULL THEN 1
							 WHEN ((@IssueTypeId = 4 AND b.Subbettype = 1) OR (@IssueTypeId = 5 AND b.Subbettype = 7)) AND @SubIssueTypeId IN (22,24) AND b.Subhdp2 = xHDPvalue.HdpValue AND @HdpValue IS NOT NULL THEN 1 --Away Virtual Head Reversed
							 WHEN ((@IssueTypeId = 4 AND b.Subbettype = 1) OR (@IssueTypeId = 5 AND b.Subbettype = 7)) AND @SubIssueTypeId IN (23,25) AND b.Subhdp1 = xHDPvalue.HdpValue AND @HdpValue IS NOT NULL THEN 1 --Home Virtual Head Reversed
							 WHEN f.BetType IS NOT NULL AND f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 THEN 1 --1X2
							 WHEN f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND @IsLinkGroupAIO = 1 THEN 1 --AIO
							 ELSE 0 END
	END  

	IF @ActionId NOT IN (2)
	BEGIN
		INSERT INTO #TransidInRequest (TransId)
		SELECT DISTINCT tmp.transid
		FROM #TVSTicketBets t
			CROSS APPLY (
						SELECT rs.TransId, rs.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
						WHERE rs.TransId = t.transid AND rs.MatchId = t.MatchId
						UNION ALL
						SELECT rp.MainTransId AS TransId, rp.RequestId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay rp WITH (NOLOCK)
						WHERE rp.TransId = t.SubTransid AND rp.MatchId = t.matchid
				)tmp
			INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = tmp.RequestId
		WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2) AND t.matchid = @MatchId

		DELETE FROM #TVSTicketBets 
		WHERE transid IN ( SELECT transid FROM #TransidInRequest) 

	END

	IF @IsShowPHOnly = 1 AND @RequestId <> 0
	BEGIN
		DELETE b
		FROM #TVSTicketBets b
		OUTER APPLY (
					SELECT TOP (1) transid
					FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
					WHERE transid = b.transid AND matchid = b.matchid AND RequestId = @RequestId
					) ts
		WHERE b.transid = b.SubTransid AND ts.TransId IS NULL

		DELETE sub
		FROM #TVSTicketBets sub
		OUTER APPLY (
					SELECT TOP (1) transid
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
					WHERE transid = sub.SubTransid AND matchid = sub.matchid AND RequestId = @RequestId
				) ts
		WHERE sub.IsMixParlay = 1 AND ts.transid IS NULL

	END

	--Return all bettype tickets
	SELECT DISTINCT s.SubBetType AS Id
		, b.typenamee AS Name
		, CASE WHEN @IssueTypeId IN (4) AND s.GroupName IN ('1X2', 'HDP') THEN '1X2' 
			   WHEN @IssueTypeId IN (5) AND s.GroupName IN ('1H 1X2', 'HDP') THEN '1H 1X2' 
		  ELSE 'AIO' END GroupName
	FROM #TVSTicketBets s
		INNER JOIN dbo.bettype b WITH(NOLOCK) ON s.SubBetType = b.typeid 

	--Return all PH tickets
	SELECT s.transid
		   ,s.MainTransId
		   ,s.BonusId
		   ,s.SubTransid
		   ,s.refno		
		   ,s.custid		
		   ,ci.username	
		   ,s.transdate
		   ,s.creator
		   ,s.Stake
		   ,s.odds
		   ,s.SubOdds
		   ,s.oddsspread
		   ,s.OddsType
		   ,s.bettype
		   ,s.SubBettype
		   ,s.STATUS
		   ,s.SubStatus
		   ,s.currencyname
		   ,s.betteam
		   ,s.SubBetTeam
		   ,s.Subhdp1
		   ,s.Subhdp2
		   ,s.hdp1
		   ,s.hdp2
		   ,s.livehomescore
		   ,s.liveawayscore
		   ,s.betid
		   ,s.betcheck
		   ,s.SubBetcheck
		   ,s.IsMixParlay
		   ,s.Transdesc
		   ,s.betdaqid
		   ,s.WalletType
		   ,s.RefCode
		   ,s.IsCashOut
		   ,cr.username AS creatorName
		   ,s.winlost
		   ,s.LiveIndicator AS IsLiveIndicator
		   ,s.ActualStake
		   ,s.statusID
		   ,s.ExtraInfo
		   ,s.winlostdate
		   ,CASE WHEN s.IsMixParlay = 1 THEN 'Parlay' ELSE s.GroupName END AS GroupName
		   ,s.matchid
		   ,m.homeid
		   ,m.awayid
		   ,m.leagueid
		   ,m.IsNeutral
		   ,m.matchcode
		   ,m.SettlementStatus
		   ,m.sporttype
	FROM #TVSTicketBets s
		INNER JOIN dbo.match m WITH(NOLOCK) ON s.matchid = m.matchid
		INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	ORDER BY CASE WHEN s.GroupName IN ('1X2', '1H 1X2') AND s.transid = s.SubTransid THEN 1
				  WHEN s.GroupName = 'AIO' AND s.transid = s.SubTransid THEN 2
				  WHEN s.IsMixParlay = 1 THEN 3 END
			, ISNULL(s.MainTransId, s.transid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #tmpTransInfo
	DROP TABLE #TransidInRequest

	SET NOCOUNT OFF
END