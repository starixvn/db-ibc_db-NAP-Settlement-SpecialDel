/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_BettransDelSpecialDel_EarlyKO]   
	 @MatchId			INT  
	,@KickOffDate		DATETIME  
	,@BetTypes			XML			 = NULL  	
	,@TransIds			VARCHAR(MAX) = ''  
	,@UserID			INT  
	,@UserName			NVARCHAR(50)  
	,@UserPassword		NVARCHAR(50)  
	,@Reason			NVARCHAR(500) = '' 
	,@ReasonSC			NVARCHAR(500) = ''
	,@IP				VARCHAR(15)	  = '' 
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
	- 20190911@Helen: Tuning Performance for Void Early KO Function - [Redmine:120058]
	- 20190909@Kathy: Do not update statuswinlost when voiding ticket [Redmine:#115376]
	- 20191101@Charles: Remove column IsMarked [122187]
	- 20200303@Charles: Copy 'epositiontaking' value from translog into bettrans [128921]
	- 20200609@Charles: Remove notify when void tickets [131865]
	- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode [137189]
	- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
	- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
	- 20201126@Charles: God of fortune [Redmine: #146053]
	- 20210303@July: Enhance data type advance mode [Redmine: #150075]
	- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
	- 20210523@Max: NAP Special Delele - The match locked Temp Variable Number while CSD doing void [Redmine: #155648]
	- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
	- 20210720@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
	- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
	- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
	- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
	- 20220301@July: Integrate Cricket AIO Phase 2 [Redmine:#168080]
	- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
	- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
	- 20220531@July: [TVS] Send data to Jacktime for Cashout Basketball [Redmine: #173389]
	- 20220712@Kathy: Do not using SELECT INTO [Redmine:#175349]
	- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	- 20221021@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]

Param's Explanation: Special bet delete option  
		- @BetTypes : 
		'<BetTypes>
			<BetType Id="1" 
					 BetTeam="a,h"			-- Default : "All" ; Format : h,a,o,u,o,e,...					 
					 Set="801"				-- Default : "All" ; Format : 80X ; Additional handled field : [Quarter]
					 Game="01"				-- Default : "All" ; Format : 0X 
					 BetOption="4-4,5-5"	-- Default : "All" ; Format : hdp2-betteam,...					 
					 Value="1,2,3"			-- Default : "All" ; Format : 1,2,3,4,... ;
					 ValueHdp1				-- Default : "All" ; Format : 1,2,3,4,... ;	
					 ValueHdp2				-- Default : "All" ; Format : Single Number
					 Goal="2"				-- Default : "All" ; Format : Single Number
					 OddsSpread="1.5"		-- Default : "All" ; Format : 1.5,0.5,1.0,...
					 OddsId ="10006450"		-- Default : "All" ; Format : Single Number
					 Transdesc = '100001'	-- Default : "All" ; Format : Single Number (PlayerId - [Team].[TeamID])
			/>
		 <BetTypes/>'
*/  
BEGIN  
	SET NOCOUNT ON 		 

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN		
			SET @sqlCommand = 'EXEC dbo.NAP_BettransDelSpecialDel_EarlyKO '
				+ CASE WHEN @UserID IS NULL THEN '' ELSE '@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
				+ CASE WHEN @MatchId IS NULL THEN '' ELSE ',@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
				+ CASE WHEN @KickOffDate IS NULL THEN '' ELSE ',@KickOffDate = ''' + CONVERT(NVARCHAR(50), @KickOffDate, 21) +'''' END
				+ CASE WHEN @BetTypes IS NULL THEN '' ELSE ',@BetTypes = ''' + CONVERT(NVARCHAR(MAX), @BetTypes) +'''' END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) +'''' END
				+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) +'''' END
				+ CASE WHEN @UserPassword IS NULL THEN '' ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) +'''' END
				+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) +'''' END
				+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) +'''' END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) +'''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH

	DECLARE @eventdate		DATETIME 
			,@LogData		NVARCHAR(500)     
			,@Remark		VARCHAR(500) 
			,@CountTransId	INT
			,@FCUpdateTime		DATETIME2

	DECLARE @isExistMatch		BIT = 0  
			,@isExistFM			BIT = 0 
			,@isExistParlay		BIT = 0  
			,@avaiableProcess	BIT
			,@IsExistBB			BIT = 0
			,@isExistFM2		BIT = 0
			,@ValueDefault		SMALLMONEY = 9999.00
			,@ErrMsg			NVARCHAR(200)	= ''
			,@ErrCode			INT				= 0	  
			,@SiteDBGroupID		SMALLINT
			,@transInfo			XML = ''
			,@transInfo3rd		XML = ''

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)
	
	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
	
	DECLARE @Session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))	 	 
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalSubParlay		INT = 0

	DECLARE @ResultDetail3rd AS TABLE ([ResultID] [int] ,[GameID] [int] ,[Custom1] [nvarchar](50) )
	DECLARE @queryResultDetail NVARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''
	
	CREATE TABLE #tblBetType
	(
		Id				SMALLINT,		 				
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		BetOption		NVARCHAR(50),
		[Value]			SMALLMONEY,	
		ValueHdp1		SMALLMONEY,	
		ValueHdp2		SMALLMONEY,
		Goal			BIGINT,
		OddsSpread		MONEY,
		OddsId			INT,
		Transdesc		NVARCHAR(1000)
	)   

	CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)  
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)	

	CREATE TABLE #BetDelete (  
		grouptransid	BIGINT  
		,transid		BIGINT  
		,refno			BIGINT  
		,betid			BIGINT  
		,stake			MONEY  
		,odds			SMALLMONEY  
		,oddsspread		MONEY
		,custid			INT  
		,recommend		INT  
		,mrecommend		INT  
		,srecommend		INT  
		,betfrom		NVARCHAR(3)  
		,STATUS			VARCHAR(20)  
		,statusID		INT  
		,creator		INT  
		,Bettype		SMALLINT 
		,betdaqid		BIGINT  
		,creatorName	NVARCHAR(50)  
		,username		NVARCHAR(50)  
		,username2		NVARCHAR(50)  
		,OddsType		TINYINT  
		,Transdate		DATETIME  
		,betteam		NVARCHAR(10)  
		,hdp1			SMALLMONEY  
		,hdp2			SMALLMONEY  
		,currencyName	NVARCHAR(50)  
		,betcheck		NVARCHAR(50)  
		,transdesc		NVARCHAR(1000) 
		,ExtraInfo		VARCHAR(1000) 
		,IsCashOut		BIT DEFAULT(0)
		,awinlost		MONEY
		,matchid		INT
		,WalletType		TINYINT
		,RefCode		BIGINT
		,BonusID		INT
		,MainTransId	BIGINT
		,ActualStake	MONEY
		,Winlost		MONEY
		,OddsId			INT
	)

	CREATE TABLE #CTE_CustInfo(custid INT, username VARCHAR(30), username2 VARCHAR(50), site VARCHAR(10), currency TINYINT)

	CREATE TABLE #BetmDelete (  
		transid			BIGINT  
		,refno			BIGINT  
		,custid			INT  
		,recommend		INT  
		,mrecommend		INT  
		,srecommend		INT  
		,odds			SMALLMONEY  
		,oddsspread		MONEY
		,choiceodds		SMALLMONEY  
		,OddsType		TINYINT  
		,Transdate		DATETIME  
		,Bettype		SMALLINT  
		,ParlayType		SMALLINT  
		,betteam		NVARCHAR(10)  
		,choicebetteam  NVARCHAR(10)  
		,choicehdp1		SMALLMONEY  
		,choicehdp2		SMALLMONEY  
		,hdp1			SMALLMONEY  
		,hdp2			SMALLMONEY  
		,creatorname	NVARCHAR(50)  
		,username		NVARCHAR(50)  
		,username2		NVARCHAR(50)  
		,stake			MONEY  
		,currencyName	NVARCHAR(50)  
		,choiceBetCheck NVARCHAR(50)  
		,betcheck		NVARCHAR(50)  
		,maintransid	BIGINT  
		,betfrom		NVARCHAR(3)  
		,STATUS			VARCHAR(20)  
		,statusid		TINYINT  
		,creator		INT  
		,modds			SMALLMONEY  
		,transdesc		NVARCHAR(1000)
		,mainstatusID	INT
		,ExtraInfo		VARCHAR(1000)
		,ActualStake	MONEY
		,main_ruben		TINYINT
		,main_custId	INT
		,Winlost		MONEY
	)  

	DECLARE @Status TABLE (statusID TINYINT)  

	DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT, custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, Bonusid INT, WalletType TINYINT, bettype INT, betdaqid BIGINT, status VARCHAR(20))
	
	SELECT @ErrCode = 0  
		 , @ErrMsg = ''

	DECLARE @SettlementStatus TINYINT = NULL
			,@GlobalShowTime SMALLDATETIME
			,@sporttype SMALLINT = NULL
			,@ParentID INT = NULL
			,@ChildMatchType TINYINT = NULL

	SELECT @eventdate = m.eventdate 
		  ,@SettlementStatus = m.SettlementStatus 
		  ,@GlobalShowTime = m.GlobalShowTime
		  ,@sporttype = m.sporttype
		  ,@ParentID = ISNULL(m.ParentID, 0)
		  ,@ChildMatchType = ISNULL(m.ChildMatchType, 0)
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
		,@ErrCode = 113				 

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			,@SiteDBGroupID AS SiteDBGroupID

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
		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			,@SiteDBGroupID AS SiteDBGroupID

		RETURN  
	END  

	BEGIN TRY  
		INSERT INTO #tblTransIds (transid)  
		SELECT DISTINCT value   
		FROM STRING_SPLIT(@TransIds,',')   
		
		SET @CountTransId = @@ROWCOUNT 

	END TRY  
	BEGIN CATCH  
		SELECT @ErrCode = 114  
		,@ErrMsg = 'Invalid TransIds.'	
		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			,@SiteDBGroupID AS SiteDBGroupID

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
			 , t.c.value('@ValueHdp1','VARCHAR(500)') AS ValueHdp1	-- check columns : hdp1			 ; single-choice + multi-choice
			 , t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2			 ; single-choice
			 , t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			 , t.c.value('@OddsSpread', 'VARCHAR(20)') AS OddsSpread	-- Check columns : OddsSpread ; single value
			 , t.c.value('@OddsId','VARCHAR(20)') AS OddsId			-- check columns : OddsId		 ; single-choice
			 , t.c.value('@Transdesc','NVARCHAR(1000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.value AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , bop.value AS BetOption
			 , CAST(CASE
						WHEN v.value = 'ALL' THEN @ValueDefault
						ELSE v.value
					END AS SMALLMONEY) AS [Value]
			 , CAST(CASE
						WHEN vhdp1.value = 'ALL' THEN @ValueDefault 
						ELSE vhdp1.value END AS SMALLMONEY) AS ValueHdp1
			 , CAST(CASE 
			 			WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault
						ELSE cte.ValueHdp2 END AS SMALLMONEY) AS ValueHdp2				 
			 , CAST(CASE 
						WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal
					END AS BIGINT) AS Goal
			, CAST(CASE WHEN cte.OddsSpread = 'ALL' THEN @ValueDefault 
						ELSE cte.OddsSpread END AS MONEY) AS OddsSpread
			, CAST(CASE WHEN cte.OddsId = 'ALL' THEN NULL 
						ELSE cte.OddsId END AS INT) AS OddsId
			, cte.Transdesc
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
			 CROSS APPLY STRING_SPLIT(cte.BetOption, ',') bop
			 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
			 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, BetOption, [Value], ValueHdp1, ValueHdp2, Goal, OddsSpread, OddsId, Transdesc)
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
		 , cte.[Value]
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.Goal
		 , cte.OddsSpread
		 , cte.OddsId
		 , cte.Transdesc
	FROM CTE_ParsedBettypes cte	
	WHERE CASE
				WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
				ELSE 1
		  END = 1
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))

	BEGIN --SD checking process  
	SELECT @isExistMatch  = MAX (CASE WHEN b.Bettype NOT IN (29, 38) AND f.GroupId IS NULL THEN 1 ELSE 0 END)  
		    ,@isExistFM  = MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)  
			,@isExistBB	 = MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistFM2 = MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM dbo.bettrans b WITH (NOLOCK)  
		INNER JOIN #tblTransIds t ON t.transid = b.transid  
		INNER JOIN #tblBettype tp ON tp.Id = b.bettype
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	WHERE b.matchid = @matchid  

	IF(EXISTS (SELECT 1 FROM #tblBettype WHERE Id = 29))    
	BEGIN  
		INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
		SELECT @MatchId, sub.refno
		FROM dbo.bettransm AS sub WITH (NOLOCK)  
			INNER JOIN dbo.bettrans AS main WITH (NOLOCK)  
			ON sub.refno = main.refno  
			INNER JOIN #tblTransIds t   
			ON t.transid = sub.transid  
		WHERE main.matchid  = 29 AND main.bettype = 29 
			AND sub.matchid  = @matchid
			AND sub.statusID NOT IN (101, 102)  

		SET @totalSubParlay = @@ROWCOUNT
		IF @totalSubParlay > 0 
			SET @isExistParlay = 1
	END  

	EXEC dbo.NAP_Set_GlobalSettingSel 
			 @LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

	INSERT INTO #tblMatchProcess(matchid, KeyID)  
	SELECT @matchid AS matchid, 1 AS KeyID WHERE @isExistMatch = 1  
	UNION ALL  
	SELECT @matchid AS matchid, 6 AS KeyID WHERE @isExistFM = 1  
	UNION ALL
	SELECT @matchid AS matchid, 5 AS KeyID WHERE @isExistBB = 1
	UNION ALL
	SELECT @matchid AS matchid, 7 AS KeyID WHERE @isExistFM2 = 1

	-- check and not allow attempt to void tickets of this match while it's being calculated
	-- Apply new way to lock parlay tickets  
	IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
		BEGIN
			-- checking single proccess		
			EXEC dbo.NAP_Admin_CheckingProcess   
				  @isExistFM		= @isExistFM  
				, @isExistMatch		= @isExistMatch  
				, @isExistBB		= @isExistBB
				, @isExistFM2		= @isExistFM2
				, @spName			= @spName
				, @avaiableProcess  = @avaiableProcess OUTPUT  
				, @ErrCode			= @ErrCode OUTPUT  
				, @ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN	
				SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					,@SiteDBGroupID AS SiteDBGroupID

				RETURN		
			END
		END
		
		IF @totalSubParlay > 0 
		BEGIN	
			-- checking refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsLockingByRefno	= 1
				,@spName			= @spName
				,@Session			= @Session
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0)   
			BEGIN		
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess   
					  @isExistFM	= @isExistFM  
					, @isExistMatch	= @isExistMatch  
					, @isExistBB	= @isExistBB
					, @isExistFM2	= @isExistFM2
					, @IsReleased  	= 1

				SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					,@SiteDBGroupID AS SiteDBGroupID

				RETURN;  
			END 
		END
	END
	ELSE IF @totalSubParlay > @ThreadHold
	BEGIN
		-- checking SD proccess
		EXEC dbo.NAP_Admin_CheckingProcess  
			@isExistParlay		= @isExistParlay  
			, @isExistFM		= @isExistFM  
			, @isExistMatch		= @isExistMatch  
			, @isExistBB		= @isExistBB
			, @isExistFM2		= @isExistFM2
			, @spName			= @spName
			, @avaiableProcess  = @avaiableProcess OUTPUT  
			, @ErrCode			= @ErrCode OUTPUT  
			, @ErrMsg			= @ErrMsg OUTPUT  

		IF(@ErrCode <> 0 OR @avaiableProcess = 0)   
		BEGIN	
			SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					,@SiteDBGroupID AS SiteDBGroupID

			RETURN  
		END
	END

	END -- end SD checking process		

	-- Apply for move match Cricket
	IF EXISTS ( SELECT TOP 1 1 
				FROM #tblTransIds t
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON b.transid = t.transid
				WHERE matchid <> @MatchId
			)
		OR EXISTS ( SELECT TOP 1 1 
				FROM #tblTransIds t
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON bm.transid = t.transid
					INNER HASH JOIN dbo.bettrans b WITH (NOLOCK) ON bm.refno = b.refno  
				WHERE b.matchid = 29  
					AND b.bettype = 29   
					AND bm.matchid  <> @matchid  
			)
	BEGIN
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Some tickets not found.'

		IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess   
					  @isExistFM	= @isExistFM  
					, @isExistMatch	= @isExistMatch  
					, @isExistBB	= @isExistBB
					, @isExistFM2	= @isExistFM2
					, @IsReleased  	= 1
			END
			
			IF @totalSubParlay > 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END

			SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					,@SiteDBGroupID AS SiteDBGroupID

			RETURN
		END
		ELSE IF @totalSubParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay	= @isExistParlay  
				, @isExistFM	= @isExistFM  
				, @isExistMatch	= @isExistMatch  
				, @isExistBB	= @isExistBB
				, @isExistFM2	= @isExistFM2
				, @IsReleased  	= 1

			SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					,@SiteDBGroupID AS SiteDBGroupID
			
			RETURN
		END
	END

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
		,IsCashOut
		,awinlost 
		,WalletType
		,RefCode
		,BonusID
		,ActualStake
		,Winlost
		,OddsId
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
		,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut 
		,b.awinlost
		,b.WalletType
		,b.RefCode
		,b.BonusID
		,b.actual_stake AS ActualStake
		,b.winlost - b.actual_stake AS Winlost
		,b.OddsId
	FROM (SELECT TOP (@CountTransId) * FROM #tblTransIds) t
		 INNER JOIN bettrans b WITH (NOLOCK)  
				 ON t.transid = b.transid
	WHERE b.matchid = @matchid  
	  AND b.transdate >= @KickOffDate  
	  AND b.liveindicator = 0  
	  AND b.bettype NOT IN (805, 806, 29)	 
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
	  AND b.SiteDBGroupID = @SiteDBGroupID
	OPTION (OPTIMIZE FOR (@CountTransId = 1))
	
	/*
		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY
		
		filter for Game : Only handle for bettype 1324
		 
		filter for BetOption : Only handle for bettypes 221 -> 227
		 
		filter for [Value]
		
		filter for ValueHdp1
		 
		filter for ValueHdp2

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
								WHEN tp.ValueHdp1 = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp1 = tp.ValueHdp1 THEN 1
										ELSE 0
									 END
							END = 1)

	DELETE s
	FROM #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.ValueHdp2 = 9999 THEN 1				
								ELSE CASE
										WHEN s.hdp2 = tp.ValueHdp2 THEN 1
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

	DELETE s
	FROM #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.OddsSpread = 9999 THEN 1				
								ELSE CASE
										WHEN s.oddsspread = tp.OddsSpread THEN 1
										ELSE 0
									 END
							END = 1)
	
	/*Apply for bettypes Cricket 2.0 [168080]*/
	DELETE s
	FROM  #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND (tp.OddsId IS NULL OR s.OddsId = tp.OddsId )) 
	
	DELETE s
	FROM  #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND  (tp.Transdesc = 'ALL' OR s.transdesc = tp.Transdesc))
	
	END	 		  

	--GET sub ticket of the matchid for mix parlay  
	IF EXISTS( SELECT TOP 1 1 FROM #tblBettype WHERE Id = 29)  
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
			,ExtraInfo
			,ActualStake
			,main_ruben
			,main_custId
			,Winlost
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
			,main.ExtraInfo
			,main.actual_stake AS ActualStake
			,main.ruben
			,main.custid
			,main.winlost - main.actual_stake AS Winlost
		FROM #tblTransIds t
			INNER LOOP JOIN dbo.bettransm AS sub WITH (NOLOCK) ON t.transid = sub.transid  
			INNER HASH JOIN dbo.bettrans main WITH (NOLOCK) ON sub.refno = main.refno AND main.matchid = 29
			INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = sub.custid  
			INNER JOIN CustDB.dbo.custInfo cr WITH(NOLOCK) ON cr.custid = main.creator  
		WHERE sub.matchid = @matchid  
			AND sub.transdate >= @KickOffDate  
			AND sub.liveindicator = 0  
			AND sub.betfrom <> 'P'  
			AND main.bettype = 29
			AND sub.statusID NOT IN (101, 102)  
			AND (  
			 main.betid = 0  
			 OR main.betid IS NULL  
			) 
			AND main.SiteDBGroupID = @SiteDBGroupID
	END  
	
	------------------***** End of insert all data into #BetDelete,#BetmDelete *****------------------	
	
	-- check ticket's status  
	INSERT INTO @Status (statusID) VALUES (102),(101),(112),(113),(111)  

	IF EXISTS (  
	SELECT 1  
	FROM #BetDelete  
	WHERE statusID IN (111, 112, 113) AND IsCashOut <> 1 -- settled  
	UNION ALL  
	SELECT 1  
	FROM #BetmDelete  
	WHERE statusID IN (111, 112, 113)
	)  
	BEGIN  
		SELECT @ErrCode = 117
			  ,@ErrMsg = 'You can only void the unsettled or refunded tickets.'  
	END  

	DELETE  
	FROM #BetDelete  
	WHERE statusID IN (SELECT statusID FROM @Status) AND IsCashOut <> 1

	DELETE  
	FROM #BetmDelete  
	WHERE statusID IN (SELECT statusID FROM @Status) 
	
	--check no data  
	IF ( NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)   
	AND NOT EXISTS (SELECT TOP 1 1 FROM #BetmDelete)  
	)  
	BEGIN  
		-- check for previous error-message 
		SELECT @ErrMsg	= CASE WHEN @ErrCode = 0 THEN 'No ticket found.' ELSE @ErrMsg END  
			  ,@ErrCode = CASE WHEN @ErrCode = 0 THEN 99 ELSE @ErrCode END  

		IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess   
					  @isExistFM	= @isExistFM  
					, @isExistMatch	= @isExistMatch  
					, @isExistBB	= @isExistBB
					, @isExistFM2	= @isExistFM2
					, @IsReleased  	= 1
			END
			
			IF @totalSubParlay > 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END
		END
		ELSE IF @totalSubParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay	= @isExistParlay  
				, @isExistFM	= @isExistFM  
				, @isExistMatch	= @isExistMatch  
				, @isExistBB	= @isExistBB
				, @isExistFM2	= @isExistFM2
				, @IsReleased  	= 1
		END
	END  
	ELSE  
	BEGIN
		-- Create temp table to calculate balance  
		DECLARE @BeforeUpd TVP_BalanceWalletChange
		DECLARE @AfterUpd  TVP_BalanceWalletChange
	  
		------------------***** Begin special delete early kickoff *****------------------  
		-- STEP 1 : BackUp bettrans  
		-- 1.1  Backup normal ticket 
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
			,RepUpdateTime
			,SiteDBGroupID
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
			,main.betcheck
			,main.checktime  
			,main.matchid  
			,main.bettype 
			,SYSDATETIME()
			,main.SiteDBGroupID
		FROM dbo.bettrans AS main WITH (NOLOCK)  
			INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK)   
			ON main.transid = tmpmain.grouptransid  
			 AND main.transid = tmpmain.transid   
			 AND main.matchid = @matchid  
		   
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
			,RepUpdateTime
			,SiteDBGroupID
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
			,SYSDATETIME()
			,bm.SiteDBGroupID
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
			,RepUpdateTime
			,SiteDBGroupID
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
			,SYSDATETIME()
			,bm.SiteDBGroupID
		FROM bettransm AS bm WITH (NOLOCK)  
		INNER JOIN #BetmDelete AS tmpbm  
		ON bm.transid = tmpbm.transid  	

		-- STEP 3 : Update bettrans
		-- 3.1. Update normal ticket  
		SET @FCUpdateTime = SYSDATETIME()
		UPDATE main  
		SET   
			winlost = main.actual_stake  
			,ruben = 1  
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
			,betid = main.betid
			,FcUpdateTime = @FCUpdateTime
				OUTPUT deleted.Transid,
						deleted.custid,  
						deleted.winlost,
						deleted.actual_stake,
						deleted.playercomm,
						deleted.BonusID,
						deleted.WalletType,
						deleted.bettype,
						deleted.betdaqid,
						deleted.status
				INTO @tmpTrans_beforeUpd (transid, custid, winlost, actual_stake, playercomm,Bonusid, WalletType, bettype, betdaqid, status)
		FROM dbo.bettrans AS main WITH (ROWLOCK, UPDLOCK)  
			INNER JOIN #BetDelete AS tmpmain ON main.transid = tmpmain.transid  AND main.transid = tmpmain.grouptransid  
		WHERE main.matchid = @matchid 
		
		SET @transInfo = (
			SELECT	t.transId AS '@t'
					, b.winlost AS '@w'
					, b.ruben AS '@r'
					, b.creator AS '@cr'
					, b.awinlost AS '@aw'
					, b.mwinlost AS '@mw'
					, b.swinlost AS '@sw'
					, b.playercomm AS '@pc'
					, b.comm AS '@c'
					, b.acomm AS '@ac'
					, b.scomm AS '@sc'
					, b.statusID AS '@sid'
					, b.status AS '@s'
					, b.betid AS '@bid'
					, b.ExtraInfo AS '@ex'
					, b.FcUpdateTime AS '@rut'
			FROM	#BetDelete t 
				INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
			WHERE t.Bettype NOT IN (38)
			FOR XML PATH('r'),ROOT('root'), TYPE)

		SET @transInfo3rd = (
			SELECT	t.transId AS '@t'
					, b.winlost AS '@w'
					, b.ruben AS '@r'
					, b.creator AS '@cr'
					, b.awinlost AS '@aw'
					, b.mwinlost AS '@mw'
					, b.swinlost AS '@sw'
					, b.playercomm AS '@pc'
					, b.comm AS '@c'
					, b.acomm AS '@ac'
					, b.scomm AS '@sc'
					, b.statusID AS '@sid'
					, b.status AS '@s'
					, b.betid AS '@bid'
					, b.ExtraInfo AS '@ex'
					, b.FcUpdateTime AS '@rut'
			FROM	#BetDelete t 
				INNER JOIN @tmpTrans_beforeUpd tp ON tp.transid = t.TransID
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.TransID
			WHERE t.Bettype IN (38)
			FOR XML PATH('r'),ROOT('root'), TYPE)
		
		IF @SiteDBGroupID <> 0 AND @transInfo <> ''
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
			SELECT 'TVS', 'VoidEKO', 'bettrans', 'U', @matchid, @transInfo
		END
		IF @SiteDBGroupID <> 0 AND @transInfo3rd <> ''
		BEGIN
			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog_3rd (SystemName, FunctionName, TableName, Action, MatchId, TransInfo, TicketType, EventTable)
			SELECT 'TVS', 'VoidEKO', 'bettrans', 'U', @matchid, @transInfo3rd, 's', 1
		END

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
			 , 1 AS balanceType
			 , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			 , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance  
		FROM  
		(  
			-- normal ticket
			SELECT main.custid
				 , main.BonusID
				 , main.WalletType
				 , main.winlost, main.actual_stake ,main.playercomm, main.bettype  
			FROM @tmpTrans_beforeUpd main
			INNER JOIN #BetDelete tmpmain  
				ON main.transid = tmpmain.transid  
				AND main.transid = tmpmain.grouptransid  
		) tmp  

		GROUP BY CustID  
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets
		
		--Correct data captured before because CO happen when voiding ticket
		IF EXISTS (SELECT TOP(1) 1 FROM #BetDelete	b
						INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
					WHERE b.IsCashOut = 0 AND t.betdaqid = -2 )
		BEGIN
			UPDATE b
			SET b.status = t.status
				, b.WinLost = t.winlost - t.actual_stake
				, b.ActualStake = t.actual_stake
				, b.betdaqid = -2
				, b.IsCashOut = 1
			FROM #BetDelete b 
				INNER JOIN @tmpTrans_beforeUpd t ON t.transid = b.transid
			WHERE b.IsCashOut = 0 
				AND t.betdaqid = -2

			UPDATE z
			SET z.status = t.status
				, z.winlost = t.winlost
			OUTPUT deleted.matchid, deleted.transid, t.status, t.winlost
			INTO @tmpTransInfo (matchid, transid, STATUS, winlost)
			FROM zzzbettrans z WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @tmpTrans_beforeUpd t ON t.transid = z.transid
			WHERE z.status <> t.status
				AND t.betdaqid = -2
			
			SET @transInfo = NULL
			SET @transInfo = (
					SELECT	transId AS '@t'
							, matchid AS '@mid'
							, STATUS AS '@s'
							, winlost AS '@w'
					FROM	@tmpTransInfo WHERE matchid = @MatchId 
					FOR XML PATH('r'),ROOT('root'), TYPE)

			IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfo)
				SELECT 'TVS', 'VoidEKO', 'zzzbettrans', 'U', @matchid, @transInfo 
			END
		END
		
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
			 , 1 AS balanceType  
			 , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END AS BonusID
			 , ISNULL(tmp.WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
			 , SUM(winlost - actual_stake + playercomm) balance  
		FROM  
		(  
			-- normal ticket
			SELECT main.custid
				 , main.BonusID
				 , main.WalletType
				 , main.winlost, main.actual_stake ,main.playercomm, main.bettype  
			FROM bettrans main WITH (NOLOCK)  
				INNER JOIN #BetDelete tmpmain  
				ON main.transid = tmpmain.transid  
					AND main.transid = tmpmain.grouptransid  
					AND main.matchid = @matchid  			
		) tmp  
		GROUP BY CustID  
			   , CASE WHEN tmp.BonusID > 0 AND tmp.WalletType = 1 THEN tmp.BonusID ELSE 0 END
			   , ISNULL(tmp.WalletType, 2) -- normal tickets are treated as cash tickets

		--UPDATE balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @beforeUpd
				, @BalanceWalletAfter	= @afterUpd
				, @ActionId				= 0	

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

				--Prepare for Max Payout
				SELECT @MainParlay_MaxPO = (SELECT t.main_custId AS '@custid'
											,t.main_ruben AS '@ruben'
											,t.maintransid AS '@transid'
										FROM #BetmDelete t
										GROUP BY main_custId, main_ruben, maintransid
										FOR XML PATH('r'), ROOT('root')
									)
				
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
		
		--Update CashOutSelling for new CO Model
		UPDATE c
		SET CashOutStatus = 6 --Void
		   ,ChangeDate = GETDATE()
		FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
			INNER JOIN #BetDelete b ON c.TransID = b.transid AND c.MatchID = @MatchId
		WHERE b.IsCashOut = 1

		IF @totalSubParlay = 0 OR @totalSubParlay <= @ThreadHold
		BEGIN
			IF EXISTS (SELECT TOP 1 1 FROM #tblMatchProcess)
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess   
					  @isExistFM	= @isExistFM  
					, @isExistMatch	= @isExistMatch  
					, @isExistBB	= @isExistBB
					, @isExistFM2	= @isExistFM2
					, @IsReleased  	= 1
			END

			IF @totalSubParlay > 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1
			END
		END
		ELSE IF @totalSubParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess  
				@isExistParlay	= @isExistParlay  
				, @isExistFM	= @isExistFM  
				, @isExistMatch	= @isExistMatch  
				, @isExistBB	= @isExistBB
				, @isExistFM2	= @isExistFM2
				, @IsReleased  	= 1
		END
		
		----------------Insert Max Payout Queue----------------
		DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @MatchId_MaxPO INT = NULL

		SET @MatchId_MaxPO = CASE WHEN @sporttype = 50 AND @ParentID <> 0 AND @ChildMatchType = 200 THEN @ParentID ELSE @MatchId END

		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
						,CASE 
							WHEN dp.custid IS NOT NULL THEN 3 --deposit 
							WHEN c.site = '789y' THEN 2 --789y
							ELSE 1 END AS '@sitetype'
						,b.TransId AS '@transid'
						,b.Bettype AS '@bettype'
					FROM #BetDelete b
						INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
						LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
					FOR XML PATH('r'), ROOT('root')
				)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId_MaxPO
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO

		IF @MainParlay_MaxPO IS NOT NULL
		BEGIN
			--Insert Max Payout Queue
			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
		END
		-------------------------------------------------------
		
		SELECT @LogData = 'Void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' because of early kick off at ' + CONVERT(VARCHAR(23), @KickOffDate, 121)
			 + ' IP=' + COALESCE(CAST(@IP AS VARCHAR(15)), SPACE(1)) + ' reason: ' + @reason  + ' - ' + @ReasonSC

		EXEC WriteLog_UserLog @UserID = @UserID  
		,@Doing = @LogData		  

		-- Output new message structure  
		DECLARE @isITAdmin BIT   

		-- CHECK IT GROUP or NOT ? 
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

		--1. Table return error code/ msg
		SELECT @ErrCode AS ErrorCode
			,@ErrMsg AS ErrorMsg
			,@SiteDBGroupID AS SiteDBGroupID
		    
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
		INSERT INTO #CTE_CustInfo(custid, username, username2, site, currency)
		SELECT DISTINCT ci.custid  
		, ci.username  
		, ci.username2  
		, ci.site  
		, ci.currency
		FROM CustDB.dbo.Customer ci WITH(NOLOCK)  
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid		
		 
		SELECT al.odds  
			,al.oddsspread			
			,al.oddstype  
			,al.transdate 
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
			,al.IsCashOut
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
			,al.ActualStake
			,ci.currency
			,ci.username
			,ci.username2 
			,ci.username AS CustUserName  
			,ci.username2 as CustUserName2  
			,ag.UserName AS AgUserName  
			,ma.UserName AS MagUserName  
			,su.Username AS SagUserName
			,CASE WHEN al.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair'   
				  ELSE su.site   
				END AS EmailGroup  
			,su.site   
			,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit  
			,@isITAdmin AS IsITSupport
			,al.Winlost
			,@sporttype AS SportTypeId
		FROM (  
			SELECT al.odds  
			,al.odds AS choiceOdds 
			,al.oddsspread			
			,al.oddstype  
			,al.transdate  
			,al.Bettype
			,al.transid
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
			,al.IsCashOut
			,al.WalletType
			,al.RefCode
			,al.BonusID
			,al.MainTransId
			,al.ActualStake
			,al.Winlost
			FROM #BetDelete al			
			UNION ALL  
			SELECT bm.odds  
			,bm.choiceodds  
			,bm.oddsspread
			,bm.oddstype  
			,bm.transdate  
			,bm.bettype 
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
			,bm.ExtraInfo
			,0 AS IsCashOut 
			,NULL AS WalletType
			,NULL AS RefCode
			,NULL AS BonusID 
			,NULL AS MainTransId
			,bm.ActualStake
			,bm.Winlost
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
	END  

	-- Write useraction log 
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN       
                INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
                VALUES (@ID, @spName, NULL, @UserId, @MatchId, GETDATE(),@SubmittedDate)
        END       
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #tblMatchProcess  
	DROP TABLE #BetDelete  
	DROP TABLE #BetmDelete
	DROP TABLE #tblMatchParlayProcess
  
END