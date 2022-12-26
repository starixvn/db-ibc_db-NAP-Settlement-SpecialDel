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
	,@LiveIndicator		  BIT = 0
	,@TransInfoJson0	  VARBINARY(MAX) = NULL
	,@TransInfoJson1	  VARBINARY(MAX) = NULL
	,@TransInfoJson2	  VARBINARY(MAX) = NULL
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

	DECLARE @Decompress_TransInfoJson0 NVARCHAR(MAX) = NULL
		   ,@Decompress_TransInfoJson1 NVARCHAR(MAX) = NULL
		   ,@Decompress_TransInfoJson2 NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson0 = CAST(DECOMPRESS(@TransInfoJson0) AS NVARCHAR(MAX))
	SET @Decompress_TransInfoJson1 = CAST(DECOMPRESS(@TransInfoJson1) AS NVARCHAR(MAX))
	SET @Decompress_TransInfoJson2 = CAST(DECOMPRESS(@TransInfoJson2) AS NVARCHAR(MAX))

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
	  ,WalletType			TINYINT
	  ,RefCode				BIGINT
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
		,WalletType 
	    ,RefCode 
	)
	/*0:Central*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
		  ,wt ,refc
	FROM OPENJSON(@Decompress_TransInfoJson0) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
		 ,wt TINYINT ,refc BIGINT
	) tbl0
	UNION ALL /*1: Sitedb1*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
		  ,wt ,refc
	FROM OPENJSON(@Decompress_TransInfoJson1) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
		 ,wt TINYINT ,refc BIGINT
	) tbl1
	UNION ALL /*2: Sitedb2*/
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
		  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
		  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
          ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
		  ,wt ,refc
	FROM OPENJSON(@Decompress_TransInfoJson2) 
	WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
	     ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(3) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
		 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
		 ,s_bfr NVARCHAR(3) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
		 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
		 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
		 ,wt TINYINT ,refc BIGINT
	) tbl2

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
		AND b.liveindicator = @LiveIndicator
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
				AND b.Subliveindicator = @LiveIndicator
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