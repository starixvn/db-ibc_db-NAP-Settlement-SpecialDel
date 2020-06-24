/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidBetIdList_Sel] @CustID            INT          = NULL,
                                                            @TransIds          VARCHAR(MAX) = NULL,
                                                            @FromDate          DATETIME     = NULL,
                                                            @ToDate            DATETIME     = NULL,
                                                            @IncludeMainParlay BIT          = 0,
                                                            @InvalidTransIds   VARCHAR(MAX) = '' OUTPUT,
                                                            @MovedTransIds     VARCHAR(MAX) = '' OUTPUT
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
	Param's Explanation:
		+ @CustID NOT NULL: Search by CustID
		+ @TransIds NOT NULL: Search by TransID

	*/
BEGIN
	SET NOCOUNT ON
	
	IF(@custid IS NULL AND @TransIds IS NULL) RETURN
	
	DECLARE @moveBetDay 	SMALLDATETIME	
	
	SELECT @moveBetDay = MAX(winlostdate) 
	FROM dbo.bettrans14 WITH(NOLOCK)
	
	SELECT @FromDate	= ISNULL(@FromDate, @moveBetDay)
		, @FromDate 	= CASE WHEN @FromDate <= @moveBetDay THEN DATEADD(d, 1, @moveBetDay) ELSE @FromDate END
		, @ToDate 		= ISNULL(@ToDate, DATEADD(d, 90, @moveBetDay))
	
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	
	CREATE TABLE #tempMatch (matchid INT)
	
	CREATE TABLE #Data
             (GroupID               BIGINT,
              bettype               INT,
              OriginalBetType       SMALLINT,
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
              SoldId                BIGINT,
              recommend             INT,
              IsHideComm            BIT DEFAULT(0),
              oddsid                INT,
              ExtraInfo             VARCHAR(1000),
              IsCashOutMemberTicket BIT DEFAULT 0,
              MainCashoutId         BIGINT,
              CurrencyName          NVARCHAR(50),
              WalletType            TINYINT,
              RefCode               BIGINT,
              BonusID               INT,
              MainTransId           BIGINT,
			  IsMarked			 BIT
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
	
	IF(LEN(@TransIds) > 0)
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)
	END
	
	IF(@custid > 0)
	BEGIN
		INSERT INTO #transIdTemp (transid)
		SELECT	b.translogid AS transid
		FROM	dbo.translog AS b WITH (NOLOCK)
		WHERE	b.custid = @Custid 
				AND b.winlostdate BETWEEN @FromDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
		FROM dbo.bettrans AS b WITH (NOLOCK)
		WHERE	b.custid = @Custid 
			AND b.winlostdate BETWEEN @FromDate AND @ToDate 
			AND 1 = CASE 
				WHEN (b.bettype BETWEEN 801 AND 806 AND b.statusID NOT IN (0, 101, 102)) THEN 1 
				WHEN (b.bettype < 19001
						AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
						AND b.bettype NOT BETWEEN 801 AND 806-- MG
						AND b.bettype NOT IN (901, 902, 903, 904) -- BT subticket
						AND b.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
						AND b.bettype NOT BETWEEN 1501 AND 1599					-- NOT IN Keno
						AND b.statusID NOT IN (101, 102)						
					) THEN 1
				ELSE 0 END			
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
			,MainCashoutId
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,IsMarked
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
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
				ELSE NULL END AS MainCashoutId
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
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
		WHERE	b.winlostdate >=@FromDate				
			AND b.bettype BETWEEN 801 AND 806 
			AND b.statusID NOT IN (0, 101, 102)
			
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
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
			 END AS MainCashoutId
			,b.CurrencyName
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
		FROM dbo.bettrans AS b WITH (NOLOCK)
			INNER JOIN #transIdTemp temp
				ON b.transid = temp.transid
			OUTER APPLY (
						SELECT TOP (1) TransId
						FROM dbo.MarkedTransaction WITH(NOLOCK) 
						WHERE b.transid = TransId
					)m				
		WHERE	b.winlostdate >= @FromDate				
			AND b.bettype < 19001
			AND b.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND b.bettype NOT BETWEEN 801 AND 806-- MG
			AND b.bettype NOT IN (901, 902, 903, 904) -- BT subticket
			AND b.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
			AND b.bettype NOT BETWEEN 1501 AND 1599					-- NOT IN Keno
			AND b.statusID NOT IN (101, 102)				
	END		
	
	-- delete cash-out member bet tickets
	DELETE t
	FROM #Data t
	WHERE EXISTS (SELECT TOP 1 1
				  FROM bettrans sub911 (NOLOCK)
				  WHERE sub911.bettype = 911
				    AND sub911.transid = t.refno)	

	-- delete main parlay tickets
	IF(@IncludeMainParlay = 0)
	BEGIN
		DELETE b
		FROM #Data b
		WHERE b.bettype IN (9, 29, 2799, 38)
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
					,MainCashoutId			
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,IsMarked
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
					,CASE
						WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
								THEN b.transid
						ELSE NULL
					 END AS MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,t.transid AS MainTransId
					,t.IsMarked	
			FROM #tmpRefCodeSummary t
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON b.RefCode = t.RefCode
							AND b.transid <> t.transid					
							AND b.custid = t.custid
							AND b.matchid = t.matchid
							AND b.bettype = t.bettype
			WHERE b.statusID NOT IN (101,102 ) -- reject, void		
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
			
		FROM #Data d
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON d.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
			
		WHERE d.bettype IN (1231,1232,1233,1237,1238)
	END
	-- UPDATE Sportype for NPH Promotion (bettype = 17000)
	IF(EXISTS(SELECT TOP 1 1 FROM #data WHERE bettype IN (17000)))
	BEGIN
		UPDATE d
		SET sporttype 	= d.matchid
		FROM #Data d
		WHERE d.bettype IN (17000)
	END

	--- Remove invalid sporttype	
	DELETE 
	FROM #Data
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		)	
		
	INSERT INTO #tempMatch(matchid)
	SELECT DISTINCT matchid
	FROM #Data
	
	-- get sub ticket of BetTrade (901)
	IF(EXISTS (SELECT TOP 1 1 
			   FROM #Data 
			   WHERE betdaqid = 0 
			     AND extrainfo is null))
	BEGIN
		WITH CTE_LastTransBT AS (
			SELECT 
				sub.refno
				, sub.transId
				, sub.betid
				, sub.transdate
				, sub.custid
				, sub.winlost 
				, sub.actual_stake
				, sub.username
				, sub.recommend
				, sub.matchid
				, sub.bettype
				, sub.betdaqid
				, sub.ExtraInfo
				, sub.WalletType
				, sub.RefCode
				, sub.BonusID
				, main.transid AS MainTransId
				, ROW_NUMBER() OVER (PARTITION  BY sub.refno ORDER BY sub.transId DESC ) AS BTNo 
				
			FROM dbo.bettrans sub WITH(NOLOCK)
				INNER JOIN #tempMatch tm 
					ON sub.matchid 	= tm.matchid
				INNER JOIN #Data main
					ON	sub.refno 	= main.transid 
					AND sub.matchid = main.matchid
				
			WHERE sub.bettype 		= 901
				AND sub.statusID 	IN (111,112,113,103) --WON/LOSE/DRAW/REFUND
				AND main.betdaqid	= 0
				AND main.extrainfo is null
		)
		INSERT INTO #Data(
			GroupID			
			,bettype
			,OriginalBetType		
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
			,matchcode
			,homeid
			,awayid
			,leagueid
			,sporttype
			,IsNeutral
			,showtime
			,ExtraInfo			
			,IsHideComm
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,IsMarked
		)
		SELECT	
			main.transid
			,sub.bettype
			,main.bettype AS OriginalBetType
			,sub.transid
			,main.bettype AS betid
			,sub.refno
			,main.hdp1
			,main.hdp2
			,main.odds
			,main.oddsspread
			,main.finalodds
			,main.finalodds2
			,main.OddsType
			,'SOLD'
			,main.comstatus
			,main.stake			
			,sub.transdate
			,main.betteam
			,main.betcheck
			,main.liveindicator
			,main.modds
			,sub.custid
			,main.livehomescore
			,main.liveawayscore
			,main.betfrom
			,main.matchid
			,sub.winlost - sub.actual_stake
			,main.commission
			,main.winlostdate
			,main.TransDesc
			,sub.betdaqid
			,sub.username
			,sub.recommend
			,main.matchcode
			,main.homeid
			,main.awayid
			,main.leagueid
			,main.sporttype
			,main.IsNeutral
			,main.showtime
			,sub.ExtraInfo						
			,1 AS IsHideComm
			,main.CurrencyName
			,sub.WalletType
			,sub.RefCode
			,sub.BonusID
			,sub.MainTransId
			,main.IsMarked
		FROM CTE_LastTransBT sub WITH(NOLOCK)
			INNER JOIN #Data main
			ON	sub.refno 	= main.transid 
			AND sub.matchid = main.matchid
		WHERE sub.BTNo = 1
		
		-- update SoldId column: if main ticket is BT, update SoldId = transid of subticket(901)
		;WITH CTE_BetTradeSold AS (
			SELECT transid
				, refno
				, matchid
			FROM #Data
			WHERE STATUS = 'SOLD'
		)
		UPDATE	main
		SET main.SoldId = bt.transid
		FROM #Data main 
			INNER JOIN CTE_BetTradeSold bt
			ON main.transId 	= bt.refno
			AND main.matchid 	= bt.matchid
					
		WHERE main.betdaqid = 0 -- main ticket is BTrade
		  AND main.extrainfo is null
	END				
	
	-- get sub ticket of Cash-out (911) and cash-out member bet tickets
	IF(EXISTS (SELECT TOP 1 1 
			   FROM #Data 
			   WHERE betdaqid = 0 
			     AND charindex ('p25',extrainfo)> 0	))
	BEGIN
		-- get sub ticket of Cash-out (911)	
		INSERT INTO #Data(
			GroupID			
			,bettype
			,OriginalBetType		
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
			,matchcode
			,homeid
			,awayid
			,leagueid
			,sporttype
			,IsNeutral
			,showtime
			,ExtraInfo
			,MainCashoutId
			,IsHideComm
			,CurrencyName
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,IsMarked
		)
		SELECT  sub911.transid
				,sub911.bettype
				,main.bettype AS OriginalBetType
				,sub911.transid
				,main.bettype AS betid
				,sub911.refno
				,main.hdp1
				,main.hdp2
				,main.odds
				,main.oddsspread
				,main.finalodds
				,main.finalodds2
				,main.OddsType
				,'Cash out'
				,main.comstatus
				,sub911.stake			
				,sub911.transdate
				,main.betteam
				,main.betcheck
				,main.liveindicator
				,main.modds
				,sub911.custid
				,main.livehomescore
				,main.liveawayscore
				,main.betfrom
				,main.matchid
				,sub911.winlost - sub911.actual_stake
				,main.commission
				,main.winlostdate
				,main.TransDesc
				,sub911.betdaqid
				,sub911.username
				,sub911.recommend
				,main.matchcode
				,main.homeid
				,main.awayid
				,main.leagueid
				,main.sporttype
				,main.IsNeutral
				,main.showtime
				,sub911.ExtraInfo
				,main.transid AS MainCashoutId
				,1 AS IsHideComm
				,sub911.CurrencyName
				,sub911.WalletType
				,sub911.RefCode
				,sub911.BonusID
				,main.transid AS MainTransId
				,main.IsMarked
		FROM #Data main
			 INNER JOIN dbo.bettrans sub911 WITH(NOLOCK)
					 ON main.transid = sub911.refno
						AND sub911.matchid = main.matchid	
						AND sub911.custid = main.custid	
						AND main.betdaqid = 0
						AND charindex ('p25',main.extrainfo)> 0	
						AND sub911.bettype = 911			 
		WHERE sub911.statusID IN (111,112,113,103) --WON/LOSE/DRAW/REFUND								 						
		
		-- get cash-out member bet tickets
		INSERT INTO #Data (
			GroupID			
			,bettype
			,OriginalBetType		
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
			,oddsid
			,ExtraInfo
			,IsCashOutMemberTicket
			,MainCashoutId
			,matchcode
			,homeid
			,awayid
			,leagueid
			,sporttype
			,IsNeutral
			,showtime	
			,IsHideComm	
			,CurrencyName	
			,WalletType
			,RefCode
			,BonusID
			,MainTransId
			,IsMarked	
		)
		SELECT  sub911.transid AS GroupId
				,b.bettype
				,sub911.OriginalBetType
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
					ELSE b.STATUS
					END AS STATUS
				,CASE 
					WHEN b.comstatus = '1' THEN 1
					ELSE 0
					END AS comstatus
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
				,b.oddsid
				,b.ExtraInfo
				,1 AS IsCashOutMemberTicket
				,sub911.MainCashoutId
				,sub911.matchcode
				,sub911.homeid
				,sub911.awayid
				,sub911.leagueid
				,sub911.sporttype
				,sub911.IsNeutral
				,sub911.showtime
				,1 AS IsHideComm
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,sub911.MainTransId
				,sub911.IsMarked
		FROM #Data sub911
			 CROSS APPLY (
							  SELECT b.bettype
									,b.transid
									,b.BetID
									,b.refno			
									,b.hdp1
									,b.hdp2
									,b.odds
									,b.oddsspread
									,b.OddsType
									,b.STATUS
									,b.SecAcceptFlag
									,b.checktime
									,b.comstatus
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
									,b.winlost
									,b.actual_stake
									,b.playercomm				
									,b.winlostdate
									,b.transdesc
									,b.betdaqid
									,b.username
									,b.recommend				
									,b.oddsid
									,b.ExtraInfo
									,b.CurrencyName
									,b.WalletType
									,b.RefCode
									,b.BonusID
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101) -- VOID, REJECT
						 ) AS b
		WHERE sub911.bettype = 911
	END				     
		
	-- UPDATE SiteName
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
		,d.OriginalBetType
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
		,d.SoldId
		,d.IsHideComm
		,g.IsDeposit
		,SUBSTRING(T.GroupName, 3, 30) AS GroupName
		,d.betdaqid
		,d.ExtraInfo
		,d.MainCashoutId
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

	-- invalid trans
	SELECT @InvalidTransIds = '', @MovedTransIds = ''
	;WITH t_invalid AS
	(
		SELECT	transid
				,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
		FROM #transIdTemp temp
			OUTER APPLY (
				SELECT TOP 1 CAST(1 AS BIT) AS isMoved
				FROM dbo.bettrans14 WITH(NOLOCK) 
				WHERE transid = temp.transid
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