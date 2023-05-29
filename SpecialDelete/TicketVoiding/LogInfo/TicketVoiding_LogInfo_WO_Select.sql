/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_LogInfo_WO_Select]
(	
	@RequestId			  INT = 0
	,@ActionId			  INT = 5
	,@IsShowLogOnly		  BIT = 0
	,@IssueTypeId		  INT = 2
	,@WrongOddsInfo		  VARCHAR(MAX) = NULL
	,@TransInfoJson		  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: 20230419@Max
	Task: [TVS] New issue type Wrong Odds [Redmine: #179934]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20230419@Max: Create new SP [Redmine:#179934]
		
	Param's explanation:
		+ @WrongOddsInfo:
			<root><r MatchId="0" FilterFromTransTime="1" FilterToTransTime ="" SubIssueTypeId="" PoolHouseCheckedBetTypes ="1,2,3,4" IsMainMatch="true" IsLinkGroup1X2 ="" IsLinkGroupAIO = "" LiveIndicator =""/></root>
			(*) PoolHouseCheckedBetTypes   : ALL - (all bettype của ticket)
											 '1,2,3' - (bettype selected)
											 -1 - (no bettype affected)
											 '' - (uncheck all bettype PH)
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @SingleCount			  INT = 0
			,@MainParlayCount		  INT = 0
	        ,@WrongOddsInfoXML		  XML = NULL
			,@MarkTransIds		      VARCHAR(MAX) =''
			,@UnmarkTransIds		  VARCHAR(MAX) = ''
			,@OldActionId			  TINYINT
			,@TransInfoJson_Output	  VARBINARY(MAX) = NULL
			,@PHBettypes			  VARCHAR(MAX) =''
			,@MainMatchId			  INT
			,@PoolHouseCheckedBetTypes VARCHAR(MAX) = ''

	CREATE TABLE #TVSTicketBets (
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			Subbettype			  SMALLINT,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			betdaqid              BIGINT,
			IsMixParlay           BIT DEFAULT(0),
			matchid               INT,
			StatusId			  TINYINT,
			SubStatusId			  TINYINT,
			SubIssueTypeId		  SMALLINT,
			GroupName			  VARCHAR(50),
			OddsType			INT,
			FilterOdds			MONEY,
			Filterbettype        SMALLINT
	)

	CREATE TABLE #logInfo (
		 MatchId						INT
		,LiveScores						NVARCHAR(300)
		,VoidFromTime					DATETIME
		,VoidToTime						DATETIME
		,LiveGameEarlySingleCount		INT
		,LiveGameEarlyCashOutCount		INT
		,LiveGameEarlySettleCount		INT
		,LiveGameEarlyInstantlySettleCount	INT
		,PoolHouseSingleCount			INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount 			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
	)

	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	CREATE TABLE #FilterInfo (
		 MatchId				INT
		,FilterFromTransTime	DATETIME
		,FilterToTransTime		DATETIME
		,SubIssueTypeId			SMALLINT
		,PoolHouseCheckedBetTypes VARCHAR(MAX)
		,IsMainMatch			VARCHAR(10)
		,IsLinkGroup1X2			BIT DEFAULT(0)
		,IsLinkGroupAIO			BIT DEFAULT(0)
		,LiveIndicator			BIT DEFAULT(0)		
		,FilterOddsType			VARCHAR(20) --"Range" or "Value"
 		,FromOdds				MONEY --"1.75" NULL IF FilterOddsType = 'Value' 
		,ToOdds					MONEY --"1.75" NULL IF FilterOddsType = 'Value' 
		,OddsValue				VARCHAR(20) --"1.75&1.5" NULL IF FilterOddsType = 'Range' 
		,betteam				VARCHAR(10)	-- "h" or "a"
		,FilterFavoriteType		VARCHAR(10) -- "h" or "a"
		,FavoriteValue			VARCHAR(20) -- "1.25"
		,FilterOUType			VARCHAR(10) -- "h" or "a"
		,OUValue				VARCHAR(20) -- "1.25"
		,CorrectOdds			MONEY --"1.75"
	)
	CREATE TABLE #logInfoVoidPage (
		RequestId						INT
		,MatchId						INT
		,PoolHouseSingleCount			INT
		,LiveGameEarlyCashOutCount		INT
		,LiveGameEarlySettleCount		INT
		,LiveGameEarlyInstantlySettleCount	INT
		,PoolHouseCashOutCount			INT
		,PoolHouseSettleCount			INT
		,PoolHouseInstantlySettleCount	INT
		,PoolHouseMainParlayCount 		INT
	)

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
      ,betfrom NVARCHAR(4)
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
	  ,Subbetfrom NVARCHAR(4)
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

	DECLARE @tblScoreMessage AS TABLE (MatchId INT, ScoreNormalTicket VARCHAR(100), ScoreOfMatch VARCHAR(100))
	DECLARE @Validation AS TABLE (
			 IsInValidTotalTickets   BIT DEFAULT(0) 
			,IsExistedInOtherRequest BIT DEFAULT(0) 
			,MatchId                 INT
			,IsPoolHouseAffected	 BIT DEFAULT(0)
		)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)

	SET @WrongOddsInfoXML = CONVERT(XML, @WrongOddsInfo)
	INSERT INTO #FilterInfo(
			MatchId
			,FilterFromTransTime
			,FilterToTransTime
			,SubIssueTypeId
			,PoolHouseCheckedBetTypes
			,IsMainMatch
			,IsLinkGroup1X2
			,IsLinkGroupAIO
			,LiveIndicator
			,FilterOddsType
			,FromOdds
			,ToOdds
			,OddsValue
			,betteam
			,FilterFavoriteType
			,FavoriteValue
			,FilterOUType
			,OUValue
		)
	SELECT t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,t.c.value('@PoolHouseCheckedBetTypes','VARCHAR(MAX)') AS PoolHouseCheckedBetTypes
			,'true' AS IsMainMatch
			,t.c.value('@IsLinkGroup1X2','BIT') AS IsLinkGroup1X2
			,t.c.value('@IsLinkGroupAIO','BIT') AS IsLinkGroupAIO
			,t.c.value('@LiveIndicator','BIT') AS LiveIndicator
			,t.c.value('@FilterOddsType', 'VARCHAR(20)') AS FilterOddsType
			,t.c.value('@FromOdds', 'MONEY') AS FromOdds
			,t.c.value('@ToOdds', 'MONEY') AS ToOdds
			,t.c.value('@OddsValue', 'VARCHAR(20)') AS OddsValue
			,t.c.value('@BetTeam', 'VARCHAR(10)') AS betteam
			,t.c.value('@FilterFavoriteType', 'VARCHAR(10)') AS FilterFavoriteType
			,t.c.value('@FavoriteValue', 'VARCHAR(20)') AS FavoriteValue
			,t.c.value('@FilterOuType', 'VARCHAR(10)') AS FilterOUType
			,t.c.value('@OuValue', 'VARCHAR(20)') AS OUValue
	FROM	@WrongOddsInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOddsInfoXML = NULL ))

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
	SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
		,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,checkt ,bid
		,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
		,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,s_checkt ,s_tdes ,s_sid ,sre
		,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
		,acstake ,wld ,m ,statuswl ,isP ,sitedb
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
				SELECT mid ,t ,s_t ,ref ,c ,hdp1 ,hdp2 ,lh ,la ,li
					  ,o ,os ,bfr ,btype ,bteam ,bcheck ,s ,tdate ,CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,bid
					  ,tdes ,sid ,s_c ,s_hdp1 ,s_hdp2 ,s_lh ,s_la ,s_li ,s_o ,s_os
					  ,s_bfr ,s_btype ,s_bteam ,s_bcheck ,s_s ,s_tdate ,CASE WHEN s_checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE s_checkt END AS s_checkt ,s_tdes ,s_sid ,sre
					  ,mre ,re ,cr ,stake ,ost ,curr ,bdaq ,ex ,bo ,w
					  ,acstake ,CASE WHEN wld = '1900-01-01 00:00:00.000' THEN NULL ELSE wld END AS wld ,m ,statuswl ,isP ,sitedb
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, s_t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT ,li BIT 
					 ,o SMALLMONEY ,os MONEY ,bfr NVARCHAR(4) ,btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50) ,s NVARCHAR(10) ,tdate DATETIME ,checkt DATETIME ,bid BIGINT
					 ,tdes NVARCHAR(1000) ,sid TINYINT ,s_c INT ,s_hdp1 SMALLMONEY ,s_hdp2 SMALLMONEY ,s_lh SMALLINT ,s_la SMALLINT ,s_li BIT ,s_o SMALLMONEY ,s_os MONEY 
					 ,s_bfr NVARCHAR(4) ,s_btype SMALLINT ,s_bteam NVARCHAR(10) ,s_bcheck NVARCHAR(50) ,s_s NVARCHAR(10) ,s_tdate DATETIME ,s_checkt DATETIME ,s_tdes NVARCHAR(1000) ,s_sid  TINYINT ,sre INT
					 ,mre INT ,re INT ,cr INT ,stake MONEY ,ost TINYINT ,curr NVARCHAR(50) ,bdaq BIGINT ,ex VARCHAR(1000) ,bo INT ,w MONEY
					 ,acstake MONEY ,wld SMALLDATETIME ,m SMALLMONEY ,statuswl TINYINT ,isP BIT ,sitedb SMALLINT
				)
		) tbl
	WHERE f.value <> ''

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
			,Subbettype
			,SubStatusId
			,SubIssueTypeId
			,GroupName
			,FilterOdds
			,OddsType
			,Filterbettype
		)
	SELECT  DISTINCT b.transid
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
			,b.Subbettype
			,b.SubstatusID
			,d.SubIssueTypeId
			,CASE WHEN b.bettype IN (1,3,7,8) THEN 'LG/Early'
				  WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch = 0 THEN 'PH' --1X2
				  WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 THEN 'PH' --AIO
			END AS GroupName
			,b.odds
			,b.oddstype
			,b.bettype
	FROM #tmpTransInfo b 
		INNER JOIN #FilterInfo d ON d.MatchId = b.matchid
		OUTER APPLY (
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS FavoriteValue
			FROM STRING_SPLIT(d.FavoriteValue, '&')
			WHERE value <> ''				
		)xHDP
		OUTER APPLY (
			SELECT DISTINCT CONVERT(SMALLMONEY, value) AS OUValue
			FROM STRING_SPLIT(d.OUValue, '&')
			WHERE value <> ''				
		)xOU
		LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType AND f.SubIssueTypeId = d.SubIssueTypeId
	WHERE b.betfrom <> 'P'  
		AND b.transdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
		AND b.liveindicator = d.LiveIndicator 
		AND b.IsMixParlay = 0
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
					 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
					 ELSE 0 END
		AND 1 = CASE WHEN d.SubIssueTypeId IN (6) 
							AND b.bettype IN (1)
							AND b.betteam = d.betteam 
							AND ((d.FilterFavoriteType = 'h' AND b.hdp1 = xHDP.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.hdp2 = xHDP.FavoriteValue))
						THEN 1
					 WHEN d.SubIssueTypeId IN (119) 
							AND b.bettype IN (7)
							AND b.betteam = d.betteam 
							AND ((d.FilterFavoriteType = 'h' AND b.hdp1 = xHDP.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.hdp2 = xHDP.FavoriteValue))
						THEN 1
					 WHEN d.SubIssueTypeId IN (120)
							AND b.bettype IN (3)
							AND b.betteam = d.FilterOUType
							AND b.hdp1 = d.OUValue
						THEN 1
					 WHEN d.SubIssueTypeId IN (121)
							AND b.bettype IN (8)
							AND b.betteam = d.FilterOUType
							AND b.hdp1 = d.OUValue
						THEN 1
					 WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1
					 WHEN d.IsMainMatch = 'true' AND f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1 
					 ELSE 0 END
	
	---get sub ticket of a mix parlay	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransInfo WHERE IsMixParlay = 1)
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
				,Subbettype
				,SubStatusId
				,SubIssueTypeId
				,GroupName
				,FilterOdds
				,OddsType
				,Filterbettype
			)
		SELECT  DISTINCT b.transid
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
				,b.Subbettype
				,b.SubstatusID
				,d.SubIssueTypeId
				,'PH' AS GroupName
				,b.Subodds
				,b.oddstype
				,b.Subbettype
		FROM	#FilterInfo d
				INNER JOIN #tmpTransInfo b ON d.MatchId = b.matchid AND b.IsMixParlay = 1
				OUTER APPLY (
					SELECT DISTINCT CONVERT(SMALLMONEY, value) AS FavoriteValue
					FROM STRING_SPLIT(d.FavoriteValue, '&')
					WHERE value <> ''				
				)xHDP
				OUTER APPLY (
					SELECT DISTINCT CONVERT(SMALLMONEY, value) AS OUValue
					FROM STRING_SPLIT(d.OUValue, '&')
					WHERE value <> ''				
				)xOU
				LEFT JOIN dbo.f_TVS_CheckingIssueTypePHBettypes() f ON f.IssueTypeId = @IssueTypeId AND b.Subbettype = f.BetType AND f.SubIssueTypeId = d.SubIssueTypeId
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.SubstatusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.SubstatusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND b.Subbetfrom <> 'P'
				AND b.Subliveindicator = d.LiveIndicator
				AND b.Subtransdate BETWEEN d.FilterFromTransTime AND d.FilterToTransTime
				AND d.IsMainMatch = 'true'
				AND 1 = CASE WHEN d.SubIssueTypeId IN (6) 
									AND b.Subbettype IN (1)
									AND b.Subbetteam = d.betteam 
									AND ((d.FilterFavoriteType = 'h' AND b.Subhdp1 = xHDP.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.Subhdp2 = xHDP.FavoriteValue))
								THEN 1
							 WHEN d.SubIssueTypeId IN (119) 
									AND b.Subbettype IN (7)
									AND b.Subbetteam = d.betteam 
									AND ((d.FilterFavoriteType = 'h' AND b.Subhdp1 = xHDP.FavoriteValue) OR (d.FilterFavoriteType = 'a' AND b.Subhdp2 = xHDP.FavoriteValue))
								THEN 1
							 WHEN d.SubIssueTypeId IN (120)
									AND b.Subbettype IN (3)
									AND b.Subbetteam = d.FilterOUType
									AND b.Subhdp1 = xOU.OUValue
								THEN 1
							 WHEN d.SubIssueTypeId IN (121)
									AND b.Subbettype IN (8)
									AND b.Subbetteam = d.FilterOUType
									AND b.Subhdp1 = xOU.OUValue
								THEN 1
							 WHEN f.BetType IS NOT NULL AND f.GroupMatch = 0 AND d.IsLinkGroup1X2 = 1 THEN 1
							 WHEN f.BetType IS NOT NULL AND f.GroupMatch <> 0 AND d.IsLinkGroupAIO = 1 THEN 1
						ELSE 0 END
	END  

	DECLARE @Odds_str NVARCHAR(100)
		, @FilterOddsType VARCHAR(20)
		, @FromOdds			MONEY = 0
		, @ToOdds			  MONEY = 0

	DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)

	SELECT @FilterOddsType = d.FilterOddsType
	FROM #FilterInfo d

	IF @FilterOddsType = 'Range'
	BEGIN
		SELECT @FromOdds = d.FromOdds, @ToOdds = d.ToOdds
		FROM #FilterInfo d

		IF (@FromOdds < 0 AND @ToOdds > 0) OR (@FromOdds > 0 AND @ToOdds < 0)
		BEGIN
			--Range 1: from negative odds to -1
			SET @FromOdds = CASE WHEN @FromOdds < 0 THEN @FromOdds ELSE @ToOdds END
			SET @ToOdds = -1.00

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

			--Range 1: from 1 to possitive odds
			SET @FromOdds =  CASE WHEN @ToOdds > 0 THEN @ToOdds ELSE @FromOdds END
			SET @ToOdds = 1.00

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
		END
	END
	ELSE IF @FilterOddsType = 'Value'
	BEGIN
		SET @Odds_str = (SELECT REPLACE(d.OddsValue, '&', ',')
						FROM #FilterInfo d)

		INSERT INTO @tmp_Odds (Odds, OddsType)
		SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

		DELETE b
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
		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
	END

	SELECT @MainMatchId = CASE WHEN PoolHouseCheckedBetTypes = 'ALL' THEN MatchId ELSE NULL END
		   ,@PoolHouseCheckedBetTypes = PoolHouseCheckedBetTypes
	FROM #FilterInfo 
	WHERE IsMainMatch = 'true' 

	IF @MainMatchId IS NOT NULL
	BEGIN
		SET @PHBettypes = STUFF((SELECT DISTINCT ',' + CAST(Subbettype AS VARCHAR(10))
									  FROM #TVSTicketBets 
									  WHERE matchid = @MainMatchId
									  AND 1 = CASE WHEN IsMixParlay = 0 AND Subbettype NOT IN (1,3,7,8) THEN 1
												   WHEN IsMixParlay = 1 THEN 1
												   ELSE 0 END
									  FOR XML PATH ('')
								),1,1,'')
		UPDATE #FilterInfo
		SET PoolHouseCheckedBetTypes = @PHBettypes
		WHERE MatchID = @MainMatchId
	END

	/*Remove Transid poolhouse bettype un-check*/
	DELETE b
	FROM #TVSTicketBets b
		INNER JOIN #FilterInfo d ON b.matchid = d.MatchId
		OUTER APPLY (
				SELECT value AS bettype
				FROM STRING_SPLIT(d.PoolHouseCheckedBetTypes, ',')
				WHERE b.Subbettype = CAST (value AS SMALLINT)		
			)xPH
	WHERE d.IsMainMatch = 'true' AND GroupName = 'PH' 
	   AND 1 = CASE WHEN ISNULL(@PoolHouseCheckedBetTypes,'') <> '' AND xPH.bettype IS NULL THEN 1
					WHEN ISNULL(@PoolHouseCheckedBetTypes,'') = '' THEN 1
					ELSE 0 END
		
	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE v SET v.IsPoolHouseAffected = 1
		FROM @Validation v
			INNER JOIN #FilterInfo d ON v.matchid = d.MatchId
		WHERE d.IsMainMatch = 'true'
	END

	--Data Section
	INSERT INTO #logInfo (MatchId, LiveScores, VoidFromTime, VoidToTime, LiveGameEarlySingleCount, LiveGameEarlyCashOutCount, LiveGameEarlySettleCount, LiveGameEarlyInstantlySettleCount, PoolHouseSingleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount, PoolHouseMainParlayCount)
	SELECT b.matchid AS MatchId
		,CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) AS LiveScores
		,MIN(b.transdate) AS VoidFromTime
		,MAX(b.transdate) AS VoidToTime
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'LG/Early' THEN b.transid ELSE NULL END) AS LiveGameEarlySingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'LG/Early' AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS LiveGameEarlyCashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'LG/Early' AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN b.transid ELSE NULL END) AS LiveGameEarlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'LG/Early' AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN b.transid ELSE NULL END) AS LiveGameEarlyInstantlySettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'PH' THEN b.transid ELSE NULL END) AS PoolHouseSingleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'PH' AND b.StatusId IN (111, 112, 113) AND ISNULL(b.betdaqid,-1) = -2 THEN b.transid ELSE NULL END) AS PoolHouseCashOutCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'PH' AND b.StatusId IN (111, 112, 113) AND i.bettype IS NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN b.transid ELSE NULL END) AS PoolHouseSettleCount
		,COUNT(CASE WHEN b.transid = b.SubTransid AND b.GroupName = 'PH' AND b.StatusId IN (111, 112, 113) AND i.bettype IS NOT NULL AND ISNULL(b.betdaqid,-1) <> -2 THEN b.transid ELSE NULL END) AS PoolHouseInstantlySettleCount
		,COUNT(CASE WHEN b.transid <> b.SubTransid AND b.IsMixParlay = 1 THEN b.transid ELSE NULL END) AS PoolHouseMainParlayCount
	FROM #TVSTicketBets b 
		LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
	GROUP BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)), b.matchid
	ORDER BY CAST(b.livehomescore AS VARCHAR(2)) + '-' + CAST(b.liveawayscore AS VARCHAR(2)) ASC

	UPDATE v SET v.IsInValidTotalTickets = CASE WHEN ISNULL(l.SingleCount,0) = 0 AND ISNULL(l.MainParlayCount,0) = 0 THEN 1 ELSE 0 END
				 ,v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE l.IsPoolHouseAffected END
	FROM @Validation v
		OUTER APPLY( 
			SELECT ISNULL(SUM(LiveGameEarlySingleCount),0) + ISNULL(SUM(PoolHouseSingleCount),0) AS SingleCount
				  ,ISNULL(SUM(PoolHouseMainParlayCount),0) AS MainParlayCount
				  ,MAX(CASE WHEN PoolHouseSingleCount <> 0 OR PoolHouseMainParlayCount <> 0 THEN 1 ELSE 0 END) AS IsPoolHouseAffected
			FROM #logInfo
			WHERE MatchId = v.MatchId
			GROUP BY MatchId
		)l 

	IF @IsShowLogOnly = 1 AND @RequestId <> 0
	BEGIN
		/*Support case uncheck bettype PH -> still show PH count = 0 & case voided*/
		UPDATE v
		SET v.IsPoolHouseAffected = CASE WHEN v.IsPoolHouseAffected = 1 THEN v.IsPoolHouseAffected ELSE 1 END
		FROM @Validation v
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON v.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId
			AND rd.TransIds LIKE '%IsMainMatch="true"%' AND rd.TransIds NOT LIKE '%PoolHouseCheckedBetTypes="-1"%'

		-- 1. Validate table
		SELECT MatchId
			,IsInValidTotalTickets
			,IsExistedInOtherRequest
			,IsPoolHouseAffected 
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
		INSERT INTO #logInfoVoidPage (RequestId, MatchId, LiveGameEarlyCashOutCount, LiveGameEarlySettleCount, LiveGameEarlyInstantlySettleCount, PoolHouseCashOutCount, PoolHouseSettleCount, PoolHouseInstantlySettleCount)
		SELECT @RequestId
				,b.matchid
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND b.betdaqid = -2 THEN s.TransId ELSE NULL END) AS LiveGameEarlyCashOutCount
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND ISNULL(b.betdaqid, -1) <> -2 AND i.bettype IS NULL THEN s.TransId ELSE NULL END) AS LiveGameEarlySettleCount
				, COUNT(CASE WHEN b.bettype IN (1,3,7,8) AND ISNULL(b.betdaqid, -1) <> -2 AND i.bettype IS NOT NULL THEN s.TransId ELSE NULL END) AS LiveGameEarlyInstantlySettleCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND b.betdaqid = -2 THEN s.TransId ELSE NULL END) AS PoolHouseCashOutCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND ISNULL(b.betdaqid, -1) <> -2 AND i.bettype IS NULL THEN s.TransId ELSE NULL END) AS PoolHouseSettleCount
				, COUNT(CASE WHEN b.bettype NOT IN (1,3,7,8) AND ISNULL(b.betdaqid, -1) <> -2 AND i.bettype IS NOT NULL THEN s.TransId ELSE NULL END) AS PoolHouseInstantlySettleCount
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
			INNER JOIN #tmpTransInfo b ON b.transid = s.transid AND b.matchid = s.MatchId AND b.IsMixParlay = 0
			LEFT JOIN #InstantSettlementBettypes i ON i.bettype = b.bettype AND i.matchid = b.matchid
		WHERE s.RequestId = @RequestId AND b.StatusId IN (111, 112, 113)
		GROUP BY b.matchid
		
		--Check score for void message
		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT s.MatchId, CAST(b.livehomescore AS VARCHAR(10)) + '-' + CAST(b.liveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = s.bettype
				INNER JOIN #tmpTransInfo b ON b.transid = s.TransId AND b.IsMixParlay = 0
			WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
		END

		IF EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) WHERE s.RequestId = @RequestId)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreNormalTicket)
			SELECT s.MatchId, CAST(b.Sublivehomescore AS VARCHAR(10)) + '-' + CAST(b.Subliveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK)
				INNER JOIN #tmpTransInfo b ON b.Subtransid = s.TransId AND b.IsMixParlay = 1
				INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.Subbettype			
			WHERE s.RequestId = @RequestId AND f.GroupName <> '2H'
		END

		IF NOT EXISTS (SELECT TOP(1) 1 FROM @tblScoreMessage)
		BEGIN
			INSERT INTO @tblScoreMessage (MatchId, ScoreOfMatch) 
			SELECT rd.MatchId, CAST(m.livehomescore AS VARCHAR(10)) + '-' + CAST(m.liveawayscore AS VARCHAR(10))
			FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
				INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = rd.MatchId
			WHERE rd.RequestId = @RequestId
		END

		-- 3. Loginfo table
		SELECT rd.MatchId
			,SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6) AS LiveScores
			,rd.VoidFromTime
			,rd.VoidToTime
			,SUBSTRING(rd.IssueDetail, CHARINDEX('LiveGameEarlySingleCount:',rd.IssueDetail) + LEN('LiveGameEarlySingleCount:'), CHARINDEX(';PoolHouseSingleCount:',rd.IssueDetail) - (CHARINDEX('LiveGameEarlySingleCount:',rd.IssueDetail) + LEN('LiveGameEarlySingleCount:'))) AS LiveGameEarlySingleCount
			,t.LiveGameEarlyCashOutCount
			,t.LiveGameEarlySettleCount
			,t.LiveGameEarlyInstantlySettleCount
			,SUBSTRING(rd.IssueDetail,CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail) + LEN('PoolHouseSingleCount:'), CHARINDEX(';PoolHouseMainParlayCount:',rd.IssueDetail) - ( CHARINDEX('PoolHouseSingleCount:',rd.IssueDetail)+ LEN('PoolHouseSingleCount:'))) AS PoolHouseSingleCount
			,t.PoolHouseCashOutCount
			,t.PoolHouseSettleCount 
			,t.PoolHouseInstantlySettleCount
			,rd.MainParlayCount AS PoolHouseMainParlayCount
			,STUFF(s2.ScoreTicket2H,1,1,'') AS ScoreNormalTicket
			,STUFF(sm.ScoreOfMatch,1,1,'') AS ScoreOfMatch
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
			LEFT JOIN #logInfoVoidPage t ON t.RequestId = rd.RequestId AND t.MatchId = rd.MatchId
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreNormalTicket
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)s2(ScoreTicket2H)
			CROSS APPLY(
				SELECT DISTINCT '|' + l.ScoreOfMatch
				FROM @tblScoreMessage l
				WHERE l.MatchId = rd.MatchId
				FOR XML PATH('')
			)sm(ScoreOfMatch)
		WHERE rd.RequestId = @RequestId

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

	--For case no ticket valid
	SELECT @SingleCount = ISNULL(SUM(LiveGameEarlySingleCount),0) + ISNULL(SUM(PoolHouseSingleCount),0)
		  ,@MainParlayCount = ISNULL(SUM(PoolHouseMainParlayCount),0)
	FROM #logInfo
	IF @SingleCount = 0 AND @MainParlayCount = 0
	BEGIN
		-- 1. Validate table
		SELECT MatchId
			, 1 AS IsInValidTotalTickets
			, IsExistedInOtherRequest
			, IsPoolHouseAffected
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
			
		-- 3. Loginfo table (No need -> return table)
		SELECT MatchId FROM #logInfo WHERE Matchid IS NULL

		-- 4. Unmark table (No need -> return table)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId
		
		-- 5. Transinfo table (No need -> return table)
		SELECT @TransInfoJson_Output AS TransInfoJson

		RETURN;
	END

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		--Mark ticket when add request
		INSERT INTO @tmpMarkTransId (TransId)
		SELECT tp.SubTransid
		FROM #TVSTicketBets tp
		WHERE tp.SubStatusId IN (0,1)
	END
	ELSE IF @IsShowLogOnly = 0 AND @RequestId <> 0 
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Edit request filter on UI -> unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT um.TransId
			FROM (
					SELECT s.TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
					WHERE s.RequestId = @RequestId
					UNION ALL
					SELECT p.TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay p WITH(NOLOCK)
					WHERE p.RequestId = @RequestId
				)um
				LEFT JOIN #TVSTicketBets tp ON um.TransId = tp.SubTransid 
			WHERE tp.TransId IS NULL 

			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			--Mark ticket when add request
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT tp.SubTransid
			FROM #TVSTicketBets tp
			WHERE tp.SubStatusId IN (0,1)
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId -- Take note
		BEGIN
			--Unmark ticket 
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT s.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
			WHERE s.RequestId = @RequestId
			UNION ALL
			SELECT p.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay p WITH(NOLOCK)
			WHERE p.RequestId = @RequestId
		END

	END
	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,'')
											,'')

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
										FROM @tmpMarkTransId
										FOR XML PATH('')), 1,1,'')
										,'')

	/*****************Return table **************************/
	-- 1. Validate table
	SELECT MatchId
		,IsInValidTotalTickets
		,IsExistedInOtherRequest
		,IsPoolHouseAffected
	FROM @Validation

	-- 2. TransId exists in other request table
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

	-- 3. Loginfo table
	SELECT MatchId
		,STUFF(w.scores,1,1,'') AS LiveScores
		,MIN(VoidFromTime) AS VoidFromTime
		,MAX(VoidToTime) AS VoidToTime
		,SUM(LiveGameEarlySingleCount) AS LiveGameEarlySingleCount
		,SUM(LiveGameEarlyCashOutCount) AS LiveGameEarlyCashOutCount
		,SUM(LiveGameEarlySettleCount) AS LiveGameEarlySettleCount
		,SUM(LiveGameEarlyInstantlySettleCount) AS LiveGameEarlyInstantlySettleCount
		,SUM(PoolHouseSingleCount) AS PoolHouseSingleCount
		,SUM(PoolHouseCashOutCount) AS PoolHouseCashOutCount
		,SUM(PoolHouseSettleCount) AS PoolHouseSettleCount
		,SUM(PoolHouseInstantlySettleCount) AS PoolHouseInstantlySettleCount
		,SUM(PoolHouseMainParlayCount) AS PoolHouseMainParlayCount
	FROM #logInfo l
		CROSS APPLY(
					SELECT '|' + LiveScores
					FROM #logInfo rd
					where l.MatchId = rd.MatchId
					FOR XML PATH('')
					)w (scores) 
	GROUP BY MatchId, w.scores

	-- 4. List ticket unmark/mark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@MarkTransIds AS MarkTransIds

	-- 5. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,t.Subtransid  AS 's_t'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.Subbettype AS 's_btype'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #TVSTicketBets t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #logInfo
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #FilterInfo
	DROP TABLE #logInfoVoidPage
	DROP TABLE #tmpTransInfo
END
GO

