/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_PoolHouseTicket_WO_Select]
(	
	@RequestId			  INT
	,@IssueTypeId		  INT
	,@ActionId			  INT
	,@WrongOddsInfo       VARCHAR(MAX) = NULL

)
AS
/*	
	Created by: 20230419@Max
	Task: [TVS] New issue type Wrong Odds [Redmine: #179934]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20230419@Max: Create new SP [Redmine:#179934]
		- 20231017@Max: [TVS] Update rule get tickets when offering wrong handicap [Redmine: #195445]
		- 20231005@July: [TVS] Update affected Pool House's bet types when bet types FT/HT 1X2 affected by offering wrong market [Redmine: #192202]
		- 20231130@Max: HotFix - Affected Pool House Ticket Detail SHOW DUPLICATE [Redmine: #197662]
		- 20231207@July: [TVS] Fix issue Pool House input more 2 values still show ticket LG [Redmine: #196467]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240618@July: [TVS] Support void wrong odds of Home/Away or Over/Under at the same time [Redmine: #205558]
		- 20241007@July: TVS - Wrong Odds - Wrongly converting odds to search ticket [Redmine: #211890]
		- 20250319@Lani: [TVS] Enhance out of memory issue [Redmine: #217771]

	Param's explanation:


*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId					INT = 0
		   ,@SubIssueTypeId				INT = NULL
		   ,@FilterFromTransTime		DATETIME = NULL
		   ,@FilterToTransTime			DATETIME = NULL
		   ,@IsLinkGroup1X2				BIT = 0
		   ,@IsLinkGroupAIO				BIT = 0
		   ,@LiveIndicator				BIT = 0
		   ,@FilterFavoriteType			VARCHAR(10) -- "h" or "a"
		   ,@FavoriteValue				SMALLMONEY -- "1.25"
		   ,@WrongOU					SMALLMONEY -- "1.25"
		   ,@WrongOddsInfoXML			XML = NULL
		   ,@FromOddsNotVoidHomeOver	SMALLMONEY
		   ,@ToOddsNotVoidHomeOver		SMALLMONEY
		   ,@FromOddsNotVoidAwayUnder	SMALLMONEY
		   ,@ToOddsNotVoidAwayUnder		SMALLMONEY
		   ,@SiteDBGroupID				SMALLINT

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
		IsDeposit			  BIT DEFAULT(0),
		srecommend			  INT,
		GroupName			  VARCHAR(50),
		FilterOdds			  MONEY,
		ID 					  INT IDENTITY (1,1) PRIMARY KEY

	)
	CREATE TABLE #TransidInRequest (TransId BIGINT, RequestId INT, MainTransId BIGINT, MatchId INT)
	
	CREATE TABLE #tmpBettype (
		 Id            INT
		,GroupName	   VARCHAR(50) 
    )

	DECLARE @tmpMatch TABLE (MatchId INT
		,MatchId_tmp INT
	)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SET @WrongOddsInfoXML = CONVERT(XML, @WrongOddsInfo)
	SELECT  @MatchId = t.c.value('@MatchId','INT')
			,@FilterFromTransTime = CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END 
			,@FilterToTransTime = CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END 
			,@SubIssueTypeId = t.c.value('@SubIssueTypeId','SMALLINT') 
			,@IsLinkGroup1X2 = t.c.value('@IsLinkGroup1X2','BIT') 
			,@IsLinkGroupAIO = t.c.value('@IsLinkGroupAIO','BIT') 
			,@LiveIndicator = t.c.value('@LiveIndicator','BIT') 
			,@FilterFavoriteType = t.c.value('@FilterFavoriteType', 'VARCHAR(10)') 
			,@FavoriteValue = t.c.value('@FavoriteValue', 'SMALLMONEY') 
			,@WrongOU = t.c.value('@WrongOU', 'SMALLMONEY') 
			,@FromOddsNotVoidHomeOver = t.c.value('@FromOddsNotVoidHomeOver', 'SMALLMONEY')
			,@ToOddsNotVoidHomeOver = t.c.value('@ToOddsNotVoidHomeOver', 'SMALLMONEY')
			,@FromOddsNotVoidAwayUnder = t.c.value('@FromOddsNotVoidAwayUnder', 'SMALLMONEY')
			,@ToOddsNotVoidAwayUnder = t.c.value('@ToOddsNotVoidAwayUnder', 'SMALLMONEY')
	FROM	@WrongOddsInfoXML.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@WrongOddsInfoXML = NULL ))

	--cricket/baseball - get child match
	INSERT INTO @tmpMatch (MatchId, MatchId_tmp)
	SELECT m.MatchId, @MatchId
	FROM dbo.match AS m WITH (NOLOCK)
	WHERE 1 = CASE WHEN m.matchid = @MatchId THEN 1
				   WHEN m.sporttype IN (50,8)
						AND (m.ChildMatchType = 200 AND m.ParentID = @MatchId) THEN 1
				   ELSE 0 END

	--Get single ticket
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
		,srecommend
		,GroupName
		,statusID
		,modds
		,ExtraInfo
		,winlostdate
		,FilterOdds
	)
	SELECT DISTINCT  b.transid
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
			,b.Status AS SubStatus
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
			,m.MatchId_tmp AS Matchid
			,b.srecommend
			,CASE WHEN f.GroupName IS NOT NULL THEN f.GroupName 
					ELSE 'Others' 
				END AS GroupName
			,b.statusID
			,b.modds
			,b.ExtraInfo
			,b.winlostdate
			,b.odds
	FROM bettrans AS b WITH (NOLOCK)
		INNER JOIN @tmpMatch m ON b.matchid = m.MatchId
		OUTER APPLY(
				SELECT DISTINCT 
						CASE WHEN f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 AND @SubIssueTypeId IN (6,120) AND f.BetType = 5 THEN '1X2' 
							WHEN f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 AND @SubIssueTypeId IN (119,121) AND f.BetType = 15 THEN '1H 1X2' 
							ELSE 'AIO' END AS GroupName
				FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
				WHERE f.IssueTypeId = @IssueTypeId 
					AND f.SubIssueTypeId = @SubIssueTypeId
					AND b.bettype = f.BetType
					AND 1 = CASE WHEN (f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1) THEN 1
									WHEN (f.GroupMatch <> 0 AND @IsLinkGroupAIO = 1) THEN 1
									ELSE 0 END
		)f
	WHERE b.betfrom <> 'P'  
		AND b.liveindicator = @LiveIndicator
		AND b.SiteDBGroupID = @SiteDBGroupID
		AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
		AND 1 = CASE WHEN (
							(@SubIssueTypeId IN (6) AND b.bettype IN (1)) 
							OR (@SubIssueTypeId IN (119) AND b.bettype IN (7))
							) 
						AND (
								(@FavoriteValue <> 0
									AND((@FilterFavoriteType = 'h' AND b.hdp1 = @FavoriteValue) OR (@FilterFavoriteType = 'a' AND b.hdp2 = @FavoriteValue))
								)
								OR (@FavoriteValue = 0 AND b.hdp1 = 0 AND b.hdp2 = 0)
								)
					THEN 0
					WHEN (
							(@SubIssueTypeId IN (120) AND b.bettype IN (3)) 
							OR (@SubIssueTypeId IN (121) AND b.bettype IN (8))
							)
						AND b.hdp1 = @WrongOU
					THEN 0
					ELSE 1 END

	--get sub ticket of a mix parlay
	IF EXISTS (
			SELECT TOP (1) 1 
			FROM dbo.bettransm AS bm WITH (NOLOCK) 
			INNER JOIN @tmpMatch m ON bm.matchid = m.MatchId
			WHERE bm.statusID NOT IN (101, 102, 103) AND bm.betfrom <> 'P'
			)
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
				,srecommend
				,GroupName
				,statusID
				,ExtraInfo
				,winlostdate
				,FilterOdds
		)
		SELECT DISTINCT  b.transid 
				,bm.transid AS Subtransid
				,b.refno
				,bm.custid AS Subcustid			
				,b.odds
				,bm.Odds AS SubOdds
				,bm.oddsspread AS Suboddsspread
				,b.OddsType
				,bm.transdate AS Subtransdate
				,b.bettype
				,bm.Bettype AS SubBettype
				,b.betteam
				,bm.Betteam AS SubBetteam
				,b.betcheck				
				,bm.Betcheck AS SubBetcheck
				,bm.hdp1 AS Subhdp1
				,bm.hdp2 AS Subhdp2
				,b.hdp1
				,b.hdp2
				,bm.livehomescore AS Sublivehomescore
				,bm.liveawayscore AS Subliveawayscore
				,b.creator
				,b.stake
				,b.currencyname				
				,b.STATUS
				,bm.Status AS SubStatus
				,bm.Transdesc AS SubTransdesc
				,1 AS IsMixParlay
				,b.modds
				,b.transid AS MainTransId
				,b.winlost - b.actual_stake AS WinLost
				,bm.liveindicator AS Subliveindicator
				,b.actual_stake AS ActualStake
				,m.MatchId_tmp AS Matchid
				,b.srecommend
				,CASE WHEN (
							(@SubIssueTypeId IN (6) AND bm.bettype IN (1)) 
							OR (@SubIssueTypeId IN (119) AND bm.bettype IN (7))
							) 
							AND (
							(@FavoriteValue <> 0
								AND((@FilterFavoriteType = 'h' AND bm.hdp1 = @FavoriteValue) OR (@FilterFavoriteType = 'a' AND bm.hdp2 = @FavoriteValue))
							)
							OR (@FavoriteValue = 0 AND bm.hdp1 = 0 AND bm.hdp2 = 0)
							)
						THEN 'HDP'
						WHEN (
							(@SubIssueTypeId IN (120) AND bm.bettype IN (3)) 
							OR (@SubIssueTypeId IN (121) AND bm.bettype IN (8))
							)
							AND bm.hdp1 = @WrongOU
						THEN 'OU'
						WHEN f.GroupName IS NOT NULL THEN f.GroupName 
						ELSE 'Others'
					END AS GroupName
				,bm.statusID AS SubstatusID
				,b.ExtraInfo
				,b.winlostdate
				,bm.odds AS SubOdds
			FROM @tmpMatch m
				INNER JOIN dbo.bettransm AS bm WITH(NOLOCK) ON m.MatchId = bm.matchid
				INNER HASH JOIN bettrans AS b WITH (NOLOCK) ON bm.refno =  b.refno
				OUTER APPLY(
					SELECT DISTINCT 
							CASE WHEN f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 AND @SubIssueTypeId IN (6,120) AND f.BetType = 5 THEN '1X2' 
								WHEN f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1 AND @SubIssueTypeId IN (119,121) AND f.BetType = 15 THEN '1H 1X2' 
								ELSE 'AIO' END AS GroupName
					FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
					WHERE f.IssueTypeId = @IssueTypeId 
						AND f.SubIssueTypeId = @SubIssueTypeId
						AND bm.bettype = f.BetType
						AND 1 = CASE WHEN (f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1) THEN 1
										WHEN (f.GroupMatch <> 0 AND @IsLinkGroupAIO = 1) THEN 1
										ELSE 0 END
				)f
		WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND bm.betfrom <> 'P'
				AND bm.liveindicator = @LiveIndicator
				AND bm.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
				AND bm.SiteDBGroupID = @SiteDBGroupID
	END

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsMixParlay = 1)
	BEGIN
		DECLARE @Odds_str		NVARCHAR(100)
			  , @FromOdds	    SMALLMONEY = 0
			  , @ToOdds			SMALLMONEY = 0
			  , @tmp_ToOdds		SMALLMONEY = 0
			  , @tmp_FromOdds	SMALLMONEY = 0
			  , @Betteam		NVARCHAR(10)

		DECLARE @tmp_Odds AS TABLE (Odds SMALLMONEY, OddsType TINYINT)
		DECLARE @tmp_OddsRange TABLE (FromOdds SMALLMONEY, ToOdds SMALLMONEY, Betteam NVARCHAR(10), IsFinish BIT)

		INSERT INTO @tmp_OddsRange(FromOdds, ToOdds, Betteam)
		SELECT @FromOddsNotVoidHomeOver, @ToOddsNotVoidHomeOver, 'h'
		UNION ALL
		SELECT @FromOddsNotVoidAwayUnder, @ToOddsNotVoidAwayUnder, 'a'

		WHILE (1=1)
		BEGIN
			DELETE FROM @tmp_Odds

			UPDATE TOP(1) d
			SET @FromOdds = d.FromOdds
			  , @ToOdds = d.ToOdds
			  , @Betteam = d.Betteam
			  , IsFinish = 1
			FROM @tmp_OddsRange d
			WHERE d.IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;

			IF (@FromOdds < 0 AND @ToOdds > 0) OR (@FromOdds > 0 AND @ToOdds < 0)
			BEGIN
				--Range 1: negative
				SET @tmp_FromOdds = CASE WHEN @FromOdds < 0 THEN @FromOdds ELSE @ToOdds END
				SET @tmp_ToOdds = -1.00
				
				SET @Odds_str = (SELECT CAST(@tmp_FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
				INSERT INTO @tmp_Odds (Odds, OddsType)
				SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

				;WITH cte AS
				(
					SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
					FROM @tmp_Odds
					GROUP BY OddsType
				)
				--Remove transid-> NOT VOID affect main bettype
				UPDATE b SET b.GroupName = 'Others'
				FROM #TVSTicketBets b
					INNER JOIN cte tp ON tp.OddsType = b.OddsType
				WHERE b.IsMixParlay = 1 
					AND b.Subbettype IN (1,3,7,8)
					AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds
					AND b.SubBetTeam = @Betteam

				DELETE @tmp_Odds
				--Range 1: possitive
				SET @tmp_FromOdds =  CASE WHEN @ToOdds > 0 THEN @ToOdds ELSE @FromOdds END
				SET @tmp_ToOdds = 1.00

				SET @Odds_str = (SELECT CAST(@tmp_FromOdds AS VARCHAR(10)) + ',' + CAST(@tmp_ToOdds AS VARCHAR(10)))
		
				INSERT INTO @tmp_Odds (Odds, OddsType)
				SELECT f.Odds, f.OddsType FROM f_TVS_OddsFilter_Calculate(@Odds_str, 'MY') f

				;WITH cte AS
				(
					SELECT OddsType, MIN(Odds) AS FromOdds, MAX(Odds) AS ToOdds
					FROM @tmp_Odds
					GROUP BY OddsType
				)
				--Remove transid-> NOT VOID affect main bettype
				UPDATE b SET b.GroupName = 'Others'
				FROM #TVSTicketBets b
					INNER JOIN cte tp ON tp.OddsType = b.OddsType
				WHERE b.IsMixParlay = 1 
					AND b.Subbettype IN (1,3,7,8)
					AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds
					AND b.SubBetTeam = @Betteam
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
				--Remove transid-> NOT VOID affect main bettype
				UPDATE b SET b.GroupName = 'Others'
				FROM #TVSTicketBets b
					INNER JOIN cte tp ON tp.OddsType = b.OddsType
				WHERE b.IsMixParlay = 1 
					AND b.Subbettype IN (1,3,7,8)
					AND b.FilterOdds BETWEEN tp.FromOdds AND tp.ToOdds
					AND b.SubBetTeam = @Betteam
			END
		END
	END

	DECLARE @TransInfoJson_Request			 VARBINARY(MAX)
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	SET @MaxRow = (SELECT MAX(ID) FROM #TVSTicketBets)
	SET @Threshold = 20000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold
	IF @ActionId <> 2
	BEGIN
		WHILE (@MaxRow IS NOT NULL)
		BEGIN
		
				SET @TransInfoJson_Request = COMPRESS((SELECT matchid AS 'mid'
						,transid AS 't'
						,SubTransid AS 's_t'
				FROM #TVSTicketBets R
				WHERE ID BETWEEN @StartRow AND @StopRow
					FOR JSON PATH))

				INSERT INTO #TransidInRequest
				EXEC DBCTG.bodb02.dbo.TicketVoiding_CheckExistingRequest
					@TransInfoJson = @TransInfoJson_Request
					,@RequestId = @RequestId
					,@Mode = 1

				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow

		END

		--Remove Transid exists in other request
		DELETE FROM #TVSTicketBets 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = SubTransid)
	END

	--Return all bettype tickets
	INSERT INTO #tmpBettype (Id, GroupName)
	SELECT DISTINCT s.SubBetType AS Id
		, CASE WHEN @SubIssueTypeId IN (6,120) AND s.GroupName IN ('1X2', 'OU', 'HDP') THEN '1X2' 
			   WHEN @SubIssueTypeId IN (119,121) AND s.GroupName IN ('1H 1X2', 'OU', 'HDP') THEN '1H 1X2' 
			   ELSE s.GroupName 
		  END AS GroupName
	FROM #TVSTicketBets s

	SELECT s.Id, b.typenamee AS Name, s.GroupName
	FROM #tmpBettype s
		INNER JOIN dbo.bettype b WITH(NOLOCK) ON s.Id = b.typeid

	-- update Isdeposit
	UPDATE al 
		SET IsDeposit = 1
	FROM	#TVSTicketBets al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)

	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30))

	;WITH CTE_CustIdAll AS (
			SELECT DISTINCT t.custid
			FROM #TVSTicketBets b
			CROSS APPLY (
				VALUES (custid)
				,(creator)
			) AS t (custid)
		)
	INSERT INTO #CTE_CustInfo (custid, username)
		SELECT ci.custid
			, ci.username
		FROM CustDB.dbo.custInfo ci WITH(NOLOCK)
			INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid	

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
		   ,s.IsDeposit
		   ,CASE WHEN s.IsMixParlay = 1 AND s.GroupName <> 'Others' AND s.IsDeposit = 0 THEN 'Credit (Parlay)'
				 WHEN s.IsMixParlay = 1 AND s.GroupName <> 'Others' AND s.IsDeposit = 1 THEN 'Deposit (Parlay)' 
				 ELSE s.GroupName END AS GroupName
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
		INNER JOIN #CTE_CustInfo cr WITH(NOLOCK) ON s.creator = cr.custid
		INNER JOIN #CTE_CustInfo ci WITH(NOLOCK) ON s.custid = ci.custid
	ORDER BY CASE WHEN s.GroupName IN ('1X2', '1H 1X2') AND s.transid = s.SubTransid THEN 1
				  WHEN s.GroupName = 'AIO' AND s.transid = s.SubTransid THEN 2
				  WHEN s.IsMixParlay = 1 AND s.GroupName <> 'Others' THEN 3
				  ELSE 4 END
			, ISNULL(s.MainTransId, s.transid)

	DROP TABLE #TVSTicketBets
	DROP TABLE #TransidInRequest
	DROP TABLE #tmpBettype
	DROP TABLE #CTE_CustInfo

	SET NOCOUNT OFF
END
