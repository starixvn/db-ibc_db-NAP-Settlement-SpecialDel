/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Sel] 
(
	@CustID            VARCHAR(MAX) = NULL,
    @TransIds          VARCHAR(MAX) = NULL,
    @FromDate          DATETIME     = NULL,
    @ToDate            DATETIME     = NULL,
    @IncludeMainParlay BIT          = 0,
	@Products		   VARCHAR(50)  = NULL,
	@StatusIds		   VARCHAR(50)  = NULL,
    @InvalidTransIds   VARCHAR(MAX) = '' OUTPUT,
    @MovedTransIds     VARCHAR(MAX) = '' OUTPUT
)
AS;
/*  
	Created by: Bobby  
	Date: 20160225
	Task: Get tickets by Bet ID/CustID : 
		  Normal SB, Outright, Mix Parlay (Allow to delete Running & Refunded), NG, and Live Casino 
	DB: DBTXN/bodb02   
	Original:NAP_BettransSpecialDelBetID_Sel     

	Revisions:  
		- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]
		- 20150611@Dominic: BetTrade Integration [Redmine:#36964]
		- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]
		- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]
		- 20151102@Kathy: Enhance performance [Redmine:#43233]
		- 20150712@Kathy: Database - Change datatype [Redmine: #48660]
		- 20160113@Patrick: Support Cricket [Redmine: #50688]
		- 20160301@Bobby: #53123 - Enhance SP void bet by Id list (allow transId up to 1000 rows)
		- 20160314@Bobby: #53935 - Update changes for multiple bet trade transaction
		- 20160413@Bobby: #55893 - Update change request for grouping tickets
		- 20160714@Kathy: change the order of result: groupname, groupid, transid
		- 20160816@Bobby: #62527 - Update BT's info for showing bet list	
		- 20160914@Kent: Add logic for suporting void system parlay [Redmine:#63202]	
		- 20161013@Kathy: Exclude phone betting tickets [Redmine:#63211]
		- 20161124@Kent: Include phone betting tickets and add new GroupName "Phone Betting" [Redmine:#67751]
		- 20170302@Kent: Fix show time for virtual sport [Redmine:#72475]
		- 20170314@Kent: Integrate cash-out [Redmine:#72059]
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170530@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	
		- 20170725@Paul: Return CurrencyName [Redmine:#77175]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]	
		- 20170503@Kent: Integrate bonus [Redmine:#72790]	
		- 20180306@Kathy: get Refcode value [Redmine:#91461]
		- 20180301@Benjamin: Add oddsspread - Fast Markets Phase 2 [Redmine:#90667]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20171029@Alan: Return Licensees Name [103474]
		- 20181004@Alan: Add new column SettlementStatus [102423]
		- 20190220@Alan: Separate a function from Void By Bet ID to void main parlay ticket [108969]
		- 20190426@Jacob: Mark Tickets - Enhancement [112480]
		- 20190227@Alan: Implement Bet Builder - [106898]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20191106@Charles: Implement NPM Promotion [122187]
		- 20200618@Max: Hotfix Change Primary key on MarkedTransaction [Redmine: #136064]
		- 20200810@Charles: Offer Saba Loyalty for Saba Promotion [139255]
		- 20201005@Max: TVS - Enhance void by Bet ID to support void by customer [Redmine: #142010]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210622@Helen: [TVS] SP Tuning [Redmine: #157354]
		- 20210526@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210820@July: Integrate Bitcoin [Redmine: #159948]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220214@July: Intergrate new Saba Basketball PinGoal [Redmine: #168079]

	Param's Explanation:
		+ @CustID NOT NULL: Search by CustID
		+ @TransIds NOT NULL: Search by TransID
		+ @@Products : 1 - Sportbook
					2 - Parlay
					3 - Bet Builder
					4 - Outright
					5 - Saba
					6 - NonSport

	*/
BEGIN
	SET NOCOUNT ON
	
	IF(@CustID IS NULL AND @TransIds IS NULL) RETURN
	
	DECLARE @movebetdate SMALLDATETIME,
			@maxdate 	DATETIME = '9999-01-01',
			@IsSB BIT = 0,
			@IsParlay BIT = 0,
			@IsBB BIT = 0,
			@IsOutright BIT = 0,
			@IsSaba BIT = 0,
			@IsNonSport BIT = 0,
			@MovebetDay DATETIME

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)	
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)
	-- invalid trans
	SELECT @InvalidTransIds = '', @MovedTransIds = ''

	--Get Movebetdate
	EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT
	
	SELECT @FromDate	= ISNULL(@FromDate, @movebetdate)
		, @FromDate 	= CASE WHEN @FromDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromDate END

	IF @ToDate IS NULL
	BEGIN
		SET @ToDate = @maxdate
	END
	
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)	
	CREATE TABLE #CustId (CustId INT)

	CREATE TABLE #Data
             (GroupID               BIGINT,
              bettype               INT,
              transid               BIGINT,
              betid                 BIGINT,
              refno                 BIGINT,
              matchcode             NVARCHAR(50),
              homeid                INT,
              awayid                INT,
              hdp1                  SMALLMONEY,
              hdp2                  SMALLMONEY,
              odds                  MONEY,
              oddsspread            MONEY DEFAULT 0,
              finalodds             MONEY,
              finalodds2            MONEY,
              OddsType              TINYINT,
              STATUS                NVARCHAR(50),
              comstatus             NVARCHAR(50),
              stake                 MONEY,
              transdate             DATETIME,
              betteam               NVARCHAR(10),
              betcheck              NVARCHAR(50),
              liveindicator         BIT,
              modds                 MONEY,
              custid                INT,
              username              VARCHAR(30),
              livehomescore         INT,
              liveawayscore         INT,
              leagueid              INT,
              sporttype             SMALLINT,
              betfrom               NVARCHAR(1),
              matchid               INT,
              isNeutral             BIT,
              winlost               MONEY,
              commission            MONEY,
              showtime              NVARCHAR(50),
              winlostdate           SMALLDATETIME,
              TransDesc             NVARCHAR(1000),
              betdaqid              BIGINT,
              recommend             INT,
              IsHideComm            BIT DEFAULT(0),
              oddsid                INT,
              ExtraInfo             VARCHAR(1000),
              IsCashOut				BIT DEFAULT(0),
              CurrencyName          NVARCHAR(50),
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
			  IsMarked			 	BIT,
			  ActualStake			MONEY,
			  eventdate				DATETIME,
			  EndTime				DATETIME, --support Bitcoin
             );
    CREATE TABLE #tmpRefCodeSummary
             (RefCode BIGINT,
              custid  INT,
              matchid INT,
              bettype SMALLINT,
              transid BIGINT,
		      IsMarked BIT
             );

	CREATE INDEX IX_Data_RefCode ON #Data(RefCode)			
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)
	
	IF @CustID IS NOT NULL
	BEGIN
		SELECT @IsSB = CASE WHEN CHARINDEX('1',@Products) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@Products) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@Products) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@Products) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@Products) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@Products) > 0 THEN 1 ELSE 0 END
	END

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE 1 = CASE WHEN @CustID IS NULL THEN 1
			ELSE CASE
					WHEN (@IsSB = 1 OR @IsSaba = 1) 
						AND pt.ProductID = 1 
						AND pt.BetType NOT IN (9,29,10)
						AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
					WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
					WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
					WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
					WHEN @IsNonSport = 1 AND ProductID IN (3,5,27) THEN 1
				ELSE 0 END
			END
		AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
		AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
		AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
		AND pt.bettype NOT BETWEEN 1501 AND 1599					-- NOT IN Keno

	IF(LEN(@TransIds) > 0)
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)
	END
	
	IF(@CustID <> '')
	BEGIN
		INSERT INTO #CustId (CustId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@CustID, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)

		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@StatusIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)
		
		INSERT INTO #transIdTemp (transid)
		SELECT	b.translogid AS transid
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #CustId c ON c.CustId = b.custid
		WHERE	b.winlostdate BETWEEN @FromDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND 1 = CASE WHEN EXISTS (SELECT 1 FROM @Status_tmp WHERE statusID IN(0,1)) AND statusID = 0 THEN 1 ELSE 0 END
				AND @IsSB = 1
				
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113,122)
			)ml
			INNER JOIN #CustId c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND b.bettype NOT BETWEEN 801 AND 806-- MG
							AND  ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
	END
	
	--Search by TransIds
	IF (EXISTS(SELECT TOP 1 1 FROM #transIdTemp))
	BEGIN
		-- MG running tickets in translog
		INSERT INTO #Data(
			GroupID
			,bettype
			,transid
			,betid
			,refno	
			,hdp1
			,hdp2
			,odds
			,oddsspread
			,finalodds
			,finalodds2
			,OddsType
			,STATUS
			,comstatus
			,stake
			,transdate
			,betteam
			,betcheck
			,liveindicator	
			,modds
			,custid
			,livehomescore	
			,liveawayscore
			,betfrom
			,matchid
			,winlost
			,commission
			,winlostdate
			,TransDesc
			,betdaqid
			,username
			,recommend
			,CurrencyName
			,IsMarked	
		)
		SELECT	
			b.translogID AS GroupID
			,b.GameID
			,b.translogID as transid
			,0 AS BetID
			,b.translogID refno	
			,0 hdp1
			,0 hdp2
			,b.odds
			,0 AS oddsspread
			,0 finalodds
			,0 finalodds2
			,b.custom1 OddsType
			,b.STATUS
			,b.custom2 comstatus
			,b.stake
			,b.transdate
			,NULL betteam
			,NULL betcheck
			,b.liveindicator liveindicator
			,NULL modds
			,b.custid
			,NULL livehomescore
			,NULL liveawayscore
			,b.betfrom
			,b.EventID
			,- b.actual_stake as winlost
			,0 AS commission
			,b.winlostdate
			,b.transdesc
			,-1 -- normal ticket
			,username
			,recommend
			,b.CurrencyName
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked	
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #transIdTemp temp
			ON b.translogid = temp.transid
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.translogid = TransId
					)m
		WHERE b.winlostdate >=@FromDate
			AND b.GameID BETWEEN 801 AND 806
			AND b.statusID = 0
				
		-- bettrans tickets	
		INSERT INTO #Data (
			GroupID			
			,bettype		
			,transid		
			,betid			
			,refno		
			,hdp1			
			,hdp2			
			,odds
			,oddsspread			
			,finalodds		
			,finalodds2		
			,OddsType		
			,STATUS			
			,comstatus		
			,stake							
			,transdate		
			,betteam		
			,betcheck		
			,liveindicator	
			,modds			
			,custid						
			,livehomescore	
			,liveawayscore					
			,betfrom		
			,matchid					
			,winlost		
			,commission					
			,winlostdate	
			,TransDesc		
			,betdaqid
			,username
			,recommend
			,IsHideComm
			,oddsid
			,ExtraInfo
			,IsCashOut
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
			,ActualStake
		)
		SELECT	
			b.refno AS GroupId
			,b.bettype
			,b.transid
			,isnull(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,0 finalodds
			,0 finalodds2
			,b.OddsType
			,CASE 
				WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,CASE 
				WHEN b.comstatus = '1' THEN 1
				ELSE 0 END AS comstatus
			,b.stake
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore
			,b.betfrom
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.playercomm AS commission				
			,b.winlostdate
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend			
			,0 AS IsHideComm
			,b.oddsid
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.actual_stake AS ActualStake
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON b.custid 		= tl.custid
				AND b.refno 	= tl.translogid
				AND b.matchid 	= tl.eventid
			INNER JOIN #transIdTemp temp
			ON tl.translogid 	= temp.transid			
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE	b.winlostdate >=@FromDate				
			AND b.bettype BETWEEN 801 AND 806 
			AND b.statusID NOT IN (0, 101, 102, 103)
			
		UNION ALL
		SELECT	
			b.transid AS GroupId
			,b.bettype
			,b.transid
			,isnull(b.BetID, 0) AS BetID
			,b.refno			
			,b.hdp1
			,b.hdp2
			,b.odds
			,b.oddsspread
			,0 finalodds
			,0 finalodds2
			,b.OddsType
			,CASE 
				WHEN b.STATUS = 'running'
					AND IsNull(b.SecAcceptFlag, 0) = 1
					AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
				ELSE b.STATUS END AS STATUS
			,CASE 
				WHEN b.comstatus = '1' THEN 1
				ELSE 0 END AS comstatus
			,b.stake				
			,b.transdate
			,b.betteam
			,b.betcheck
			,b.liveindicator
			,b.modds
			,b.custid
			,b.livehomescore
			,b.liveawayscore				
			,b.betfrom
			,b.matchid				
			,(b.winlost - b.actual_stake) winlost
			,b.playercomm AS commission				
			,b.winlostdate
			,b.transdesc
			,b.betdaqid
			,b.username
			,b.recommend			
			,CASE 
				WHEN b.bettype = 501 AND b.playerdiscount < 0 THEN 1				 
				ELSE 0 
			 END AS IsHideComm
			,b.oddsid
			,b.ExtraInfo
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			,b.actual_stake AS ActualStake
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #transIdTemp temp
				ON b.transid = temp.transid
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype				
		WHERE	b.winlostdate >= @FromDate				
			AND b.bettype NOT BETWEEN 801 AND 806-- MG
			AND b.statusID NOT IN (101, 102, 103)				
	END			

	-- delete main parlay tickets
	IF(@IncludeMainParlay = 0 AND @Products IS NULL)
	BEGIN
			DELETE b FROM #Data b 
			WHERE  b.bettype IN (9, 29, 2799, 38)
	END
	
	-- update MainTransId
	IF EXISTS (SELECT TOP 1 1 FROM #Data WHERE refno IS NOT NULL)
	BEGIN
		UPDATE sub
		SET MainTransId = main.transid
		FROM #Data main
			 INNER JOIN #Data sub
					 ON main.RefCode = sub.RefCode	
						AND main.transid <> sub.transid					
						AND main.custid = sub.custid
						AND main.matchid = sub.matchid
						AND main.bettype = sub.bettype											
		WHERE main.WalletType = 1			
	  
		-- Insert more bonus or cash ticket in case only one ticket appears in #Data	
		INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, IsMarked, transid)
		SELECT RefCode, custid, matchid, bettype,IsMarked
			 , MAX(transid) AS transid
		FROM #Data
		WHERE	RefCode IS NOT NULL
		GROUP BY RefCode, custid, matchid, bettype,IsMarked
		HAVING COUNT(*) = 1
		
		IF @@ROWCOUNT > 0
		BEGIN
			INSERT INTO #Data (
					GroupID			
					,bettype		
					,transid		
					,betid			
					,refno		
					,hdp1			
					,hdp2			
					,odds			
					,finalodds		
					,finalodds2		
					,OddsType		
					,STATUS			
					,comstatus		
					,stake							
					,transdate		
					,betteam		
					,betcheck		
					,liveindicator	
					,modds			
					,custid						
					,livehomescore	
					,liveawayscore					
					,betfrom		
					,matchid					
					,winlost		
					,commission					
					,winlostdate	
					,TransDesc		
					,betdaqid
					,username
					,recommend
					,IsHideComm
					,oddsid			
					,ExtraInfo
					,IsCashOut			
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,IsMarked
					,ActualStake
				)
				SELECT	
					b.refno AS GroupId
					,b.bettype
					,b.transid
					,isnull(b.BetID, 0) AS BetID
					,b.refno			
					,b.hdp1
					,b.hdp2
					,b.odds
					,0 finalodds
					,0 finalodds2
					,b.OddsType
					,CASE 
						WHEN b.STATUS = 'running'
							AND IsNull(b.SecAcceptFlag, 0) = 1
							AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS END AS STATUS
					,CASE 
						WHEN b.comstatus = '1' THEN 1
						ELSE 0 END AS comstatus
					,b.stake
					,b.transdate
					,b.betteam
					,b.betcheck
					,b.liveindicator
					,b.modds
					,b.custid
					,b.livehomescore
					,b.liveawayscore				
					,b.betfrom
					,b.matchid				
					,(b.winlost - b.actual_stake) winlost
					,b.playercomm AS commission				
					,b.winlostdate
					,b.transdesc
					,b.betdaqid
					,b.username
					,b.recommend			
					,0 AS IsHideComm
					,b.oddsid
					,b.ExtraInfo
					,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,t.transid AS MainTransId
					,t.IsMarked
					,b.actual_stake AS ActualStake
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid					
							AND b.custid = t.custid
							AND b.matchid = t.matchid
							AND b.bettype = t.bettype
			WHERE b.statusID NOT IN (101, 102, 103) -- reject, void, refund	
		END	    			    				    					    				    					    
	END
	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #data WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventdate  = m.eventdate
		FROM #Data d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799)
	END
	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #data WHERE bettype IN (10)))
	BEGIN
		UPDATE d
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventdate  = odds.eventdate
		FROM #Data d
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	d.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE d.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #data WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE d
		SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
			,homeid 	= o.RacerID
			,awayid 	= 0
			,leagueid 	= r.leagueid
			,sporttype 	= r.sporttype
			,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113) 
			,eventdate  = o.eventdate
		FROM #Data d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE d
		SET sporttype = sb.SportType
		FROM #Data d
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON d.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	-- UPDATE Sportype, Endtime for Bitcoin 
	IF(EXISTS(SELECT TOP 1 1 FROM #Data WHERE bettype BETWEEN 7901 AND 7999))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
			,eventdate  = m.EventDate
			,EndTime    = m.EndTime
		FROM #Data d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #Data WHERE bettype IN (9,29,2799)))
	BEGIN
		UPDATE #Data
		SET eventdate = winlostdate
		WHERE bettype IN (9,29,2799)
	END
	--- Remove invalid sporttype
	DELETE 
	FROM #Data
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		)	


	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDay OUTPUT

	IF @TransIds IS NOT NULL AND EXISTS (SELECT TOP 1 1 FROM #Data WHERE eventdate <= @MovebetDay)
	BEGIN
		DELETE 
		FROM #Data
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE eventdate <= @MovebetDay
	END
		     
	-- UPDATE SiteNam
	;WITH CustSiteName AS (
		SELECT DISTINCT ag.custid, ci.site, ci.srecommend, ci.mrecommend
		FROM CUSTDB.dbo.Customer ci WITH(NOLOCK)
			INNER JOIN #Data ag
			ON ci.custid = ag.recommend
		
	)
	--format group
	, CTE_GroupInfo AS (
		SELECT DISTINCT d.custid
			,cs.mrecommend
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit
			,CASE 
				WHEN (
					d.recommend NOT IN (52466, 5707545)
					AND d.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
					AND s.custid IS NULL					
				) THEN '0-Credit'
				WHEN d.recommend IN (52466, 5707545) THEN '1-8RM/BARM'
				WHEN (
					d.recommend NOT IN (52466, 5707545)
					AND d.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
					AND s.custid IS NOT NULL					
				) THEN '2-Deposit'
				WHEN d.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) 					 
				  THEN '3-BetFair'				
			END AS GroupName
		FROM #Data d
			INNER JOIN CustSiteName cs 
			ON d.custid = cs.custid
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK) 
			ON cs.srecommend = s.custid
	)

	-- ALL tickets	
	SELECT
		CASE WHEN d.bettype BETWEEN 801 AND 899 THEN d.refno ELSE d.transid END AS transid
		,d.bettype
		,d.betid
		,d.refno
		,d.matchcode
		,d.homeid
		,d.awayid
		,d.hdp1
		,d.hdp2
		,d.odds
		,d.oddsspread
		,d.finalodds
		,d.finalodds2
		,d.OddsType
		,d.STATUS
		,d.comstatus
		,d.stake
		,d.transdate
		,d.betteam
		,d.betcheck
		,d.liveindicator
		,d.modds
		,d.custid
		,d.username
		,d.livehomescore
		,d.liveawayscore
		,d.leagueid
		,d.sporttype
		,d.betfrom
		,d.matchid
		,d.isNeutral
		,d.winlost
		,d.commission
		,d.showtime
		,d.winlostdate
		,d.TransDesc
		,d.IsHideComm
		,g.IsDeposit
		,SUBSTRING(T.GroupName, 3, 30) AS GroupName
		,d.betdaqid
		,d.ExtraInfo
		,d.IsCashOut
		,d.CurrencyName
		,d.WalletType	    
	    ,d.MainTransId
	    ,FollowInfo.transid AS followedId
		,FollowInfo.Username AS followedUsername
		,d.RefCode
		,c.site AS LicenseeName
		,m.SettlementStatus
		,d.IsMarked
		,m.GlobalShowTime
		,c.custid
		,d.ActualStake
		,d.EndTime 
	FROM #Data d
		INNER JOIN CTE_GroupInfo g ON d.custid = g.custid
		INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON d.recommend = c.custid
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = d.matchid
		OUTER APPLY (SELECT CASE 
								WHEN d.betfrom = 'p' THEN '4-Phone Betting'
								ELSE g.GroupName
							END AS GroupName) AS T
		OUTER APPLY (SELECT TOP 1 transid, username
					 FROM bettrans (NOLOCK)
					 WHERE transid = d.betid					   
					   AND T.GroupName = '1-8RM/BARM') AS FollowInfo							
		
	WHERE NOT EXISTS (
			SELECT TOP 1 1 
			FROM  dbo.[f_GetBetDaqCustomer] (1) 
			WHERE custid = d.custid
		) --betdaq
		AND d.username 		<> '12EU'
		AND g.mrecommend 	NOT IN (105181, 118473, 105183) --MHC
		AND d.recommend 	NOT IN (11196380) --Foobet
		AND d.recommend 	NOT IN (13423967) --OneExchange
	ORDER BY T.GroupName
		   , ISNULL(d.MainTransId, d.transid)
		   , CASE 
				WHEN d.BonusID IS NOT NULL
						THEN CASE 
								WHEN d.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE d.transid
			 END	

	;WITH t_invalid AS
	(
		SELECT	transid
				,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
		FROM #transIdTemp temp
			OUTER APPLY (
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM dbo.bettrans14 WITH(NOLOCK) 
				WHERE transid = temp.transid
				UNION ALL
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM @tmpTransIdMoveBet m  
				WHERE m.transid = temp.transid
			) bm
		WHERE NOT EXISTS (SELECT 1 
						  FROM #Data 
						  WHERE transid = temp.transid 
						     OR refno = temp.transid)
	)
	SELECT @InvalidTransIds = @InvalidTransIds +
							  CASE
								  WHEN isMoved = 0
										THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + 
											 CAST(transid AS VARCHAR(100))
								  ELSE ''
							  END								  
		 , @MovedTransIds = @MovedTransIds +
							CASE
								WHEN isMoved = 1
										THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + 
											 CAST(transid AS VARCHAR(100))
								ELSE ''
							END
		FROM t_invalid
	RETURN;
END
GO