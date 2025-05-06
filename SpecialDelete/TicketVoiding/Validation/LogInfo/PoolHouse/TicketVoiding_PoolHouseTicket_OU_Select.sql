/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_PoolHouseTicket_OU_Select]
(	
	@MatchId              INT
	,@RequestId			  INT
	,@IssueTypeId		  INT
	,@ActionId			  INT
	,@SubIssueTypeId	  INT
	,@FilterFromTransTime DATETIME
	,@FilterToTransTime	  DATETIME
	,@IsLinkGroup1X2	  BIT = 0
	,@IsLinkGroupAIO	  BIT = 0
	,@LiveIndicator		  BIT = 0
	,@WrongMarket         VARCHAR(1000) = NULL

)
AS
/*	
	Created by: 20230403@July
	Task: Affected Pool House Ticket popup  [Redmine: #172975]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20230403@July: TVS - Wrong OU affects to PH bet types [Redmine: #172975]
		- 20230802@July: Fix bug - Tickets bettype HDP/OU with HDP/OU value difference filter NOT SHOW on Other group  [Redmine: #190441]
		- 20231005@July: [TVS] Update affected Pool House's bet types when bet types FT/HT 1X2 affected by offering wrong market [Redmine: #192202]
		- 20231130@Max: HotFix - Affected Pool House Ticket Detail SHOW DUPLICATE [Redmine: #197662]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20250319@Lani: [TVS] Enhance out of memory issue [Redmine: #217771]

	Param's explanation:


*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SiteDBGroupID	SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

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

	DECLARE @tmpWrongMarket TABLE (WrongMarket SMALLMONEY)
	
	IF @WrongMarket IS NOT NULL
	BEGIN
		INSERT INTO @tmpWrongMarket (WrongMarket)
		SELECT DISTINCT value AS WrongMarket
		FROM STRING_SPLIT(@WrongMarket, '&')
		WHERE value <> ''
	END

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
			,b.status AS SubStatus
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
	FROM bettrans AS b WITH (NOLOCK)
		INNER JOIN @tmpMatch m ON b.matchid = m.MatchId
		OUTER APPLY(
					SELECT DISTINCT 
							CASE WHEN @IsLinkGroup1X2 = 1 AND f.GroupMatch = 0 AND @IssueTypeId = 6 AND f.BetType = 5 THEN '1X2' 
								WHEN @IsLinkGroup1X2 = 1 AND f.GroupMatch = 0 AND @IssueTypeId = 7 AND f.BetType = 15 THEN '1H 1X2' 
								ELSE 'AIO' END AS GroupName
					FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
					WHERE f.IssueTypeId = @IssueTypeId AND b.bettype = f.BetType
						AND ((f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1) OR (f.GroupMatch <> 0 AND @IsLinkGroupAIO = 1))
					)f
	WHERE b.betfrom <> 'P'  
		AND b.liveindicator = @LiveIndicator
		AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
		AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
		AND 1 = CASE WHEN @IssueTypeId = 6 AND b.bettype = 3 AND b.hdp1 IN (SELECT WrongMarket FROM @tmpWrongMarket) THEN 0
						WHEN @IssueTypeId = 7 AND b.bettype = 8 AND b.hdp1 IN (SELECT WrongMarket FROM @tmpWrongMarket) THEN 0 
						ELSE 1 END
		AND b.SiteDBGroupID = @SiteDBGroupID

	--get sub ticket of a mix parlay
	IF EXISTS (
			SELECT TOP (1) 1 
			FROM dbo.bettransm AS bm WITH (NOLOCK) 
				INNER JOIN @tmpMatch m ON bm.matchid = m.MatchId
			WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				  		   WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
				   		   ELSE 0 END 
				AND bm.betfrom <> 'P'
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
		)
		SELECT DISTINCT  b.transid 
				,bm.transid AS Subtransid
				,b.refno
				,bm.custid AS Subcustid				
				,b.odds
				,bm.odds AS SubOdds
				,bm.oddsspread AS Suboddsspread
				,b.OddsType
				,bm.transdate AS Subtransdate
				,b.bettype
				,bm.bettype AS SubBettype
				,b.betteam
				,bm.betteam AS SubBetteam
				,b.betcheck				
				,bm.betcheck AS SubBetcheck
				,bm.hdp1 AS Subhdp1
				,bm.hdp2 AS Subhdp2
				,b.hdp1
				,b.hdp2
				,bm.livehomescore AS Sublivehomescore
				,bm.liveawayscore AS Subliveawayscore
				,b.creator
				,b.stake
				,b.currencyname				
				,b.status
				,bm.status AS SubStatus
				,bm.transdesc AS SubTransdesc
				,1 AS IsMixParlay
				,b.modds
				,b.transid AS MainTransId
				,b.winlost - b.actual_stake AS WinLost
				,bm.liveindicator AS Subliveindicator
				,b.actual_stake AS ActualStake
				,m.MatchId_tmp AS Matchid
				,b.srecommend
				,CASE WHEN ((@IssueTypeId = 6 AND bm.bettype = 3) OR (@IssueTypeId = 7 AND bm.bettype = 8)) AND bm.hdp1 IN (SELECT WrongMarket FROM @tmpWrongMarket) THEN 'OU'
						WHEN f.GroupName IS NOT NULL THEN f.GroupName 
						ELSE 'Others'
					END AS GroupName
				,bm.statusID
				,b.ExtraInfo
				,b.winlostdate
		FROM  @tmpMatch m
			INNER LOOP JOIN dbo.bettransm AS bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) ON bm.refno = b.refno
			OUTER APPLY(
				SELECT DISTINCT 
						CASE WHEN @IsLinkGroup1X2 = 1 AND f.GroupMatch = 0 AND @IssueTypeId = 6 AND f.BetType = 5 THEN '1X2' 
							WHEN @IsLinkGroup1X2 = 1 AND f.GroupMatch = 0 AND @IssueTypeId = 7 AND f.BetType = 15 THEN '1H 1X2' 
							ELSE 'AIO' END AS GroupName
				FROM dbo.f_TVS_CheckingIssueTypePHBettypes() f 
				WHERE f.IssueTypeId = @IssueTypeId AND bm.bettype = f.BetType
					AND ((f.GroupMatch = 0 AND @IsLinkGroup1X2 = 1) OR (f.GroupMatch <> 0 AND @IsLinkGroupAIO = 1))
			)f
		WHERE 1 = CASE WHEN @ActionId <>2 AND bm.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
						WHEN @ActionId = 2 AND bm.statusID NOT IN (101, 103) THEN 1
						ELSE 0 END
				AND bm.betfrom <> 'P'
				AND bm.liveindicator = @LiveIndicator
				AND bm.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime
				AND b.SiteDBGroupID = @SiteDBGroupID AND bm.SiteDBGroupID = @SiteDBGroupID

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

				INSERT INTO #TransidInRequest (TransId, RequestId, MainTransId, MatchId)
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
		, CASE WHEN @IssueTypeId IN (6) AND s.GroupName IN ('1X2', 'OU') THEN '1X2' 
			   WHEN @IssueTypeId IN (7) AND s.GroupName IN ('1H 1X2', 'OU') THEN '1H 1X2' 
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