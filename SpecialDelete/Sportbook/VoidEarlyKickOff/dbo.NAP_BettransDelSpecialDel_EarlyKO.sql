/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransDelSpecialDel_EarlyKO]   
	 @MatchId			INT  
	,@KickOffDate		DATETIME  
	,@BetTypes			XML			 = NULL  	
	
	,@TransIds			VARCHAR(MAX) = ''  
	,@TransIdSolds		VARCHAR(MAX) = '' -- just for BetTrade's subticket (transid of bettype 901)		
	
	,@InvalidTransIds   VARCHAR(MAX) = '' OUTPUT -- invalid trans of BTrade  

	,@UserID			INT  
	,@UserName			NVARCHAR(50)  
	,@UserPassword		NVARCHAR(50)  
	,@Reason			NVARCHAR(500) = '' 
	,@ReasonSC			NVARCHAR(500) = ''
	,@IP				VARCHAR(15)	  = ''  
	,@ErrMsg			NVARCHAR(200) = '' OUTPUT  
	,@ErrCode			INT			  = 0  OUTPUT  
AS  
/*  
Created by: Kathy  
Date: 20131125  
Task : Void ticket information for early kickoff  
DB: DBTXN/bodb02  
Original: Acc_BettransDelSpecialDel_EarlyKO  

Revisions:  
	- 20140102@Kathy: Add username2 column [Redmine:#10270]  
	- 20140121@Elodie: Apply LAS system for special delete function [Redmine:#10701]  
	- 20140411@Kathy: Separate tickets of Bet Fair, OneExchange 3rd parties [Redmine:#10128]  
		- Add 2 new bettypes 1H Total Goal and 1H First Goal/ Last Goal (126, 127) [Redmine:#14749]  
	- 20140701@Kathy: Apply BetRadar - change @BetTypes to varchar(1000) [Redmine:#18219]  
	- 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]    
	- 20140806@Kathy: Support new 11 bettypes [Redmine:#19955]  
	- 20140929@Kathy: - Offer new bettypes from Sportting Solutions and new IBC bettypes [Redmine:#23129]  
		- Add moneyline in filter  
	- 20141112@Kathy: correct creator value used to send email  
	- 20141125@Kathy: Add betid column [Redmine:##26489]  
	- 20141204@Kathy: Remove codes which are used in checking permission on DBPolicy [Redmine:#27058]   
	- 20150402@Dominic: Add new 60 bettypes [Redmine:#27214]  
	- 20150615@Dominic: BetTrade Integration  [Redmine:#36964]  
	- 20150623@Dominic: Add Metric Gaming Super Live [Redmine:##38200]  
	- 20150806@Kathy: Using new balance table (BalCreditSportsPending,BalDebitSportsPending) [Redmine:#40125]  
	- 20150917@Patrick: #43565: Show error-message in case user clicks void button but no tickets are found    
	- 20151008@Kathy: insert bettrade tickets to send API [Redmine:#43233]  
	- 20151021@Kathy: Do not show ticket 901 if its owner is not BetTrade account(betdaqid = 0)[Redmine:#43233]  
	- 20151102@Kathy: Enhance performance [Redmine:#43233]  
	- 20151202@Kathy: add modds column   
	- 20151209@Kathy: get translog.siteid for MG API [Redmine:#49019]  
	- 20151207@Kathy: - Apply 28 Live Bettypes(PH) [Redmine: #48110]  
		- Database - Change datatype [Redmine: #48660]  
	- 20150119@Kathy: Changes for phase 1.2 of PH All in One: bettype 4,30,413,414,405 [Redmine:#50932]            
	- 20160202@Kathy: change datatype of Username2 from nvarchar(30) to nvarchar(50)  
	- 20160112@Patrick: Support Cricket [Redmine: #50688]  
	- 20160401@Bobby: #55354 - Update changes for new message structure  
	- 20160426@Bobby: #56641 - Integrate Fast Market bettypes
	- 20160705@Bobby: #60327 - Fix bug - Wrong using of bettype list in sp input for checking match lock process  
	- 20160420@Kathy: - Apply new settlement SP [Redmine:#56306]  
						- Add bettrans.betcheck column to support Combo Parlay [Redmine:#55272]  
	- 20160722@Bobby: #61240 - Implement parent-child for PHAIO new 19 bet types
	- 20160728@Kathy: Using non clustered index PK_bettrans to settle [Redmine:#61193]
	- 20160810@Bobby: #62223 - Apply new business terms for VOID bet function
	- 20160909@Kent: Add logic for bettype 425, 426, 429 - PH AIO [Redmine:#62880]
	- 20161010@Kathy: Wrong checking process of parlay [Redmine:#63202]
	- 20161101@Elodie: #56641 - Integrate Fast Market new bettypes
	- 20161110@Kent: Exclude the list of voided main refno when calling the cal 29 from special delete side [Redmine:#65531]
	- 20161221@Kathy: Release lock after voiding tickets [Redmine:#68960]
	- 20170220@Kent: Add logic of new bettypes in BAIO [Redmine:#71536]
	- 20170301@Kent: Return dummy tables for exceptional return cases [Redmine:#71536]
	- 20170313@Kent: Integrate cash-out [Redmine:#72059]
	- 20170417@Kent: Tune performance [Redmine:#72059]
	- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
	- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
	- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
	- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
	- 20170503@Kent: Integrate bonus [Redmine:#72790]
	- 20171127@Kent: Integrate BullFighting [Redmine:#86832]
	- 20180312@Helen: Metric Gaming hotfix [Redmine:91543]
	- 20180306@Kathy: get Refcode value [Redmine:#91461]
	- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
	- 20180301@Benjamin: Add oddsspread and Remove DateTime Column- Fast Markets Phase 2 [Redmine:#90667]
	- 20180507@Benjamin: Correct actual_stake: 0 when INSERT TO BETTRANS[Redmine: #94603]
	- 20180508@Alan: Change result for new template email - Delete Creator [Redmine:#93296]
	- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
	- 20181017@Alan: Write log new reason chinese simplified [102918]
	- 20181004@Alan: Add new column SettlementStatus [102423]
	- 20180821@Alan: Incorporate ESports 2.0 [99448]
	- 20190419@Kathy: Mark Ticket for Settlement Exclusion [Redmine:#108826]
	- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]
	- 20190718@Charles: Drop table #CTE_CustInfo [115870]
	- 20190301@Alan: Implement Bet Builder - [106898]
	- 20190812@Charles: Add new column IsMarked [118437]

Param's Explanation: Special bet delete option  
		- @BetTypes : 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ; Additional handled field : TimeInterval
					 Goal="2"				-- Default : "All" ; Format : Single Number
			/>
		 <BetTypes/>'
*/  
BEGIN  
	SET NOCOUNT ON 		 

	DECLARE @eventdate DATETIME 
		,@LogData NVARCHAR(500)     
		,@Remark VARCHAR(500) 
		,@CountTransId	INT 
	 
	DECLARE @isExistMatch		BIT = 0  
			,@isExistMG			BIT = 0 
		, @isExistFM  BIT = 0 
			,@isExistParlay		BIT = 0  
			,@avaiableProcess	BIT = 0  
			,@isExistBT			BIT = 0 
			,@isExistCashOut	BIT = 0
			,@IsExistBB			BIT = 0
		
	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	 	 
	
	CREATE TABLE #tblBetType
	(
		Id				SMALLINT,		 				
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,	
		TimeInterval	SMALLMONEY,	
		Goal			BIGINT
	)   

	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)  

	CREATE TABLE #tblTransIdSolds (grouptransid BIGINT, transid BIGINT PRIMARY KEY)  

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)  

	CREATE TABLE #BetDelete (  
		grouptransid BIGINT  
		,transid BIGINT  
		,refno  BIGINT  
		,betid  BIGINT  
		,stake  MONEY  
		,odds  MONEY  
		,oddsspread		MONEY
		,custid  INT  
		,recommend INT  
		,mrecommend INT  
		,srecommend INT  
		,betfrom NVARCHAR(1)  
		,STATUS  VARCHAR(20)  
		,statusID INT  
		,creator INT  
		,Bettype SMALLINT 
		,OriginalBetType SMALLINT 
		,betdaqid BIGINT  
		,creatorName NVARCHAR(50)  
		,username  NVARCHAR(50)  
		,username2  NVARCHAR(50)  
		,OddsType  TINYINT  
		,Transdate  DATETIME  
		,betteam  NVARCHAR(10)  
		,hdp1   SMALLMONEY  
		,hdp2   SMALLMONEY  
		,currencyName NVARCHAR(50)  
		,betcheck  NVARCHAR(50)  
		,transdesc  NVARCHAR(1000) 
		,ExtraInfo VARCHAR(1000) 
		,IsCashOutMemberTicket BIT DEFAULT 0
		,MainCashoutId BIGINT
		,awinlost MONEY
		,matchid INT
		,WalletType TINYINT
		,RefCode BIGINT
		,BonusID INT
		,MainTransId BIGINT
		,IsMarked BIT
	)

	CREATE TABLE #tmpRefCodeSummary (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,IsMarked	BIT
	)

	CREATE INDEX IX_BetDelete_RefCode ON #BetDelete(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)	

	CREATE TABLE #BetmDelete (  
		transid   BIGINT  
		,refno   BIGINT  
		,custid   INT  
		,recommend  INT  
		,mrecommend  INT  
		,srecommend  INT  
		,odds   MONEY  
		,oddsspread		MONEY
		,choiceodds  MONEY  
		,OddsType   TINYINT  
		,Transdate   DATETIME  
		,Bettype  SMALLINT  
		,ParlayType  SMALLINT  
		,betteam  NVARCHAR(10)  
		,choicebetteam  NVARCHAR(10)  
		,choicehdp1  SMALLMONEY  
		,choicehdp2  SMALLMONEY  
		,hdp1   SMALLMONEY  
		,hdp2   SMALLMONEY  
		,creatorname NVARCHAR(50)  
		,username  NVARCHAR(50)  
		,username2  NVARCHAR(50)  
		,stake   MONEY  
		,currencyName NVARCHAR(50)  
		,choiceBetCheck  NVARCHAR(50)  
		,betcheck  NVARCHAR(50)  
		,maintransid BIGINT  
		,betfrom  NVARCHAR(1)  
		,STATUS   VARCHAR(20)  
		,statusid  TINYINT  
		,creator  INT  
		,modds   MONEY  
		,transdesc  NVARCHAR(1000)
		,mainstatusID INT  
	)  

	DECLARE @Status TABLE (statusID TINYINT)  
	DECLARE @tblInvalidTrans TABLE (transid BIGINT) -- store invalid BT transid  
	DECLARE @tblCustBT902 TABLE (custid INT) --store BT's custid 
	DECLARE @tblCustCashOut912 TABLE (custid INT) --store Cash-Out's custid 
	
	CREATE TABLE #CashOutSubTicket
	(
		transid				BIGINT PRIMARY KEY,
		bettype				SMALLINT,
		OriginalBetType		SMALLINT,
		MainCashoutId		BIGINT,
		matchid				INT,
		MainTransId			BIGINT
	) -- store 911,912,913		
	
	SELECT @ErrCode = 0  
		 , @ErrMsg = ''
		 , @InvalidTransIds = ''

	DECLARE @SettlementStatus TINYINT = NULL
			,@GlobalShowTime SMALLDATETIME

	SELECT @eventdate = m.eventdate 
		,@SettlementStatus = m.SettlementStatus 
		,@GlobalShowTime = m.GlobalShowTime
	FROM dbo.match m WITH (NOLOCK)  
	WHERE matchid = @matchid  

	IF NOT EXISTS (  
		SELECT 1  
		FROM custDB.dbo.customer WITH (NOLOCK)  
		WHERE userpwd = @UserPassword  
		AND custid = @UserID  
		AND roleid >= 5  
	)  
	BEGIN  
		SELECT @LogData = 'fail to void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' because of early kick off at ' + CAST(@KickOffDate AS VARCHAR(30)) + ' reason: ' + @reason  

		EXEC WriteLog_UserLog   
		@UserID = @UserID  
		,@Doing = @LogData  

		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'  
		,@ErrCode = 101				 

		RETURN  
	END  

	IF EXISTS (  
		SELECT 1  
		FROM dbo.match WITH (NOLOCK)  
		WHERE matchid = @matchid  
		AND eventstatus = 'completed'  
	)  
	BEGIN  
		SELECT @ErrCode = 100  
		,@ErrMsg = 'You can not void completed match.'				 

		RETURN  
	END  

	BEGIN TRY  
		INSERT INTO #tblTransIds (transid)  
		SELECT DISTINCT val   
		FROM dbo.f_SplitString(@TransIds,',') 
		OPTION (maxrecursion 0)  
		
		SET @CountTransId = @@ROWCOUNT 

		IF ISNULL(@TransIdSolds,'') <> ''  
		INSERT INTO #tblTransIdSolds(grouptransid, transid)  
		SELECT  refno, transid  
		FROM dbo.bettrans sub WITH(NOLOCK)  
		WHERE transid IN (SELECT val FROM dbo.strSplit(@TransIdSolds,','))  
		 AND bettype = 901  
	END TRY  
	BEGIN CATCH  
		SELECT @ErrCode = 101  
		,@ErrMsg = 'Invalid TransIds.'				  

		RETURN  
	END CATCH  

	-- Parse xml @BetTypes
	;WITH CTE_ParsedBettypes_1 AS
	(	
		SELECT t.c.value('@Id','SMALLINT') AS Id
			 , t.c.value('@BetTeam','NVARCHAR(MAX)') AS BetTeam		-- check columns : betteam		 ; multi-choice	 
			 , t.c.value('@Set','VARCHAR(10)') AS [Set]				-- check columns : betid		 ; single-choice
			 , t.c.value('@Game','VARCHAR(3)') AS Game				-- check columns : betid		 ; single-choice
			 , t.c.value('@BetOption','NVARCHAR(250)') AS BetOption	-- check columns : hdp2, betteam ; multi-choice	 
			 , t.c.value('@Value','VARCHAR(500)') AS [Value]		-- check columns : hdp1, hdp2	 ; single-choice + multi-choice
			 , t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.val AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.val AS BetOption
			 , CAST(CASE
						WHEN v.val = 'ALL' THEN 9999.00 
						ELSE v.val
					END AS SMALLMONEY) AS [Value]			 
			 , CAST(CASE 
						WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal
					END AS BIGINT) AS Goal
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY dbo.strSplit(cte.betteam, ',') bt
			 CROSS APPLY dbo.strSplit(cte.BetOption, ',') bop
			 CROSS APPLY dbo.strSplit(cte.[Value], ',') v
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], TimeInterval, Goal)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.BetOption
		 , CAST(CASE WHEN (cte.Id NOT BETWEEN 221 AND 227) AND (cte.Id NOT IN (479, 481)) THEN cte.[Value]
					ELSE 9999.00 END AS SMALLMONEY) AS [Value]
		 , CAST(CASE WHEN (cte.Id BETWEEN 221 AND 227) OR (cte.Id IN (479, 481)) THEN cte.[Value]
					ELSE 9999.00 END AS SMALLMONEY) AS TimeInterval
		 , cte.Goal
	FROM CTE_ParsedBettypes cte	
	WHERE CASE
				WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
				ELSE 1
		  END = 1
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))

	BEGIN --SD checking process  
	SELECT @isExistMatch  = MAX (CASE WHEN b.Bettype NOT IN (29, 38) 
										AND b.Bettype NOT BETWEEN 801 AND 806 
										AND b.bettype NOT BETWEEN 221 AND 227
									THEN 1 ELSE 0 END)  
			
		,@isExistFM  = MAX (CASE WHEN b.Bettype BETWEEN 221 AND 227 THEN 1 ELSE 0 END)  
			,@isExistBB		= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
	FROM dbo.bettrans b WITH (NOLOCK)  
		INNER JOIN #tblTransIds t ON t.transid = b.transid  
		INNER JOIN #tblBettype tp ON tp.Id = b.bettype  
		WHERE b.matchid = @matchid  

	IF (ISNULL(@isExistMG, 0) = 0   
		AND EXISTS (SELECT 1 FROM #tblBettype WHERE Id BETWEEN 801 AND 899 )  
	)  
	BEGIN  
		SELECT TOP 1 @isExistMG  = 1  
		FROM dbo.translog b WITH(NOLOCK)  
			INNER JOIN #tblTransIds t   
			ON t.transid = b.translogid  
			INNER JOIN #tblBettype tp   
			ON tp.Id = b.gameid  
		WHERE b.eventid = @matchid  
			AND b.gameid BETWEEN 801 AND 899  
	END  

	IF(EXISTS (SELECT 1 FROM #tblBettype WHERE Id IN(9,29)))    
	BEGIN  
		SELECT TOP 1 @isExistParlay = 1  
		FROM dbo.bettransm AS sub WITH (NOLOCK)  
			INNER JOIN dbo.bettrans AS main WITH (NOLOCK)  
			ON sub.refno = main.refno  
			INNER JOIN #tblTransIds t   
			ON t.transid = sub.transid  
		WHERE main.matchid  IN (9, 29)  
			AND main.bettype IN (9, 29)  
			AND sub.matchid  = @matchid  
	END  

	INSERT INTO #tblMatchProcess(matchid, KeyID)  
	SELECT @matchid AS matchid, 1 AS KeyID WHERE @isExistMatch = 1  
	UNION ALL  
	SELECT @matchid AS matchid, 3 AS KeyID WHERE @isExistMG = 1  
	UNION ALL  
	SELECT @matchid AS matchid, 6 AS KeyID WHERE @isExistFM = 1  
	UNION ALL
	SELECT @matchid AS matchid, 5 AS KeyID WHERE @isExistBB = 1  

	-- check and not allow attempt to void tickets of this match while it's being calculated  
	EXEC dbo.NAP_Admin_CheckingProcess  
		@isExistParlay		= @isExistParlay  
		, @isExistMG		= @isExistMG  
		, @isExistFM  = @isExistFM  
		, @isExistMatch		= @isExistMatch  
		, @isExistBB		= @isExistBB
		, @avaiableProcess  = @avaiableProcess OUTPUT  
		, @ErrCode			= @ErrCode OUTPUT  
		, @ErrMsg			= @ErrMsg OUTPUT  

	IF(@ErrCode <> 0 OR @avaiableProcess = 0)   
	BEGIN		
		RETURN  
	END
	END -- end SD checking process		

	------------------***** Insert all data into #BetDelete,#BetmDelete *****------------------    
	INSERT INTO #BetDelete (  
		grouptransid  
		,transid  
		,refno  
		,betid  
		,stake  
		,odds  
		,oddsspread
		,custid  
		,recommend  
		,mrecommend  
		,srecommend  
		,betfrom  
		,STATUS  
		,statusID  
		,creator  
		,Bettype     
		,betdaqid  
		,OddsType    
		,Transdate    
		,betteam        
		,hdp1     
		,hdp2     
		,currencyName  
		,betcheck    
		,transdesc
		,ExtraInfo 
		,MainCashoutId
		,awinlost 
		,WalletType
		,RefCode
		,BonusID
		,IsMarked
	)  
	SELECT   
		b.transid AS grouptransid  
		,b.transid  
		,b.refno  
		,b.betid  
		,b.stake  
		,b.odds  
		,b.oddsspread
		,b.custid  
		,b.recommend  
		,b.mrecommend  
		,b.srecommend  
		,b.betfrom  
		,b.STATUS  
		,b.statusID  
		,b.creator  
		,b.bettype      
		,b.betdaqid  
		,b.oddstype  
		,b.transdate  
		,b.betteam      
		,b.hdp1  
		,b.hdp2  
		,b.CurrencyName  
		,b.betcheck  
		,b.transdesc
		,b.ExtraInfo 
		,CASE
			WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
					THEN b.transid
			ELSE NULL
		 END AS MainCashoutId 
		,b.awinlost
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
	FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
		 INNER JOIN bettrans b WITH (NOLOCK)  
				 ON t.transid = b.transid
		LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON t.transid = m.TransId
	WHERE b.matchid = @matchid  
	  AND b.transdate >= @KickOffDate  
	  AND b.liveindicator = 0  
	  AND b.bettype NOT IN (805, 806, 9, 29)	 
	  AND b.betfrom <> 'P'
	  -- filter for BetTeam
	  AND EXISTS (SELECT TOP 1 1
				  FROM #tblBetType tp
				  WHERE tp.Id = b.bettype
				    AND CASE
							WHEN tp.BetTeam = 'ALL' THEN 1									
							ELSE CASE 
									WHEN b.betteam = tp.BetTeam THEN 1
									ELSE 0
								 END 
					    END = 1)
	OPTION (OPTIMIZE FOR (@CountTransId = 1))
	
	/*
		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY
		
		filter for Game : Only handle for bettype 1324
		 
		filter for BetOption : Only handle for bettypes 221 -> 227
		 
		filter for [Value]
		
		filter for TimeInterval
		 
		filter for Goal
	*/			
	BEGIN		
	DELETE s
	FROM #BetDelete s	 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Set] = 'ALL' THEN 1							
								ELSE CASE 						  
										WHEN s.betid LIKE tp.[Set] + '%' THEN 1
										ELSE 0
									 END
							END = 1) 
				
	DELETE s
	FROM #BetDelete s	 	
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.Game = 'ALL' THEN 1
								WHEN (tp.Game LIKE '>%' AND RIGHT(s.betid, 2) > RIGHT(tp.Game, 2)) 
									 OR (RIGHT(s.betid, 2) = tp.Game)
										THEN 1											
								ELSE 0
							END = 1)
				
	DELETE s
	FROM #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.BetOption = 'ALL' THEN 1				
								ELSE CASE
										WHEN CAST(CAST(s.hdp2 AS INT) AS VARCHAR(50)) + '-' + s.betteam = tp.BetOption THEN 1
										ELSE 0
									 END
							END = 1)				
					 
	DELETE s
	FROM #BetDelete s		 		
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Value] = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 + s.hdp2 = tp.[Value] THEN 1
										ELSE 0
									 END
							END = 1)
		  
	DELETE s
	FROM #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.TimeInterval = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 = tp.TimeInterval THEN 1
										ELSE 0
									 END
							END = 1)		  
				
	DELETE s
	FROM #BetDelete s		 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.Goal = 100 THEN 1
								WHEN ISNULL(s.betID, 0) = tp.Goal THEN 1			
								ELSE 0
							END = 1)
	END	 		  

	--Metric Gaming Super Live  
	IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (805,806) )   
	-- translog  
	INSERT INTO #BetDelete (  
		grouptransid  
		,transid  
		,refno  
		,betid  
		,stake  
		,odds  
		,oddsspread
		,custid  
		,recommend  
		,mrecommend  
		,srecommend  
		,betfrom  
		,STATUS  
		,statusID  
		,creator  
		,Bettype  
		,betdaqid  
		,OddsType      
		,Transdate                
		,currencyName      
		,Transdesc
		,IsMarked
	)  
	SELECT   

		b.translogid grouptransid  
		,b.translogID transid  
		,b.translogID  refno  
		,0 betid  
		,b.stake  
		,b.odds 
		,0 AS oddsspread		
		,b.custid  
		,b.recommend  
		,b.mrecommend  
		,b.srecommend  
		,b.betfrom  
		,b.STATUS  
		,b.statusID  
		,b.creator   
		,b.GameID  
		,-1     
		,b.custom1   
		,b.transdate             
		,b.CurrencyName      
		,b.transdesc
		,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked				
	FROM dbo.translog b WITH (NOLOCK)  
		INNER JOIN #tblTransIds t   
		ON t.transid = b.translogid  
		INNER JOIN #tblBettype tp   
		ON tp.Id = b.GameIDLEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.TranslogID = m.TransId
	WHERE b.transdate >= @KickOffDate  
		AND b.GameID IN (805, 806)   
		AND b.liveindicator = 0  
		AND b.betfrom <> 'P'  
		AND b.statusID IN (0, 103) -- RUNNING, REFUND	   	
	
	--GET sub ticket of the matchid for mix parlay  
	IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id IN (9, 29))  
	BEGIN  
		INSERT INTO #BetmDelete (  
			transid  
			,refno  
			,custid  
			,recommend  
			,mrecommend  
			,srecommend  
			,betfrom  
			,STATUS  
			,odds  
			,choiceodds  
			,oddsspread	
			,OddsType  
			,Transdate  
			,Bettype  
			,ParlayType  
			,betteam  
			,choicebetteam  
			,choicehdp1  
			,choicehdp2  
			,hdp1  
			,hdp2  
			,stake  
			,currencyName  
			,choiceBetCheck  
			,betcheck  
			,maintransid  
			,statusid  
			,creatorname  
			,username  
			,username2  
			,modds  
			,transdesc  
			,creator 
			,mainstatusID 
		)  
		SELECT   
			sub.transid  
			,sub.refno  
			,sub.custid  
			,main.recommend  
			,main.mrecommend  
			,main.srecommend  
			,sub.betfrom  
			,main.STATUS  
			,main.odds  
			,sub.odds 
			,main.oddsspread
			,main.oddstype  
			,sub.transdate  
			,main.bettype  
			,sub.bettype  
			,main.betteam  
			,sub.betteam  
			,sub.hdp1  
			,sub.hdp2  
			,main.hdp1  
			,main.hdp2  
			,main.stake  
			,main.CurrencyName  
			,sub.betcheck  
			,main.betcheck  
			,main.transid  
			,sub.statusID  
			,cr.username  
			,c.username  
			,c.username2  
			,main.modds  
			,sub.transdesc  
			,sub.creator 
			,main.statusID AS mainstatusID 
		FROM dbo.bettransm AS sub WITH (NOLOCK)  
			INNER JOIN #tblTransIds t   
			ON t.transid = sub.transid  
			INNER JOIN dbo.bettrans main WITH (NOLOCK)   
			ON sub.refno = main.refno   
			 AND main.matchid IN (9,29)  
			INNER JOIN #tblBettype tp   
			ON tp.Id = main.bettype    
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK)  
			ON c.custid = sub.custid  
			INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK)  
			ON cr.custid = main.creator  
		WHERE sub.matchid = @matchid  
			AND sub.transdate >= @KickOffDate  
			AND sub.liveindicator = 0  
			AND sub.betfrom <> 'P'  
			AND main.bettype IN (9, 29)  
			AND sub.statusID NOT IN (101, 102)  
			AND (  
			 main.betid = 0  
			 OR main.betid IS NULL  
			)  
	END  
	
	------------------***** End of insert all data into #BetDelete,#BetmDelete *****------------------	
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets	
	INSERT INTO #tmpRefCodeSummary (RefCode, custid, bettype, IsMarked, transid)
	SELECT RefCode, custid, bettype, IsMarked, MAX(transid) as transid
	FROM #BetDelete
	WHERE RefCode IS NOT NULL		
	GROUP BY RefCode, custid, bettype, IsMarked
	HAVING COUNT(*) = 1	
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #BetDelete (  
			grouptransid  
			,transid  
			,refno  
			,betid  
			,stake  
			,odds
			,oddsspread			
			,custid  
			,recommend  
			,mrecommend  
			,srecommend  
			,betfrom  
			,STATUS  
			,statusID  
			,creator  
			,Bettype      
			,betdaqid  
			,OddsType    
			,Transdate    
			,betteam         
			,hdp1     
			,hdp2     
			,currencyName  
			,betcheck    
			,transdesc		
			,ExtraInfo  
			,MainCashoutId   
			,awinlost		
			,WalletType
			,RefCode
			,BonusID 
			,MainTransId
			,IsMarked  
		)  
		SELECT   
			b.transid grouptransid  
			,b.transid  
			,b.refno  
			,b.betid  
			,b.stake  
			,b.odds 
			,b.oddsspread			
			,b.custid  
			,b.recommend  
			,b.mrecommend  
			,b.srecommend  
			,b.betfrom  
			,b.STATUS  
			,b.statusID  
			,b.creator  
			,b.Bettype      
			,b.betdaqid  
			,b.oddstype  
			,b.transdate  
			,b.betteam      
			,b.hdp1  
			,b.hdp2  
			,b.CurrencyName  
			,b.betcheck  
			,b.transdesc
			,b.ExtraInfo 
			,CASE
				WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
						THEN b.transid
				ELSE NULL
			 END AS MainCashoutId
			,b.awinlost
			,b.WalletType
			,b.RefCode
			,b.BonusID
			,r.transid AS MainTransId
			,r.IsMarked
		FROM #tmpRefCodeSummary r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON b.RefCode = r.RefCode
						AND b.transid <> r.transid
						AND b.matchid = @MatchId
						AND b.custid = r.custid
						AND b.bettype = r.bettype
		WHERE b.statusID NOT IN (101,102 ) -- reject, void
	END
	
	-- delete main ticket if it's BT but subticket is not exists in SOLD list  
	DELETE  
	FROM #BetDelete  
	OUTPUT DELETED.grouptransid  
	INTO @tblInvalidTrans (transid)  
	WHERE grouptransid NOT IN (SELECT grouptransid FROM #tblTransIdSolds)  
	AND betdaqid = 0
	AND extrainfo is null   

	-- delete main ticket if it's not BT but have subticket in SOLD list  
	DELETE  
	FROM #BetDelete  
	OUTPUT DELETED.grouptransid  
	INTO @tblInvalidTrans  
	WHERE transid IN (SELECT grouptransid FROM #tblTransIdSolds)  
	AND betdaqid = -1
	AND extrainfo is null   
	 
	-- checking cash-out process
	INSERT INTO #tblCashOutProcess(transid)
	SELECT transid
	FROM #BetDelete	
	WHERE betdaqid = 0 
	  AND charindex ('p25',extrainfo)> 0
	
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 0
	
	DELETE bd
	FROM #BetDelete bd
		 INNER JOIN #tblCashOutProcess rp
				 ON bd.transid = rp.transid					
					AND rp.IsAvailable = 0

	-- check ticket's status  
	INSERT INTO @Status (statusID) VALUES (102),(101),(112),(113),(111)  

	IF EXISTS (  
	SELECT 1  
	FROM #BetDelete  
	WHERE statusID IN (111, 112, 113) -- settled  
	UNION ALL  
	SELECT 1  
	FROM #BetmDelete  
	WHERE statusID IN (111, 112, 113)  
	)  
	BEGIN  

	SELECT @ErrCode = 100  
	,@ErrMsg = 'You can only void the unsettled or refunded tickets.'  
	 
	END  

	DELETE  
	FROM #BetDelete  
	WHERE statusID IN (SELECT statusID FROM @Status)  

	DELETE  
	FROM #BetmDelete  
	WHERE statusID IN (SELECT statusID FROM @Status) 
	
	-- return invalid transId   
	SELECT @InvalidTransIds = @InvalidTransIds + CAST(T.transid AS VARCHAR(20)) + ','  
	FROM (
			SELECT transid
			FROM @tblInvalidTrans	
			UNION ALL
			SELECT transid
			FROM #tblCashOutProcess
			WHERE IsAvailable = 0	
		 ) AS T 

	--check no data  
	IF ( NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)   
	AND NOT EXISTS (SELECT TOP 1 1 FROM #BetmDelete)  
	)  
	BEGIN  
		-- check for previous error-message 
		IF @InvalidTransIds = '' 
			SELECT @ErrMsg = CASE WHEN @ErrCode = 0 THEN 'No ticket found.' ELSE @ErrMsg END  
			,@ErrCode = CASE WHEN @ErrCode = 0 THEN 99 ELSE @ErrCode END  

		------ releasing SD process  
		EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay  = @isExistParlay  
				, @isExistMG  	= @isExistMG  
				, @isExistMatch	= @isExistMatch  
				, @isExistBB	= @isExistBB
				, @IsReleased  	= 1  
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1				
	END  
	ELSE  
	BEGIN
		DELETE   
		FROM #tblTransIdSolds   
		WHERE grouptransid IN (SELECT transid FROM @tblInvalidTrans)	   		  		
		
		--- check exists BT or not + Cash-out or not
		SELECT @isExistBT 	= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			 , @isExistCashOut = MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
		FROM #BetDelete

		-- Create temp table to calculate balance  
		DECLARE @BeforeUpd TVP_BalanceWalletChange
		DECLARE @AfterUpd  TVP_BalanceWalletChange

		IF (@isExistBT = 1 AND EXISTS (SELECT TOP 1 1 FROM #tblTransIdSolds))
		BEGIN
			INSERT INTO #BetDelete (  
			 grouptransid  
			 ,transid  
			 ,refno  
			 ,betid  
			 ,stake  
			 ,odds  
			 ,oddsspread
			 ,custid  
			 ,recommend  
			 ,mrecommend  
			 ,srecommend  
			 ,betfrom  
			 ,STATUS  
			 ,statusID  
			 ,creator  
			 ,Bettype
			 ,OriginalBetType      
			 ,betdaqid  
			 ,OddsType    
			 ,Transdate    
			 ,betteam         
			 ,hdp1     
			 ,hdp2     
			 ,currencyName  
			 ,betcheck    
			 ,transdesc
			 ,ExtraInfo 			 
			 ,awinlost
			 ,WalletType
			 ,RefCode
			 ,BonusID 
			 ,MainTransId
			 ,IsMarked
			)   
			SELECT  tmpmain.grouptransid  
			 ,sub.transid  
			 ,sub.refno  
			 ,tmpmain.Bettype AS betid  
			 ,tmpmain.stake  
			 ,tmpmain.odds 
			 ,tmpmain.oddsspread			 
			 ,sub.custid  
			 ,sub.recommend  
			 ,sub.mrecommend  
			 ,sub.srecommend  
			 ,tmpmain.betfrom  
			 ,'SOLD'  
			 ,sub.statusID  
			 ,sub.creator  
			 ,sub.Bettype 
			 ,tmpmain.bettype AS OriginalBetType     
			 ,tmpmain.betdaqid  
			 ,tmpmain.OddsType  
			 ,sub.transdate  
			 ,tmpmain.betteam  
			 ,tmpmain.hdp1  
			 ,tmpmain.hdp2  
			 ,tmpmain.currencyName  
			 ,tmpmain.betcheck  
			 ,tmpmain.transdesc 
			 ,tmpmain.ExtraInfo			 
			 ,sub.awinlost 
			 ,sub.WalletType
			 ,sub.RefCode
			 ,sub.BonusID  
			 ,tmpmain.transid AS MainTransId
			 ,tmpmain.IsMarked
			FROM dbo.bettrans sub WITH(NOLOCK)  
			INNER JOIN #BetDelete tmpmain   
			 ON sub.refno = tmpmain.transid  
			  AND sub.bettype = 901  
			  AND tmpmain.betdaqid = 0  
			  AND tmpmain.extrainfo is null 
			  AND sub.matchid = @matchid    
			WHERE sub.transid IN (SELECT transid FROM #tblTransIdSolds)  
			
			--insert custBT 
			INSERT INTO @tblCustBT902( custid )
			SELECT sub902.custid
			FROM dbo.bettrans sub902 WITH (NOLOCK)
				INNER JOIN #BetDelete tmpmain with(NOLOCK)
				ON	sub902.refno = tmpmain.transid
									
			WHERE sub902.matchid 		= @matchid
				AND sub902.bettype 		= 902
				AND tmpmain.betdaqid 	= 0
				AND tmpmain.extrainfo is null
			GROUP BY sub902.custid
			
		END
		
		IF (@isExistCashOut = 1)
		BEGIN
			-- insert cash-out sub ticket 911
			INSERT INTO #BetDelete (  
			 grouptransid  
			 ,transid  
			 ,refno  
			 ,betid  
			 ,stake  
			 ,odds 
			 ,oddsspread			 
			 ,custid  
			 ,recommend  
			 ,mrecommend  
			 ,srecommend  
			 ,betfrom  
			 ,STATUS  
			 ,statusID  
			 ,creator  
			 ,Bettype 
			 ,OriginalBetType     
			 ,betdaqid  
			 ,OddsType    
			 ,Transdate    
			 ,betteam         
			 ,hdp1     
			 ,hdp2     
			 ,currencyName  
			 ,betcheck    
			 ,transdesc 
			 ,ExtraInfo 
			 ,MainCashoutId   
			 ,awinlost
			 ,matchid
			 ,WalletType
			 ,RefCode
			 ,BonusID 
			 ,MainTransId
			 ,IsMarked
			)   
			OUTPUT inserted.transid
				 , inserted.bettype 
				 , inserted.OriginalBetType
				 , inserted.MainCashoutId
				 , inserted.matchid
				 , inserted.MainTransId
					INTO #CashOutSubTicket(transid
										 , bettype
										 , OriginalBetType
										 , MainCashoutId
										 , matchid
										 , MainTransId)
			SELECT  tmpmain.grouptransid  
			 ,sub.transid  
			 ,sub.refno  
			 ,tmpmain.Bettype AS betid  
			 ,sub.stake  
			 ,tmpmain.odds
			 ,tmpmain.oddsspread			 
			 ,sub.custid  
			 ,sub.recommend  
			 ,sub.mrecommend  
			 ,sub.srecommend  
			 ,tmpmain.betfrom  
			 ,'Cash out'  
			 ,sub.statusID  
			 ,sub.creator  
			 ,sub.Bettype
			 ,tmpmain.Bettype AS OriginalBetType      
			 ,sub.betdaqid  
			 ,tmpmain.OddsType  
			 ,sub.transdate  
			 ,tmpmain.betteam  
			 ,tmpmain.hdp1  
			 ,tmpmain.hdp2  
			 ,tmpmain.currencyName  
			 ,tmpmain.betcheck  
			 ,tmpmain.transdesc  
			 ,sub.ExtraInfo
			 ,tmpmain.transid AS MainCashoutId
			 ,sub.awinlost
			 ,sub.matchid
			 ,sub.WalletType
			 ,sub.RefCode
			 ,sub.BonusID  
			 ,tmpmain.transid AS MainTransId
			 ,tmpmain.IsMarked
			FROM dbo.bettrans sub WITH(NOLOCK)
				INNER JOIN #BetDelete tmpmain 
					ON	sub.refno = tmpmain.transid
						AND sub.custid = tmpmain.custid						
						AND tmpmain.betdaqid = 0
						AND charindex ('p25',tmpmain.extrainfo)> 0			
						AND sub.bettype = 911
						AND sub.matchid = @matchid
			WHERE sub.statusID NOT IN (102, 101) -- VOID, REJECT						
			
			-- insert cash-out member bet tickets
			INSERT INTO #BetDelete (  
				grouptransid  
				,transid  
				,refno  
				,betid  
				,stake  
				,odds  
				,oddsspread
				,custid  
				,recommend  
				,mrecommend  
				,srecommend  
				,betfrom  
				,STATUS  
				,statusID  
				,creator  
				,Bettype
				,OriginalBetType      
				,betdaqid  
				,OddsType    
				,Transdate    
				,betteam         
				,hdp1     
				,hdp2     
				,currencyName  
				,betcheck    
				,transdesc 
				,ExtraInfo 
				,IsCashOutMemberTicket
				,MainCashoutId 
				,awinlost 
				,WalletType
				,RefCode
				,BonusID 
				,MainTransId
				,IsMarked
			)  
			SELECT   
				b.transid grouptransid  
				,b.transid  
				,b.refno  
				,b.betid  
				,b.stake  
				,b.odds  
				,b.oddsspread
				,b.custid  
				,b.recommend  
				,b.mrecommend  
				,b.srecommend  
				,b.betfrom  
				,b.STATUS  
				,b.statusID  
				,b.creator  
				,b.Bettype 
				,sub911.OriginalBetType     
				,b.betdaqid  
				,b.oddstype  
				,b.transdate  
				,b.betteam      
				,b.hdp1  
				,b.hdp2  
				,b.CurrencyName  
				,b.betcheck  
				,b.transdesc 
				,b.ExtraInfo
				,1 AS IsCashOutMemberTicket
				,sub911.MainCashoutId AS MainCashoutId
				,b.awinlost
				,b.WalletType
				,b.RefCode
				,b.BonusID 
				,sub911.MainTransId
				,b.IsMarked
			FROM #CashOutSubTicket sub911
				 CROSS APPLY ( 
					SELECT b.transid
						,b.refno
						,b.betid  
						,b.stake  
						,b.odds  
						,b.oddsspread
						,b.custid  
						,b.recommend  
						,b.mrecommend  
						,b.srecommend  
						,b.betfrom  
						,b.STATUS  
						,b.statusID  
						,b.creator  
						,b.Bettype    
						,b.betdaqid  
						,b.oddstype  
						,b.transdate  
						,b.betteam      
						,b.hdp1  
						,b.hdp2  
						,b.CurrencyName  
						,b.betcheck  
						,b.transdesc 
						,b.ExtraInfo
						,b.awinlost
						,b.WalletType
						,b.RefCode
						,b.BonusID
						,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
						FROM dbo.bettrans b WITH (NOLOCK)
							 LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId
						WHERE b.refno = sub911.transid
						AND b.matchid = sub911.matchid
						AND b.bettype = sub911.OriginalBetType
						AND b.statusID NOT IN (102, 101) -- VOID, REJECT
					) AS b
			
			-- insert 912,913
			INSERT INTO #CashOutSubTicket(transid
										, bettype
										, OriginalBetType
										, MainCashoutId
										, matchid
										, MainTransId)															
			SELECT sub_912_913.transid
				 , sub_912_913.bettype
				 , sub911.OriginalBetType
				 , sub911.MainCashoutId
				 , sub911.matchid
				 , sub911.MainTransId
			FROM #CashOutSubTicket sub911
				 INNER JOIN bettrans sub_912_913 (nolock)
						 ON sub911.transid = sub_912_913.refno
							AND sub911.matchid = sub_912_913.matchid						    
							AND sub_912_913.bettype IN (912,913) 
							AND sub_912_913.statusID NOT IN (102, 101) -- VOID, REJECT				 
			
			-- insert custCashOut912
			INSERT INTO @tblCustCashOut912( custid )
			SELECT DISTINCT custid
			FROM #BetDelete						
			WHERE IsCashOutMemberTicket = 1						
		END
		
		--Insert ticket of MGSL in translog: 805,806  
		INSERT INTO [bodb02].[dbo].[bettrans]  
		  ([custid]  
		  ,[transdate]  
		  ,[oddsid]  
		  ,[hdp1]  
		  ,[hdp2]  
		  ,[odds]  
		  ,[stake]  
		  ,[status]  
		  ,[winlost]  
		  ,[awinlost]  
		  ,[mwinlost]  
		  ,[playercomm]  
		  ,[comm]  
		  ,[acomm]  
		  ,[apositiontaking]  
		  ,[mpositiontaking]  
		  ,[tpositiontaking]  
		  ,[playerdiscount]  
		  ,[discount]  
		  ,[adiscount]  
		  ,[livehomescore]  
		  ,[liveawayscore]  
		  ,[liveindicator]  
		  ,[betteam]  
		  ,[creator]  
		  ,[refno]  
		  ,[comstatus]  
		  ,[winlostdate]  
		  ,[betfrom]  
		  ,[betcheck]  
		  ,[checktime]  
		  ,[oddsspread]  
		  ,[actualrate]  
		  ,[matchid]  
		  ,[recommend]  
		  ,[mrecommend]  
		  ,[ruben]  
		  ,[betid]  
		  ,[statuswinlost]  
		  ,[modds]  
		  ,[bettype]  
		  ,[betdaqid]  
		  ,[actual_stake]  
		  ,[currency]  
		  ,[ip]  
		  ,[transdesc]  
		  ,[sdiscount]  
		  ,[scomm]  
		  ,[spositiontaking]  
		  ,[swinlost]  
		  ,[srecommend]  
		  ,[Username]  
		  ,[CurrencyName]  
		  ,[virtualrate]  
		  ,[oddstype]  
		  ,[statusID]  
		  ,[currency2]  
		  ,[balance]  
		  ,[SecAcceptFlag]  
		  ,[transid2]  
		  ,[RecommDate])  
		SELECT  b.[custid]  
		  ,b.[transdate]  
		  ,0 [oddsid]  
		  ,0 [hdp1]  
		  ,0 [hdp2]  
		  ,b.[odds]  
		  ,b.[stake]  
		  ,b.[status]  
		  ,0 [winlost]  
		  ,0 [awinlost]  
		  ,0 [mwinlost]  
		  ,0 [playercomm]  
		  ,0 [comm]  
		  ,0 [acomm]  
		  ,b.[apositiontaking]  
		  ,b.[mpositiontaking]  
		  ,b.[tpositiontaking]  
		  ,b.[playerdiscount]  
		  ,b.[discount]  
		  ,b.[adiscount]  
		  ,0 [livehomescore]  
		  ,0 [liveawayscore]  
		  ,b.[liveindicator]  
		  ,SUBSTRING(b.[transdesc],11,CHARINDEX(';BettypeTime',b.[transdesc],0) - 11) [betteam]  
		  ,b.[creator]  
		  ,b.translogid [refno]  
		  ,b.custom2 [comstatus]  
		  ,b.[winlostdate]  
		  ,b.[betfrom]  
		  ,b.transdate [betcheck]  
		  ,NULL [checktime]  
		  ,0 [oddsspread]  
		  ,b.[actualrate]  
		  ,b.EventID  
		  ,b.[recommend]  
		  ,b.[mrecommend]  
		  ,0 [ruben]  
		  ,CASE WHEN ISNULL(b.custom3,'') = '' THEN NULL ELSE CAST(b.custom3 AS BIGINT) END [betid]  
		  ,NULL [statuswinlost]  
		  ,0 [modds]  
		  ,b.GameID [bettype]  
		  ,NULL [betdaqid]  
		  --,b.[actual_stake] #94603
		  ,0 [actual_stake]
		  ,b.[currency]  
		  ,b.[ip]  
		  ,b.[transdesc]  
		  ,b.[sdiscount]  
		  ,0 [scomm]  
		  ,b.[spositiontaking]  
		  ,0 [swinlost]  
		  ,b.[srecommend]  
		  ,b.[Username]  
		  ,b.[CurrencyName]  
		  ,b.[virtualrate]  
		  ,b.custom1 [oddstype]  
		  ,b.[statusID]  
		  ,NULL [currency2]  
		  ,b.[balance]  
		  ,0 [SecAcceptFlag]  
		  ,0 [transid2]  
		  ,NULL [RecommDate]  
		FROM dbo.translog b WITH(NOLOCK)   
			INNER JOIN #BetDelete tmp   
			ON b.translogid = tmp.transid  
		WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.bettrans WITH(NOLOCK) WHERE refno = b.translogid AND matchid = b.eventID)  
		AND b.GameID IN (805,806)  
	 
		--Update new transid  
		UPDATE tmpmain  
		SET tmpmain.TransID = main.TransID  
		,tmpmain.grouptransid = main.transid  
		FROM #BetDelete tmpmain  
		INNER JOIN dbo.bettrans main WITH(NOLOCK)   
		ON main.refno = tmpmain.refno   
		 AND main.matchid = @matchid  
		 AND tmpmain.Bettype IN (805, 806)  
	  
		------------------***** Begin special delete early kickoff *****------------------  
		-- STEP 1 : BackUp bettrans  
		-- 1.1  Backup normal, main bettrade, main cash-out, cash-out member bet ticket 
		INSERT INTO zzzbettrans (  
			transid  
			,custid  
			,transdate  
			,oddsid  
			,hdp1  
			,hdp2  
			,odds  
			,stake  
			,STATUS  
			,winlost  
			,livehomescore  
			,liveawayscore  
			,liveindicator  
			,betteam  
			,creator  
			,refno  
			,winlostdate  
			,betfrom  
			,betcheck  
			,checktime  
			,matchid  
			,bettype  
		)  
		SELECT main.transid  
			,main.custid  
			,CURRENT_TIMESTAMP  
			,main.oddsid  
			,main.hdp1  
			,main.hdp2  
			,main.odds  
			,main.stake  
			,main.STATUS  
			,main.winlost  
			,main.livehomescore  
			,main.liveawayscore  
			,main.liveindicator  
			,main.betteam  
			,main.creator  
			,main.refno  
			,main.winlostdate  
			,main.betfrom  
			,CASE
					WHEN (tmpmain.betdaqid = 0 AND charindex ('p25',tmpmain.extrainfo)> 0) -- main ticket is Cash-out
						 OR tmpmain.IsCashOutMemberTicket = 1
							THEN @session
					ELSE main.betcheck
			 END AS betcheck  
			,main.checktime  
			,main.matchid  
			,main.bettype  
		FROM dbo.bettrans AS main WITH (NOLOCK)  
			INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK)   
			ON main.transid = tmpmain.grouptransid  
			 AND main.transid = tmpmain.transid   
			 AND main.matchid = @matchid  
		   
		--1.2. Backup subtickets (901,902,903) 
		IF (@isExistBT = 1)  
			INSERT INTO zzzbettrans (  
				transid  
				,custid  
				,transdate  
				,oddsid  
				,hdp1  
				,hdp2  
				,odds  
				,stake  
				,STATUS  
				,winlost  
				,livehomescore  
				,liveawayscore  
				,liveindicator  
				,betteam  
				,creator  
				,refno  
				,winlostdate  
				,betfrom  
				,betcheck  
				,checktime  
				,matchid  
				,bettype  
			)  
			SELECT sub.transid  
				,sub.custid  
				,CURRENT_TIMESTAMP  
				,sub.oddsid  
				,sub.hdp1  
				,sub.hdp2  
				,sub.odds  
				,sub.stake  
				,sub.STATUS  
				,sub.winlost  
				,sub.livehomescore  
				,sub.liveawayscore  
				,sub.liveindicator  
				,sub.betteam  
				,sub.creator  
				,sub.refno  
				,sub.winlostdate  
				,sub.betfrom  
				,sub.betcheck  
				,sub.checktime  
				,sub.matchid  
				,sub.bettype  
			FROM dbo.bettrans AS sub WITH (NOLOCK)  
			INNER JOIN #BetDelete tmpmain   
			ON  sub.refno = tmpmain.transid  
			 AND sub.matchid = @matchid  
			 AND sub.bettype IN (901, 902, 903)  
			 AND tmpmain.betdaqid = 0
			 AND tmpmain.extrainfo is null 
		 
		-- 1.3. Back up Cash-out's subtickets (911,912,913) 
		IF (@isExistCashOut = 1)
			INSERT INTO zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
						winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
						winlostdate,betfrom,betcheck,checktime,matchid, bettype)
			SELECT  b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
					b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
					b.winlostdate, b.betfrom, 
					@session AS betcheck, 
					b.checktime, b.matchid, b.bettype
			FROM bettrans b WITH (nolock)
				 INNER JOIN #CashOutSubTicket sub
						 ON b.transid = sub.transid						

		--STEP2: BackUp bettransm tickets into zzzbettrans  
		/***  
		Date: 20120112@Lukas  
		Temporary solution  
		ADD MORE LOG IN ZZZBETTRANS FOR VIEWING LOG TW SITE  
		***/  
		INSERT INTO zzzbettrans (  
			transid  
			,custid  
			,transdate  
			,oddsid  
			,hdp1  
			,hdp2  
			,odds  
			,stake  
			,STATUS  
			,winlost  
			,livehomescore  
			,liveawayscore  
			,liveindicator  
			,betteam  
			,creator  
			,refno  
			,winlostdate  
			,betfrom  
			,betcheck  
			,checktime  
			,matchid  
			,bettype  
		)  
		SELECT bm.transid  
			,bm.custid  
			,CURRENT_TIMESTAMP  
			,bm.oddsid  
			,bm.hdp1  
			,bm.hdp2  
			,bm.odds  
			,bm.stake  
			,bm.STATUS  
			,bm.winlost  
			,bm.livehomescore  
			,bm.liveawayscore  
			,bm.liveindicator  
			,bm.betteam  
			,bm.creator  
			,bm.refno  
			,bm.winlostdate  
			,bm.betfrom  
			,bm.betcheck  
			,bm.checktime  
			,bm.matchid  
			,bm.bettype  
		FROM bettransm AS bm WITH (NOLOCK)  
		INNER JOIN #BetmDelete AS tmpbm   
		ON bm.transid = tmpbm.transid  

		/*  
		END -  ADD MORE LOG IN ZZZBETTRANS FOR VIEWING LOG TW SITE  
		*/  
		INSERT INTO zzzbettransm (  
			transid  
			,custid  
			,transdate  
			,oddsid  
			,hdp1  
			,hdp2  
			,odds  
			,stake  
			,STATUS  
			,winlost  
			,livehomescore  
			,liveawayscore  
			,liveindicator  
			,betteam  
			,creator  
			,refno  
			,winlostdate  
			,betfrom  
			,betcheck  
			,checktime  
			,matchid  
			,bettype  
		)  
		SELECT bm.transid  
			,bm.custid  
			,CURRENT_TIMESTAMP  
			,bm.oddsid  
			,bm.hdp1  
			,bm.hdp2  
			,bm.odds  
			,bm.stake  
			,bm.STATUS  
			,bm.winlost  
			,bm.livehomescore  
			,bm.liveawayscore  
			,bm.liveindicator  
			,bm.betteam  
			,bm.creator  
			,bm.refno  
			,bm.winlostdate  
			,bm.betfrom  
			,bm.betcheck  
			,bm.checktime  
			,bm.matchid  
			,bm.bettype  
		FROM bettransm AS bm WITH (NOLOCK)  
		INNER JOIN #BetmDelete AS tmpbm  
		ON bm.transid = tmpbm.transid  
		 
		--Get data before update  
		INSERT INTO @BeforeUpd (  
			 matchid
			,custid  			 
			,balanceType
			,BonusID
			,WalletType 
			,balance 
		)  
		SELECT @MatchId AS matchid
			 , custid  
			 , CASE WHEN bettype IN (805, 806) THEN 4 ELSE 1 END AS balanceType
			 , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			 , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance  
		FROM  
		(  
			-- normal, main bettrade, main cash-out, cash-out member bet ticket
			SELECT main.custid
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
				 , main.winlost, main.actual_stake ,main.playercomm, main.bettype  
			FROM bettrans main WITH (NOLOCK)  
			INNER JOIN #BetDelete tmpmain  
				ON main.transid = tmpmain.transid  
				AND main.transid = tmpmain.grouptransid  
				AND main.matchid = @matchid  
			WHERE 1 = CASE WHEN tmpmain.bettype IN (805, 806) AND tmpmain.statusID = 0 THEN 0 ELSE 1 END  			
			UNION ALL  
			SELECT  tl.custid
				  , 0 AS BonusID -- running metric gaming tickets always bet from cash wallet
				  , 2 AS WalletType -- running metric gaming tickets always bet from cash wallet
				  , 0 AS winlost, tl.actual_stake, 0 AS playercomm, tl.gameID  
			FROM dbo.translog tl WITH(NOLOCK)  
			INNER JOIN #BetDelete tmpmain  
				ON tl.translogid = tmpmain.refno  
				AND tl.eventID = @matchid  
			WHERE tl.statusID = 0  
				AND tl.gameID IN (805, 806)  			
			UNION ALL 
			-- bettrade subticket (901,902,903) 
			SELECT sub.custid
				 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype  
			FROM bettrans sub WITH (NOLOCK)  
			INNER JOIN #BetDelete AS tmpmain   
				ON tmpmain.transid = sub.refno  
				AND sub.bettype BETWEEN 901 AND 910
				AND tmpmain.betdaqid = 0  
				AND tmpmain.extrainfo is null
				AND sub.matchid = @matchid 			
			WHERE @isExistBT = 1
			UNION ALL
			-- cash-out subticket (911,912,913)	
			SELECT	b.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , b.winlost, b.actual_stake, b.playercomm, b.bettype
			FROM	bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub
					 ON b.transid = sub.transid
			WHERE @isExistCashOut = 1									
			UNION ALL
			-- bettrade summary 904
			SELECT	sub904.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype  
			FROM	bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid										
			WHERE sub904.matchid 		= @matchid
				AND sub904.bettype 		= 904
			UNION ALL
			-- cash-out summary 914
			SELECT	sub914.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
			FROM	bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp
					ON sub914.custid = temp.custid						
			WHERE sub914.matchid 		= @matchid
				AND sub914.bettype 		= 914				
		) tmp  

		GROUP BY CustID  
			   , CASE WHEN bettype IN (805, 806) THEN 4 ELSE 1 END
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		-- STEP 3 : Update bettrans/translog  
		-- 3.1. Update normal, main bettrade, main cash-out, cash-out member bet ticket  
		UPDATE main  
		SET   
			winlost = main.actual_stake  
			,ruben = 1  
			,statuswinlost = 6  
			,creator = @UserID  
			,mwinlost = 0  
			,swinlost = 0  
			,playercomm = 0  
			,comm = 0  
			,acomm = 0  
			,scomm = 0  
			,statusID = 102  
			,status = 'VOID'  
			,betid = CASE WHEN main.Bettype IN (805,806) AND main.BetID IS NULL THEN (   
			 SELECT rs.ResultID   
			 FROM DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)   
			 WHERE (  
			   (ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, main.transdesc,0) <> 0)  
			   OR  
			   main.bettype = 806  
			  )  
			  AND rs.GameID = main.bettype   
			  AND rs.VendorID = 5    
			  AND rs.MatchID = main.matchid     
		   )  
		   ELSE main.betid  
		   END  
		FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)  
			INNER JOIN #BetDelete AS tmpmain  
		ON main.transid = tmpmain.transid  
			AND main.transid = tmpmain.grouptransid  
			AND main.matchid = @matchid  

		-- recover actual_stake from translog  
		UPDATE mainMG  
		SET actual_stake = tl.actual_stake  
		,winlost = tl.actual_stake     
		FROM dbo.bettrans mainMG WITH(ROWLOCK, UPDLOCK)  
			INNER JOIN #BetDelete tmpmainMG  
			ON mainMG.transid = tmpmainMG.transid  
			AND mainMG.transid = tmpmainMG.grouptransid  
			AND mainMG.bettype IN (805, 806)  
			INNER JOIN dbo.translog tl WITH(NOLOCK)  
			ON mainMG.refno = tl.translogid  
			AND mainMG.matchid = @matchid  
	  
		-- 3.2. Update translog  
		UPDATE tl  
		SET  
			tl.Status = 'Void',  
			tl.StatusID = 102,  
			tl.creator = @UserID,  
			tl.custom3 = case   
		   when ISNULL(tl.Custom3,'') = '' then   
			(SELECT rs.ResultID   
			FROM  DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)   
			WHERE (  
			  (ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, tl.transdesc,0) <> 0)  
			  OR  
			  tl.GameID = 806  
			  )  
			  AND rs.GameID = tl.GameID   
			  AND rs.VendorID = 5    
			  AND rs.MatchID = tl.EventID     
			)   
		   else tl.custom3  
		   end  
		FROM dbo.translog tl WITH(ROWLOCK,UPDLOCK)  
		inner join #BetDelete main  
		on tl.translogid = main.refno  
		 and tl.eventid = @matchid  
		 and tl.gameid in (805, 806) 
		
		-- update bettrade, cash-out
		IF (@isExistBT = 1 OR @isExistCashOut = 1)  
		BEGIN
			-- 3.3. BetTrade's subtickets (901,902,903)
			IF (@isExistBT = 1)
				UPDATE sub  
				SET winlost = sub.actual_stake  
					,ruben = 1  
					,statuswinlost = 6  
					,creator = @UserID 
					,awinlost = 0 
					,mwinlost = 0  
					,swinlost = 0  
					,playercomm = 0  
					,comm = 0  
					,acomm = 0  
					,scomm = 0  
					,statusID = 102  
					,status = 'VOID'  
				FROM dbo.bettrans AS sub WITH (ROWLOCK, UPDLOCK)  
				INNER JOIN #BetDelete tmpmain   
				 on sub.refno = tmpmain.transid  
				  and sub.matchid = @matchid  
				  and sub.bettype in (901, 902, 903)  
				  AND tmpmain.betdaqid = 0
			  AND tmpmain.extrainfo is null
						
			-- 3.4. Cash-out's subtickets (911,912,913)
			IF (@isExistCashOut = 1)
				UPDATE b  
				SET winlost = b.actual_stake  
					,ruben = 1  
					,statuswinlost = 6  
					,creator = @UserID  
					,awinlost = 0
					,mwinlost = 0  
					,swinlost = 0  
					,playercomm = 0  
					,comm = 0  
					,acomm = 0  
					,scomm = 0  
					,statusID = 102  
					,status = 'VOID'  
				FROM	dbo.bettrans b WITH (ROWLOCK, UPDLOCK)
				INNER JOIN #CashOutSubTicket sub
						 ON b.transid = sub.transid
			
			-- STEP 4 : Update BetTrade selling information
			CREATE TABLE #CustIdList
			(
				custid INT PRIMARY KEY
			)
			 			 
			CREATE TABLE #CustList
			(
				custid INT PRIMARY KEY,
				Balance MONEY
			)
			
			INSERT INTO #CustIdList(custid)
			SELECT DISTINCT custid FROM #BetDelete
			
			INSERT INTO #CustList(custid, Balance)
			SELECT T.custid, SUM(T.Balance)
			FROM
			(
				SELECT	b.custid, b.winlost - b.actual_stake + b.playercomm AS Balance				
				FROM	dbo.bettrans b WITH(NOLOCK)
					LEFT JOIN dbo.translog tl WITH(NOLOCK)
						ON	b.refno = tl.translogid
							AND b.matchid = tl.eventID												
				WHERE	b.custid IN (SELECT custid FROM #CustIdList)
						AND (tl.translogid IS NULL OR (tl.translogid IS NOT NULL AND tl.statusID <> 0))						
				UNION ALL 
				SELECT	tl.custid, 0 - tl.actual_stake + 0 AS Balance 
				FROM	dbo.translog tl WITH(NOLOCK)
				WHERE	tl.custid IN (SELECT custid FROM #CustIdList)
						AND tl.statusID IN (0, 1)				
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransRnG WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList)
						AND IsSum=0				
				UNION ALL
				SELECT	custid, winlost - actual_stake + playercomm AS Balance
				FROM	dbo.bettransLC WITH(NOLOCK)
				WHERE	custid IN (SELECT custid FROM #CustIdList) 
						AND IsSum=0	
				UNION ALL
				SELECT bal.CustId, (Credit - Debit) AS Balance
				FROM dbo.BalNetPosition bal WITH(NOLOCK)
					INNER JOIN #BetDelete d 
							 ON bal.CustId = d.CustId 
								AND bal.MatchId = @MatchId 
								AND bal.Bettype = d.bettype	
				UNION ALL
				SELECT DISTINCT c.CustId, c.Credit AS Balance
				FROM DBCUST.custDB.dbo.custInfo c WITH(NOLOCK)						
					 INNER JOIN #CustIdList d 
							 ON c.CustId = d.CustId
			) T
			GROUP BY T.custid
			
			;WITH CTE_Source AS
			(
				SELECT	bts.TradeID AS TradeID
						,bts.TicketID AS [TicketID]					
						,'SB void ticket due to ' + @Reason AS [Remark]
						,tmpsub.awinlost AS [BTBuyBack]
						,0 AS [BTComission]
						,tcust.Balance AS [AfterBalance]
						,'SB' AS [Owner]
						,1 AS [Cancelled]
						,GETDATE() AS [ChangeDate]
						,GETDATE() AS [CreateDate]
				FROM #BetDelete tmpsub						 											 
					 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
							 ON bts.TicketID = tmpsub.refno -- bettrade + cash-out
								AND CASE																				 
										WHEN tmpsub.bettype = 911 -- cash-out													 
												THEN CASE
														WHEN bts.SoldTicketID = tmpsub.transid THEN 1
														ELSE 0
													 END																							
										ELSE 1
									END = 1	
					 INNER JOIN #CustList tcust
							 ON tmpsub.custid = tcust.custid						 							
				WHERE tmpsub.BetType IN (901,911)				  
			)
			MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
			USING (SELECT * FROM CTE_Source) AS [Source]
			ON [Target].TradeID = [Source].TradeID
			WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
										,[BTBuyBack] = [Source].[BTBuyBack]
										,[BTComission] = [Source].[BTComission]
										,[AfterBalance] = [Source].[AfterBalance]
										,[Owner] = [Source].[Owner]
										,[Cancelled] = [Source].[Cancelled]
										,[ChangeDate] = [Source].[ChangeDate]										
			WHEN NOT MATCHED THEN INSERT(TradeID
										,[TicketID]										
										,[Remark]
										,[BTBuyBack]
										,[BTComission]
										,[AfterBalance]
										,[Owner]
										,[Cancelled]
										,[ChangeDate]
										,[CreateDate])
								  VALUES([Source].TradeID
										,[Source].[TicketID]										
										,[Source].[Remark]
										,[Source].[BTBuyBack]
										,[Source].[BTComission]
										,[Source].[AfterBalance]
										,[Source].[Owner]
										,[Source].[Cancelled]
										,[Source].[ChangeDate]
										,[Source].[CreateDate]);						
			
			--Pre-CAL 904
			IF (@isExistBT = 1)
			BEGIN
				BEGIN TRY				
					DECLARE @CustIdsBT VARCHAR(MAX)
					SET @CustIdsBT = STUFF((SELECT ',' + CAST(tt.CustId AS VARCHAR(50))
											FROM #BetDelete tt 
											WHERE tt.betdaqid = 0
											  AND tt.extrainfo is null								    
											FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
					EXEC dbo.NAP_Admin_Calculate_904 
							  @MatchId 	= @MatchID
							, @Action 	= 'VOID'
							, @CustIds 	= @CustIdsBT				
				END TRY 
				BEGIN CATCH
					SELECT @ErrCode = 904
						 , @ErrMsg = 'Called NAP_Admin_Calculate_904 with error.'
				END CATCH										
			END
			
			--Pre-CAL 914
			IF (@isExistCashOut = 1)
			BEGIN
				BEGIN TRY
					DECLARE @CustIdsCashOut VARCHAR(MAX)
					SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
												 FROM @tblCustCashOut912 tt								    
												 FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')											    
					EXEC dbo.NAP_Admin_Calculate_914 
							  @MatchId 	= @MatchID
							, @Action 	= 'VOID'
							, @CustIds 	= @CustIdsCashOut
				END TRY 
				BEGIN CATCH
					SELECT	@ErrCode = 914
						,@ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
				END CATCH
			END
		END				  

		--STEP5: Update awinlost of normal, main bettrade, main cash-out, cash-out member bet ticket 
		UPDATE main  
		SET awinlost = 0  
		FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)  
		INNER JOIN #BetDelete AS tmpmain   
		ON main.transid = tmpmain.transid   
		 AND main.transid = tmpmain.grouptransid  
		 AND main.matchid = @matchid  

		--Get data after update 
		INSERT INTO @AfterUpd (
			 matchid
			,custid  
			,balanceType
			,BonusID
			,WalletType
			,balance  
		)  
		SELECT @MatchId AS matchid
			 , custid  
			 , CASE WHEN bettype IN (805, 806) THEN 4 ELSE 1 END AS balanceType  
			 , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			 , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance  
		FROM  
		(  
			-- normal, main bettrade, main cash-out, cash-out member bet ticket
			SELECT main.custid
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 0 ELSE main.BonusID END AS BonusID -- cash out sub tickets always bet from cash wallet
				 , CASE WHEN tmpmain.IsCashOutMemberTicket = 1 THEN 2 ELSE main.WalletType END AS WalletType -- cash out sub tickets always bet from cash wallet
				 , main.winlost, main.actual_stake ,main.playercomm, main.bettype  
			FROM bettrans main WITH (NOLOCK)  
				INNER JOIN #BetDelete tmpmain  
				ON main.transid = tmpmain.transid  
					AND main.transid = tmpmain.grouptransid  
					AND main.matchid = @matchid  			
			UNION ALL  
			-- bettrade subticket (901,902,903) 
			SELECT sub.custid
				 , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				 , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				 , sub.winlost, sub.actual_stake, sub.playercomm, sub.bettype  
			FROM bettrans sub WITH (NOLOCK)  
				INNER JOIN #BetDelete AS tmpmain   
				ON tmpmain.transid = sub.refno  
					AND sub.bettype BETWEEN 901 AND 910
					AND tmpmain.betdaqid = 0  
					AND tmpmain.extrainfo is null
					AND sub.matchid = @matchid  
			WHERE @isExistBT = 1
			UNION ALL
			-- cash-out subticket (911,912,913)	
			SELECT	b.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , b.winlost, b.actual_stake, b.playercomm, b.bettype
			FROM	bettrans b WITH (nolock)
				INNER JOIN #CashOutSubTicket sub
					 ON b.transid = sub.transid
			WHERE @isExistCashOut = 1									
			UNION ALL
			-- bettrade summary 904
			SELECT	sub904.custid
				  , 0 AS BonusID -- bet trade sub tickets always bet from cash wallet
				  , 2 AS WalletType -- bet trade sub tickets always bet from cash wallet
				  , sub904.winlost, sub904.actual_stake, sub904.playercomm, sub904.bettype  
			FROM	bettrans sub904 WITH (NOLOCK)
					INNER JOIN @tblCustBT902 temp
					ON sub904.custid = temp.custid										
			WHERE sub904.matchid 		= @matchid
				AND sub904.bettype 		= 904
			UNION ALL
			-- cash-out summary 914
			SELECT	sub914.custid
				  , 0 AS BonusID -- cash out sub tickets always bet from cash wallet
				  , 2 AS WalletType -- cash out sub tickets always bet from cash wallet
				  , sub914.winlost, sub914.actual_stake, sub914.playercomm, sub914.bettype
			FROM	bettrans sub914 WITH (NOLOCK)
					INNER JOIN @tblCustCashOut912 temp
					ON sub914.custid = temp.custid						
			WHERE sub914.matchid 		= @matchid
				AND sub914.bettype 		= 914	
		) tmp  
		GROUP BY CustID  
			   , CASE WHEN bettype IN (805, 806) THEN 4 ELSE 1 END
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		--UPDATE balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @beforeUpd
				, @BalanceWalletAfter	= @afterUpd
				, @ActionId				= 0	

		-- update totalbets
		DECLARE @Total TABLE (  
			oddsid INT  
			,HomeTotal MONEY  
			,AwayTotal MONEY  
		)  

		INSERT INTO @Total  
		SELECT oddsid  
		,SUM(CASE   
		 WHEN betteam = 'h' THEN (CASE   
		   WHEN ABS(odds) > 1 THEN ABS(odds)  
		   ELSE 1 END * b.stake * e.actualrate * (1 - b.tpositiontaking)  
		   )  
		 ELSE 0  
		 END) homeTotal  
		,SUM(CASE   
		 WHEN betteam = 'a' THEN (CASE   
		   WHEN ABS(odds) > 1 THEN ABS(odds)  
		   ELSE 1 END * b.stake * e.actualrate * (1 - b.tpositiontaking)  
		   )  
		 ELSE 0  
		 END) awayTotal  
		FROM dbo.bettrans AS b WITH (NOLOCK)  
		INNER JOIN custDB.dbo.exchange AS e WITH (NOLOCK) ON b.currency = e.exchangeid  
		WHERE bettype IN (1, 3, 7, 8)  
		AND ruben = 0  
		AND oddsid <> 0  
		AND matchid = @matchid  
		GROUP BY oddsid  

		UPDATE odds WITH (ROWLOCK, UPDLOCK)  
		SET hometotal = t.HomeTotal  
		,awaytotal = t.AwayTotal  
		FROM @Total t  
		WHERE odds.oddsid = t.oddsid  
		AND odds.matchid = @matchid  
		
		--UPDATE Mix and System parlay
		IF EXISTS (  
			SELECT 1  
			FROM #BetmDelete  
		)  
		BEGIN  
			DECLARE @rowcount  INT  
			,@step   INT = 0  
			,@transid_tmp VARCHAR(2000)  

			DECLARE @transtbl TABLE (id INT IDENTITY, transid BIGINT)  

			INSERT INTO @transtbl (transid)  
			SELECT transid  
			FROM #BetmDelete  

			SELECT @rowcount = @@ROWCOUNT  

			WHILE @step < @rowcount  
			BEGIN  
				SET @transid_tmp = ''  

				SELECT @transid_tmp = @transid_tmp + CONVERT(VARCHAR(20), transid) + ','  
				FROM @transtbl  
				WHERE id > @step  
				AND id <= @step + 100  

				SET @step = @step + 100  

				EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId  
				  ,@fth = 0  
				  ,@fta = 0  
				  ,@hth = 0  
				  ,@hta = 0  
				  ,@matchdate = @eventdate  
				  ,@mode = 'VOID'  
				  ,@VoidTransID = @transid_tmp  
				  ,@UserId = @UserId  
			END  

			--***********System parlay*********---  
			IF EXISTS (  
				SELECT TOP 1 1  
				FROM bettrans b WITH (NOLOCK)  
					INNER JOIN #BetmDelete r ON b.refno = r.refno  
				WHERE b.matchid = 29  
					AND b.bettype = 29  
			)  
			BEGIN  
				BEGIN TRY  
					DECLARE @transids_29 VARCHAR(MAX) = ''  
					,@refnos_29  VARCHAR(MAX) = ''  

					SELECT @transids_29 = @transids_29 + CONVERT(VARCHAR(20), maintransid) + ','  
					FROM #BetmDelete  
					WHERE Bettype = 29  
					GROUP BY maintransid  

					SELECT  @refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), maintransid)
					FROM #BetmDelete  
					WHERE Bettype = 29 
					  AND (mainstatusID IS NULL OR mainstatusID <> 102) 
					GROUP BY refno, maintransid

					SET @refnos_29 = STUFF(@refnos_29,1,1,'')

					EXEC dbo.NAP_Admin_Calculate_MP_broker  
						@matchid = @matchid  
						,@matchdate = @eventdate  
						,@strXML = @transids_29  
						,@mode  = 'PRECAL-29'  
				END TRY  
				BEGIN CATCH   
					SELECT @ErrCode = 100  
					, @ErrMsg = ERROR_MESSAGE()  
				END CATCH  
		
				---********* Calculate balance for system parlay********---  
				DECLARE @BeforeUpdSP	TVP_BalanceWalletChange
				DECLARE @AfterUpdSP		TVP_BalanceWalletChange

				--Get data before update  
				INSERT INTO @BeforeUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT @MatchId AS matchid
					 , b.custid  
					 , 1 AS balanceType
					 , 0 AS BonusID
					 , 2 AS WalletType
					 , SUM(b.winlost - b.actual_stake + b.playercomm) balance  					 
				FROM bettrans b WITH (NOLOCK)  
				 INNER JOIN #BetmDelete r ON b.refno = r.refno  
				WHERE b.matchid = 29  
				 AND b.bettype = 29  
				GROUP BY b.CustID  

				--Settlement System parlay (changed balance)  
				BEGIN TRY  
					EXEC dbo.NAP_Admin_Calculate_MP_broker  
					@matchdate = @eventdate  
					,@strXML = @refnos_29  
					,@mode  = '29'  
				END TRY  
				BEGIN CATCH   
					SELECT @ErrCode = 100  
					, @ErrMsg = ERROR_MESSAGE()  
				END CATCH  
		  
				--Get data after update  
				INSERT INTO @AfterUpdSP (matchid, custid, balanceType, BonusID, WalletType, balance)  
				SELECT @MatchId AS matchid
					 , b.custid  
					 , 1 AS balanceType
					 , 0 AS BonusID
					 , 2 AS WalletType
					 , SUM(b.winlost - b.actual_stake + b.playercomm) balance  					 
				FROM bettrans b WITH (NOLOCK)  
				 INNER JOIN #BetmDelete r ON b.refno = r.refno  
				WHERE b.matchid = 29  
				 AND b.bettype = 29  
				GROUP BY b.CustID  

				---insert data into pending balance table   
				EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					  @BalanceWalletBefore	 = @BeforeUpdSP
					, @BalanceWalletAfter	 = @AfterUpdSP
				
			 ---********* End of calculate balance for system parlay********---  
			END  
		END  
		
		------ releasing SD process  
		EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay	= @isExistParlay  
				, @isExistMG  	= @isExistMG  
				, @isExistFM  = @isExistFM  
				, @isExistMatch	= @isExistMatch  
				, @isExistBB	= @isExistBB
				, @IsReleased  	= 1
		
		------ releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1  
	   
		-- If void all marked tickets of one match (number of waiting/running marked tickets after voiding = 0), shall notify message to Settlement site
		DECLARE @allTransId VARCHAR(MAX) = ''

		SELECT	@allTransId = @allTransId + CAST(transid AS VARCHAR(20)) + ','
		FROM	#BetDelete

		EXEC dbo.NAP_SpecialDelete_CheckingMarkedTransaction
			@TransId = @allTransId
			,@Username = @Username
			,@MatchId = @MatchId		 

		SELECT @LogData = 'Void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' because of early kick off at ' + CONVERT(VARCHAR(23), @KickOffDate, 121)
			 + ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + ' reason: ' + @reason  + ' - ' + @ReasonSC

		EXEC WriteLog_UserLog @UserID = @UserID  
		,@Doing = @LogData		  

		-- Output new message structure  
		DECLARE @isITAdmin BIT   

		-- CHECK IT GROUP or NOT ? 
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)
		    
		;WITH CTE_CustIdAll AS (  
			SELECT DISTINCT t.custid  
			FROM #BetDelete b  
			CROSS APPLY (  
			 VALUES (custid)  
			 ,(creator)  
			 ,(recommend)  
			 ,(mrecommend)  
			 ,(srecommend)  
		) AS t (custid)  

		UNION ALL  
		SELECT DISTINCT t.custid  

		FROM #BetmDelete bm  
		CROSS APPLY (  
			 VALUES (custid)  
			 ,(creator)  
			 ,(recommend)  
			 ,(mrecommend)  
			 ,(srecommend)  
		) AS t (custid)  
		) 
		SELECT DISTINCT ci.custid  
		, ci.username  
		, ci.username2  
		, ci.site  
		, ci.currency
			INTO #CTE_CustInfo  
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)  
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		
		 
		SELECT al.odds  
			,al.oddsspread			
			,al.oddstype  
			,al.transdate 
			,al.OriginalBetType 
			,al.transid 
			,al.refno  
			,al.betteam
			,al.STATUS 
			,al.betfrom  
			,al.livehomescore  
			,al.liveawayscore  
			,al.stake  
			,al.currencyName  
			,al.betid  
			,al.betcheck
			,al.transdesc  
			,al.grouptransid
			,al.custid  
			,al.recommend  
			,al.mrecommend  
			,al.srecommend 
			,al.betdaqid
			,al.ExtraInfo 
			,al.MainCashoutId
			,al.WalletType
			,al.RefCode
			,al.Bettype AS BetTypeId
			,al.hdp1 AS Handicap1
			,al.hdp2 AS Handicap2
			,al.modds AS MasterOdds
			,al.IsMixParlay 
			,al.ParlayType AS SubBettype
			,al.choicehdp1 AS SubHdp1
			,al.choicehdp2 AS SubHdp2
			,al.choiceOdds AS SubOdds
			,al.choiceBetTeam AS SubBetteam
			,al.ChoiceBetCheck AS SubBetCheck
			,@SettlementStatus AS SettlementStatus
			,@GlobalShowTime AS GlobalShowTime
			-----------------------------  
			,ci.currency
			,ci.username
			,ci.username2 
			,ci.username AS CustUserName  
			,ci.username2 as CustUserName2  
			,ag.UserName AS AgUserName  
			,ma.UserName AS MagUserName  
			,su.Username AS SagUserName
			---------------------------------------  
			,CASE   
			WHEN al.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair'   
			ELSE su.site   
			END AS EmailGroup  
			,su.site   
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit  
			,CASE WHEN al.betdaqid = 0 AND al.extrainfo is null THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isBetTrade
			,CASE WHEN al.IsCashOutMemberTicket = 1 THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isCashOut  
			,@isITAdmin AS IsITSupport
			,al.IsMarked
		FROM (  
			SELECT al.odds  
			,al.odds AS choiceOdds 
			,al.oddsspread			
			,al.oddstype  
			,al.transdate  
			,al.Bettype
			,al.OriginalBetType  
			,CASE WHEN al.Bettype BETWEEN 801 AND 806 THEN al.refno ELSE al.transid END transid 
			,al.refno  
			,al.betteam  
			,al.betteam AS choiceBetTeam   
			,al.STATUS      
			,al.hdp1  
			,al.hdp2  
			,al.betfrom  
			,0 livehomescore  
			,0 liveawayscore  
			,al.stake  
			,al.currencyName  
			,al.betid  
			,al.betcheck  
			,al.betcheck ChoiceBetCheck  
			,CAST(0 AS BIT) AS IsMixParlay  
			,0 AS ParlayType  
			,al.transdesc  
			,al.grouptransid  
			,NULL AS modds  
			,al.betdaqid  
			,al.custid  
			,al.recommend  
			,al.mrecommend  
			,al.srecommend  
			,al.creator  
			,NULL AS choicehdp1  
			,NULL AS choicehdp2 
			,al.extrainfo
			,al.IsCashOutMemberTicket
			,al.MainCashoutId
			,al.WalletType
			,al.RefCode
			,al.BonusID
			,al.MainTransId
			,al.IsMarked
			FROM #BetDelete al			

			UNION ALL  
			SELECT bm.odds  
			,bm.choiceodds  
			,bm.oddsspread
			,bm.oddstype  
			,bm.transdate  
			,bm.bettype 
			,NULL AS OriginalBetType 
			,bm.maintransid AS transid
			,bm.refno  
			,bm.betteam  
			,bm.choiceBetteam  
			,bm.STATUS  
			,bm.hdp1  
			,bm.hdp2  
			,bm.betfrom  
			,0 AS livehomescore  
			,0 AS liveawayscore  
			,bm.stake  
			,bm.currencyName  
			,0 AS betid  
			,bm.betcheck  
			,bm.ChoiceBetCheck  
			,CAST(1 AS BIT) AS IsMixParlay  
			,bm.ParlayType  
			,bm.transdesc  
			,bm.maintransid AS grouptransid  
			,bm.modds  
			,1 betdaqid  
			,bm.custid  
			,bm.recommend  
			,bm.mrecommend  
			,bm.srecommend  
			,bm.creator  
			,bm.choicehdp1 AS choicehdp1  
			,bm.choicehdp2 AS choicehdp2  
			,NULL AS extrainfo
			,CAST(0 AS BIT) AS IsCashOutMemberTicket
			,NULL AS MainCashoutId 
			,NULL AS WalletType
			,NULL AS RefCode
			,NULL AS BonusID 
			,NULL AS MainTransId
			FROM #BetmDelete bm  
		) AS al  
			INNER JOIN #CTE_CustInfo ci WITH(NOLOCK)  
			ON al.custid = ci.custid  
			INNER JOIN #CTE_CustInfo ag WITH(NOLOCK)  
			ON al.recommend = ag.custid  
			INNER JOIN #CTE_CustInfo ma WITH(NOLOCK)  
			ON al.mrecommend = ma.custid  
			INNER JOIN #CTE_CustInfo su WITH(NOLOCK)  
			ON al.srecommend = su.custid  
			LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH(NOLOCK)   
			ON al.srecommend = s.custid        
		ORDER BY ISNULL(al.MainTransId, al.transid)  
			   , CASE 
					WHEN al.BonusID IS NOT NULL
							THEN CASE 
									WHEN al.MainTransId IS NULL THEN 1
									ELSE 2 
								 END
					ELSE al.transid
				 END
		DROP TABLE #CTE_CustInfo
		--Metric API Calling  
		SELECT al.refno  
			,al.Bettype  
			,al.custid  
			,b.statusID  
			,b.winlost  
			,al.odds  
			,al.OddsType  
			,al.stake   
			,al.transdesc  
			,tl.SiteId
		FROM #BetDelete al  
			INNER JOIN dbo.bettrans b WITH(NOLOCK)  
			ON al.transid = b.transid  
			AND b.matchid = @matchid  
			INNER JOIN dbo.translog tl WITH(NOLOCK)  
			ON tl.translogid = al.refno  
		WHERE al.Bettype IN (805,806)  
		ORDER BY al.refno  
	  
		-- Insert bettrade tickets to send API  
		IF(EXISTS(SELECT 1   
			FROM #BetDelete   
			WHERE betdaqid = 0 
			AND extrainfo is null 
			AND grouptransid = transid -- main ticket  
		))  
		BEGIN  			  		 
			;WITH cteMainTicket  
			AS(  
			SELECT transid  
			FROM #BetDelete   
			WHERE betdaqid = 0 
			  AND extrainfo is null 
			  AND grouptransid = transid -- main ticket  
			)  
		 
			INSERT INTO dbo.BettradeAPI (  
			transid  
			,matchid  
			,[Session]  
			,[action]  
			,buybackNo  
			,Payout  
			,Remark  
			)  
			SELECT b.TicketID  
				 ,b.MatchID  
				 ,@session  
				 ,'VOID'  
				 ,b.BuyBackNo  
				 ,b.PayOut  
				 ,'SB void ticket due to ' + @Reason  
			FROM dbo.BetTradeSelling b WITH(NOLOCK)  
			WHERE b.TicketID IN (SELECT transid FROM cteMainTicket)  
				AND b.[Status] IN ('Accept', 'Confirm')  
		END  
	END  
	DROP TABLE #tblMatchProcess  
	DROP TABLE #BetDelete  
	DROP TABLE #BetmDelete  
END