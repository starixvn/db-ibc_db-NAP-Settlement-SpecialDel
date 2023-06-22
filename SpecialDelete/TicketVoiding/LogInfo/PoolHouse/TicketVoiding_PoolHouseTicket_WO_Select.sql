/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_PoolHouseTicket_WO_Select]
(	
	@RequestId			  INT
	,@IssueTypeId		  INT
	,@ActionId			  INT
	,@TransInfoJson		  VARCHAR(MAX)
	,@WrongOddsInfo       VARCHAR(MAX) = NULL

)
AS
/*	
	Created by: 20230419@Max
	Task: [TVS] New issue type Wrong Odds [Redmine: #179934]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20230419@Max: Create new SP [Redmine:#179934]

	Param's explanation:


*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId          INT = 0
		,@SubIssueTypeId	  INT = NULL
		,@FilterFromTransTime DATETIME = NULL
		,@FilterToTransTime	  DATETIME = NULL
		,@IsLinkGroup1X2	  BIT = 0
		,@IsLinkGroupAIO	  BIT = 0
		,@LiveIndicator		  BIT = 0
		,@FilterOddsType	  VARCHAR(20) --"Range" or "Value"
 		,@FromOdds			  MONEY --"1.75" NULL IF FilterOddsType = 'Value' 
		,@ToOdds			  MONEY --"1.75" NULL IF FilterOddsType = 'Value' 
		,@OddsValue			  VARCHAR(20) --"1.75&1.5" NULL IF FilterOddsType = 'Range' 
		,@betteam			  VARCHAR(10)	-- "h" or "a"
		,@FilterFavoriteType  VARCHAR(10) -- "h" or "a"
		,@FavoriteValue		  VARCHAR(20) -- "1.25"
		,@FilterOUType		  VARCHAR(10) -- "h" or "a"
		,@OUValue			  VARCHAR(20) -- "1.25"
		,@WrongOddsInfoXML	  XML = NULL

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
		GroupName			  VARCHAR(50),
		FilterOdds			MONEY,
		Filterbettype        SMALLINT
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
      ,betfrom				NVARCHAR(4)
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
	  ,Subbetfrom			NVARCHAR(4)
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
	
	SET @WrongOddsInfoXML = CONVERT(XML, @WrongOddsInfo)
	SELECT @MatchId = t.c.value('@MatchId','INT')
			,@FilterFromTransTime = CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END 
			,@FilterToTransTime = CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END 
			,@SubIssueTypeId = t.c.value('@SubIssueTypeId','SMALLINT') 
			,@IsLinkGroup1X2 = t.c.value('@IsLinkGroup1X2','BIT') 
			,@IsLinkGroupAIO = t.c.value('@IsLinkGroupAIO','BIT') 
			,@LiveIndicator = t.c.value('@LiveIndicator','BIT') 
			,@FilterOddsType = t.c.value('@FilterOddsType', 'VARCHAR(20)') 
			,@FromOdds = t.c.value('@FromOdds', 'MONEY') 
			,@ToOdds = t.c.value('@ToOdds', 'MONEY') 
			,@OddsValue = t.c.value('@OddsValue', 'VARCHAR(20)') 
			,@betteam = t.c.value('@BetTeam', 'VARCHAR(10)') 
			,@FilterFavoriteType = t.c.value('@FilterFavoriteType', 'VARCHAR(10)') 
			,@FavoriteValue = t.c.value('@FavoriteValue', 'VARCHAR(20)') 
			,@FilterOUType = t.c.value('@FilterOuType', 'VARCHAR(10)') 
			,@OUValue = t.c.value('@OuValue', 'VARCHAR(20)') 
	FROM	@WrongOddsInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOddsInfoXML = NULL ))

	DECLARE @tmpFavoriteValue TABLE (FavoriteValue SMALLMONEY)
	DECLARE @tmpOUValue TABLE (OUValue SMALLMONEY)

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
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
		,wt ,refc
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
					  ,wt ,refc
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(4) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(4) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
					 ,wt TINYINT ,refc BIGINT
				)
		) tbl
	WHERE f.value <> ''

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
			,Filterbettype
			,FilterOdds
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
			,CASE WHEN @SubIssueTypeId IN (6,120) AND f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 THEN '1X2' 
				  WHEN @SubIssueTypeId IN (119,121) AND f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 THEN '1H 1X2'
			      WHEN f.GroupMatch <> 0 AND f.BetType IS NOT NULL AND @IsLinkGroupAIO = 1 THEN 'AIO'
				  ELSE 'Others' 
			 END AS GroupName
			,b.statusID
			,b.modds
			,b.ExtraInfo
			,b.winlostdate
			,b.bettype
			,b.odds
	FROM #tmpTransInfo b WITH (NOLOCK)
		OUTER APPLY(
					SELECT f.GroupMatch, f.BetType
					FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
					WHERE f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType AND f.SubIssueTypeId = @SubIssueTypeId
					)f
		OUTER APPLY (
				SELECT DISTINCT CONVERT(SMALLMONEY, value) AS FavoriteValue
				FROM STRING_SPLIT(@FavoriteValue, '&')
				WHERE value <> ''				
		)xHDP
		OUTER APPLY (
				SELECT DISTINCT CONVERT(SMALLMONEY, value) AS OUValue
				FROM STRING_SPLIT(@OUValue, '&')
				WHERE value <> ''				
		)xOU
	WHERE b.matchid = @MatchId AND b.betfrom <> 'P'  
		AND b.liveindicator = @LiveIndicator
		AND b.IsMixParlay = 0
		AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
		AND 1 = CASE WHEN @SubIssueTypeId IN (6) 
						AND b.bettype IN (1)
						AND b.betteam = @betteam
						AND ((@FilterFavoriteType = 'h' AND b.hdp1 = xHDP.FavoriteValue) OR (@FilterFavoriteType = 'a' AND b.hdp2 = xHDP.FavoriteValue))
					THEN 0
					WHEN @SubIssueTypeId IN (119) 
						AND b.bettype IN (7)
						AND b.betteam = @betteam
						AND ((@FilterFavoriteType = 'h' AND b.hdp1 = xHDP.FavoriteValue) OR (@FilterFavoriteType = 'a' AND b.hdp2 = xHDP.FavoriteValue))
					THEN 0
					WHEN @SubIssueTypeId IN (120)
						AND b.bettype IN (3)
						AND b.betteam = @FilterOUType
						AND b.hdp1 = xOU.OUValue
					THEN 0
					WHEN @SubIssueTypeId IN (121)
						AND b.bettype IN (8)
						AND b.betteam = @FilterOUType
						AND b.hdp1 = xOU.OUValue
					THEN 0
					ELSE 1 END
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsMixParlay = 1)
	BEGIN
		IF @FavoriteValue IS NOT NULL
		BEGIN
			INSERT INTO @tmpFavoriteValue(FavoriteValue)
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS FavoriteValue
			FROM STRING_SPLIT(@FavoriteValue, '&')
			WHERE value <> ''
		END
		IF @OUValue IS NOT NULL
		BEGIN
			INSERT INTO @tmpOUValue(OUValue)
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS OUValue
			FROM STRING_SPLIT(@OUValue, '&')
			WHERE value <> ''		
		END

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
					,Filterbettype
					,FilterOdds
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
					,CASE WHEN @SubIssueTypeId IN (6) AND b.Subbettype IN (1)
							AND b.Subbetteam = @betteam 
							AND ((@FilterFavoriteType = 'h' AND b.Subhdp1 IN (SELECT FavoriteValue FROM @tmpFavoriteValue)) 
								OR (@FilterFavoriteType = 'a' AND b.Subhdp2 IN (SELECT FavoriteValue FROM @tmpFavoriteValue)))
							THEN 'HDP'
						  WHEN @SubIssueTypeId IN (119) AND b.Subbettype IN (7)
							AND b.Subbetteam = @betteam 
							AND ((@FilterFavoriteType = 'h' AND b.Subhdp1 IN (SELECT FavoriteValue FROM @tmpFavoriteValue)) 
								OR (@FilterFavoriteType = 'a' AND b.Subhdp2 IN (SELECT FavoriteValue FROM @tmpFavoriteValue)))
							THEN 'HDP'
						  WHEN @SubIssueTypeId IN (120) AND b.Subbettype IN (3) 
							AND b.Subbetteam = @FilterOUType 
							AND b.Subhdp1 IN (SELECT OUValue FROM @tmpOUValue) THEN 'OU'
						  WHEN @SubIssueTypeId IN (121) AND b.Subbettype IN (8) 
							AND b.Subbetteam = @FilterOUType 
							AND b.Subhdp1 IN (SELECT OUValue FROM @tmpOUValue) THEN 'OU'
						  WHEN @SubIssueTypeId IN (6,120) AND f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 THEN '1X2' 
						  WHEN @SubIssueTypeId IN (119,121) AND f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 THEN '1H 1X2'
						  WHEN f.GroupMatch <> 0 AND f.BetType IS NOT NULL AND @IsLinkGroupAIO = 1 THEN 'AIO'
						  ELSE 'Others'
					 END AS GroupName
					,b.SubstatusID
					,b.ExtraInfo
					,b.winlostdate
					,b.Subbettype
					,b.Subodds
		  FROM #tmpTransInfo b
				OUTER APPLY(
					SELECT f.GroupMatch, f.BetType
					FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
					WHERE f.IssueTypeId = @IssueTypeId AND b.Subbettype = f.BetType AND f.SubIssueTypeId = @SubIssueTypeId
				)f
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					   WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
					   ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.Subliveindicator = @LiveIndicator
				AND b.IsMixParlay = 1
				AND b.Subtransdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
	END 

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsMixParlay = 1)
	BEGIN
		DECLARE @Odds_str NVARCHAR(100)
			, @tmp_ToOdds MONEY = 0
		DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)
		DECLARE @tmp_TransId AS TABLE (TransId BIGINT)

		IF @FilterOddsType = 'Range'
		BEGIN
			IF (@FromOdds < 0 AND @ToOdds > 0) OR (@FromOdds > 0 AND @ToOdds < 0)
			BEGIN
				--Range 1: negative
				SET @FromOdds = CASE WHEN @FromOdds < 0 THEN @FromOdds ELSE @ToOdds END
				SET @tmp_ToOdds = -1.00

				SET @Odds_str = (SELECT CAST(@FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
				INSERT INTO @tmp_Odds (Odds, OddsType)
				SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

				;WITH cte AS
				(
					SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
					FROM @tmp_Odds
					GROUP BY OddsType
				)
				INSERT INTO @tmp_TransId (TransId)
				SELECT b.transid FROM #TVSTicketBets b
					LEFT JOIN f_Set_OddsTypeBettypes() f ON f.BetType = b.Filterbettype
				WHERE EXISTS (SELECT TOP 1 1 FROM cte tp
					WHERE tp.OddsType = b.OddsType 
						AND 1 = CASE WHEN (b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds) 
											OR (b.IsMixParlay = 1 AND b.Subbettype NOT IN (1,3,7,8))
											OR (b.IsMixParlay = 0 AND b.GroupName = 'PH') THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NOT NULL AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL 
											AND b.OddsType = 1 
											AND b.FilterOdds BETWEEN (tp.FromOdds - 1) AND (tp.ToOdds - 1) THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL AND b.OddsType <> 1 AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds THEN 1
								ELSE 0 END
					)
					AND b.IsMixParlay = 1

				--Range 1: possitive
				DELETE @tmp_Odds
				SET @FromOdds =  CASE WHEN @ToOdds > 0 THEN @ToOdds ELSE @FromOdds END
				SET @tmp_ToOdds = 1.00

				SET @Odds_str = (SELECT CAST(@FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
				INSERT INTO @tmp_Odds (Odds, OddsType)
				SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

				;WITH cte AS
				(
					SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
					FROM @tmp_Odds
					GROUP BY OddsType
				)
				INSERT INTO @tmp_TransId (TransId)
				SELECT b.transid FROM #TVSTicketBets b
					LEFT JOIN f_Set_OddsTypeBettypes() f ON f.BetType = b.Filterbettype
				WHERE EXISTS (SELECT TOP 1 1 FROM cte tp
					WHERE tp.OddsType = b.OddsType 
						AND 1 = CASE WHEN (b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds) 
											OR (b.IsMixParlay = 1 AND b.Subbettype NOT IN (1,3,7,8))
											OR (b.IsMixParlay = 0 AND b.GroupName = 'PH') THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NOT NULL AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL 
											AND b.OddsType = 1 
											AND b.FilterOdds BETWEEN (tp.FromOdds - 1) AND (tp.ToOdds - 1) THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL AND b.OddsType <> 1 AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds THEN 1
								ELSE 0 END
						)	
					AND b.IsMixParlay = 1

				--Remove invalid transid
				UPDATE b SET b.GroupName = 'Others'
				FROM #TVSTicketBets b
					LEFT JOIN @tmp_TransId t ON t.TransId = b.transid
				WHERE b.IsMixParlay = 1 AND t.TransId IS NULL
			END
			ELSE
			BEGIN
				SET @Odds_str = (SELECT CAST(@FromOdds AS VARCHAR(10)) + ',' + CAST(@ToOdds AS VARCHAR(10)))
		
				INSERT INTO @tmp_Odds (Odds, OddsType)
				SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

				;WITH cte AS
				(
					SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
					FROM @tmp_Odds
					GROUP BY OddsType
				)
				DELETE b
				FROM #TVSTicketBets b
					LEFT JOIN f_Set_OddsTypeBettypes() f ON f.BetType = b.Filterbettype
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM cte tp
					WHERE tp.OddsType = b.OddsType 
						AND 1 = CASE WHEN (b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds) 
											OR (b.IsMixParlay = 1 AND b.Subbettype NOT IN (1,3,7,8))
											OR (b.IsMixParlay = 0 AND b.GroupName = 'PH') THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NOT NULL AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL 
											AND b.OddsType = 1 
											AND b.FilterOdds BETWEEN (tp.FromOdds - 1) AND (tp.ToOdds - 1) THEN 1
									WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL AND b.OddsType <> 1 AND b.FilterOdds BETWEEN tp.FromOdds AND ToOdds THEN 1
								ELSE 0 END
					)
				AND b.IsMixParlay = 1
			END
		END
		ELSE IF @FilterOddsType = 'Value'
		BEGIN
			SET @Odds_str = (SELECT REPLACE(@OddsValue, '&', ','))

			INSERT INTO @tmp_Odds (Odds, OddsType)
			SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

			UPDATE b SET b.GroupName = 'Others'
			FROM #TVSTicketBets b
				LEFT JOIN f_Set_OddsTypeBettypes() f ON f.BetType = b.Filterbettype
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM @tmp_Odds tp
				WHERE tp.OddsType = b.OddsType 
					AND 1 = CASE WHEN (b.IsMixParlay = 1 AND b.Subbettype IN (1,3,7,8) AND b.FilterOdds = tp.Odds)
										OR (b.IsMixParlay = 1 AND b.Subbettype NOT IN (1,3,7,8))
										OR (b.IsMixParlay = 0 AND b.GroupName = 'PH') THEN 1
								WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NOT NULL AND b.FilterOdds = tp.Odds THEN 1
								WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL AND b.OddsType = 1 AND b.FilterOdds = tp.Odds - 1 THEN 1
								WHEN b.IsMixParlay = 0 AND b.GroupName <> 'PH' AND f.BetType IS NULL AND b.OddsType <> 1 AND b.FilterOdds = tp.Odds THEN 1
							ELSE 0 END
				)
				AND b.IsMixParlay = 1
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
	END

	--Return all bettype tickets
	SELECT DISTINCT s.SubBetType AS Id
		, b.typenamee AS Name
		, CASE WHEN @SubIssueTypeId IN (6,120) AND s.GroupName IN ('1X2', 'OU', 'HDP') THEN '1X2' 
			   WHEN @SubIssueTypeId IN (119,121) AND s.GroupName IN ('1H 1X2', 'OU', 'HDP') THEN '1H 1X2' 
			   ELSE s.GroupName 
		  END AS GroupName
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
		   ,CASE WHEN s.IsMixParlay = 1 AND s.GroupName <> 'Others' THEN 'Parlay' ELSE s.GroupName END AS GroupName
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
				  WHEN s.IsMixParlay = 1 AND s.GroupName <> 'Others' THEN 3
				  ELSE 4 END
			, ISNULL(s.MainTransId, s.transid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #tmpTransInfo
	DROP TABLE #TransidInRequest

	SET NOCOUNT OFF
END