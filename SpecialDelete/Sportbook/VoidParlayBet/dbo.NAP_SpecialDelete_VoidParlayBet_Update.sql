/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlayBet_Update]  
	  @MatchId				INT 
	, @Type					SMALLINT		= 0   
	, @LiveHomeScore		SMALLINT		= NULL
	, @LiveAwayScore		SMALLINT		= NULL    
	, @FromTransdate		DATETIME		= NULL
	, @ToTransdate			DATETIME		= NULL 
	, @BetTypes				XML				= NULL
	, @TransIds				VARCHAR(MAX)	= '' 
	, @UserId				INT
	, @UserName				NVARCHAR(50)
	, @UserPassword			NVARCHAR(50)
	, @Ip					VARCHAR(15)		= ''
	, @Reason				NVARCHAR(500)	=''
	, @ReasonSC				NVARCHAR(500)	=''
	, @Language				NVARCHAR(2)		= 'E'    
AS 
/*  
	 Created by: Paul  
	 Date:   
	 Task: Delete transaction of mix parlay bet in bettransm  
	 DB: DBTXN/bodb02  
	 Original: NAP_BettransDelSpecialDel_MixParlay
   
	 Revisions:  
		- 20170814@Paul: Create new SP; Allow voiding settled tickets [Redmine:#81481]
		- 20170918@Kent: Add New Bettypes Decimal Only 461, 462, 463, 464 [Redmine:#83255]
		- 20171009@Kent: PH AIO Phase 3 [Redmine:#83737]
		- 20180327@Helen:  Correct Transdesc column size [Redmine: #92810]
		- 20180507@Alan: Change result for new template email - Delete Creator, Match Outright [Redmine:#93296]
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181017@Alan: Write log new reason chinese simplified [102918]
		- 20180821@Alan: Incorporate ESports 2.0 [99448]
		- 20181228@Alan: E-Sports Phase 2b - Support In-play status [106456]
		- 20190531@Raymond.Le: PH AIO 4 - change filter advanced mode for bettype 479, 481 [112884]
		- 20191106@Helen: SP Tuning -  [Redmine: 121209]
		- 20200727@Zane: Basketball AIO Phase 2 - Change filter advanced mode [137189]
		- 20201002@Charles: Letstalk notification for void settled bets [141828]
		- 20200925@Charles: HotFix - advance mode can not search all for 226-227 (fast market)[142312]
		- 20201126@Charles: God of fortune [Redmine: #146053]
		- 20210303@July: Enhance data type advance mode [Redmine: #150075]
		- 20210426@July: Integrate new bettype Time Machine HDP  [Redmine:#153433]
		- 20210720@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210801@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20220221@July: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220301@July: Integrate Cricket AIO Phase 2 [Redmine:#168080]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220705@Max: [TVS] Support multiple selection on Player filter of Cricket AIO [Redmine: #174652]
		- 20220804@Max: TVS HotFix Filter Player Cricket [Redmine: #176290]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185238]

	 Param's Explanation:   
		@BetTypes : 
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
						OddsId="8518"			-- Default : "All" ; Format : 8518,8519,...
						Transdesc = '100001'	-- Default : "All" ; Format : 100001,100002,... (PlayerId - [Team].[TeamID])
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
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidParlayBet_Update '
					+ CASE WHEN @MatchId IS NULL THEN '' ELSE '@MatchId = ' + CONVERT(NVARCHAR(50), @MatchId) END
					+ CASE WHEN @Type IS NULL THEN '' ELSE ',@Type = ' + CONVERT(NVARCHAR(50), @Type) END
					+ CASE WHEN @LiveHomeScore IS NULL THEN '' ELSE ',@LiveHomeScore = ' + CONVERT(NVARCHAR(50), @LiveHomeScore) END
					+ CASE WHEN @LiveAwayScore IS NULL THEN '' ELSE ',@LiveAwayScore = ' + CONVERT(NVARCHAR(50), @LiveAwayScore) END
					+ CASE WHEN @FromTransdate IS NULL THEN '' ELSE ',@FromTransdate = ''' + CONVERT(NVARCHAR(50), @FromTransdate, 21) + '''' END
					+ CASE WHEN @ToTransdate IS NULL THEN '' ELSE ',@ToTransdate = ''' + CONVERT(NVARCHAR(50), @ToTransdate, 21) + '''' END
					+ CASE WHEN @BetTypes IS NULL THEN '' ELSE ',@BetTypes = ''' + CONVERT(NVARCHAR(MAX), @BetTypes) + '''' END
					+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
					+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
					+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ''' + CONVERT(NVARCHAR(50), @UserName) + '''' END
					+ CASE WHEN @UserPassword IS NULL THEN ''ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) + '''' END
					+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
					+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
					+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END
					+ CASE WHEN @Language IS NULL THEN '' ELSE ',@Language = ' + CONVERT(NVARCHAR(50), @Language) END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH   
	
	DECLARE  @avaiableProcess	BIT = 1
			,@CustIds			VARCHAR(MAX) = ''
			,@CountSubTransId	INT = 0
			,@ValueDefault		SMALLMONEY = 9999.00
			,@Movebetdate		DATETIME
			,@matchdate			DATETIME
			,@NegativeBalanceUsers	VARCHAR(MAX)	= '' 
			,@ErrMsg				NVARCHAR(200)	= '' 
			,@ErrCode				INT				= 0  
			,@SiteDBGroupID		SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @MainParlay_MaxPO VARCHAR(MAX) = NULL
	
	DECLARE @Session			NVARCHAR(50)
		   ,@ThreadHold			INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
		   ,@totalSubParlay		INT = 0 
		   	
	SELECT @NegativeBalanceUsers = ''
	      ,@Session = CONVERT(NVARCHAR(50),NEWID())

	CREATE TABLE #tblBetType
	(
		Id				SMALLINT,		 				
		BetTeam			NVARCHAR(10), 
		[Set]			VARCHAR(10),
		Game			VARCHAR(3),
		[Value]			SMALLMONEY,
		ValueHdp1		SMALLMONEY,
		ValueHdp2		SMALLMONEY,
		Goal			BIGINT,
		OddsId			INT,
		Transdesc		NVARCHAR(2000)
	)
			
	CREATE TABLE #BetDelete (   
		  refno			BIGINT,   
		  transid		BIGINT,   
		  custid		INT,   
		  srecommend	INT,   
		  mrecommend	INT,   
		  recommend		INT,   
		  betfrom		NVARCHAR(3),   
		  bettype		SMALLINT,   
		  hdp1			SMALLMONEY,   
		  hdp2			SMALLMONEY,   
		  odds			SMALLMONEY,   
		  betteam		NVARCHAR(20),   
		  livehomescore SMALLINT,  
		  liveawayscore SMALLINT,   
		  liveindicator BIT,   
		  org_betteam	NVARCHAR(10),   
		  statusID		INT,
		  status		NVARCHAR(10),    
		  betcheck		NVARCHAR(50),  
		  transdesc		NVARCHAR(1000),  
		  creator		INT,      
		  mainbettype	SMALLINT,  
		  maintransid	BIGINT  ,
		  mainstatusID	INT,
		  main_ruben	TINYINT,
		  main_custid	INT,
		  OddsId		INT
	)  
       
	CREATE TABLE #tblTransId (transid BIGINT PRIMARY KEY)								 
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	IF NOT EXISTS (SELECT 1  FROM custDB.dbo.customer WITH (NOLOCK) WHERE userpwd = @UserPassword  AND custid = @UserId AND roleid>=5)  
	BEGIN  
		SELECT @ErrMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!', @ErrCode = 113	   
		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers
		
		RETURN  
	END  
	
	/*Modify the way to get move bet date*/
	SELECT @matchdate = eventdate FROM dbo.match WITH(NOLOCK) WHERE matchid = @MatchId

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
	IF @matchdate <= @Movebetdate
	BEGIN
		SELECT @ErrCode = 99
		     , @ErrMsg = 'Match is under Movebet process, could not void ticket.'

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers

		RETURN	
	END	
 
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
			 , t.c.value('@ValueHdp2','VARCHAR(20)') AS ValueHdp2	-- check columns : hdp2	 		 ; single-choice
			 , t.c.value('@Goal','VARCHAR(10)') AS Goal				-- check columns : betID		 ; single-choice
			 , t.c.value('@OddsId','VARCHAR(1000)') AS OddsId			-- check columns : OddsId		 ; single-choice + multi-choice
			 , t.c.value('@Transdesc','NVARCHAR(2000)') AS Transdesc	-- check columns : Transdesc	 ; single-choice + multi-choice
		FROM @BetTypes.nodes('BetTypes/BetType') t(c)
	),
	CTE_ParsedBettypes AS
	(
		SELECT cte.Id
			 , bt.value AS BetTeam 
			 , cte.[Set]
			 , cte.Game
			 , CAST(CASE
						WHEN v.value = 'ALL' THEN @ValueDefault 
						ELSE v.value
					END AS SMALLMONEY) AS [Value]
			 , CAST(CASE
						WHEN vhdp1.value = 'ALL' THEN @ValueDefault 
						ELSE vhdp1.value
					END AS SMALLMONEY) AS ValueHdp1

			 , CAST(CASE
						WHEN cte.ValueHdp2 = 'ALL' THEN @ValueDefault 
						ELSE cte.ValueHdp2
					END AS SMALLMONEY) AS ValueHdp2			 
			 , CAST(CASE 
						WHEN cte.Goal = 'ALL' THEN 100 
						ELSE cte.Goal
					END AS BIGINT) AS Goal
			 , CAST(CASE WHEN osid.value = 'ALL' THEN NULL
						ELSE osid.value END AS INT) AS OddsId
			 , CAST(CASE WHEN td.value = 'ALL' THEN NULL
						ELSE td.value END AS NVARCHAR(2000)) AS Transdesc
		FROM CTE_ParsedBettypes_1 cte
			 CROSS APPLY STRING_SPLIT(cte.betteam, ',') bt
			 CROSS APPLY STRING_SPLIT(cte.[Value], ',') v
			 CROSS APPLY STRING_SPLIT(cte.ValueHdp1, ',') vhdp1
			 CROSS APPLY STRING_SPLIT(cte.OddsId, ',') osid
			 CROSS APPLY STRING_SPLIT(cte.Transdesc, ',') td
	)	 
	INSERT INTO #tblBetType(Id, BetTeam, [Set], Game, [Value], Goal, ValueHdp1, ValueHdp2, OddsId, Transdesc)
	SELECT cte.Id
		 , CASE
				WHEN cte.Id = 30 AND cte.BetTeam = '4:0up' THEN '4:0' -- replace row [bettype 30 - betteam '4:0up'] by [bettype 30 - betteam '4:0'] 
				WHEN cte.Id = 30 AND cte.BetTeam = '0:4up' THEN '0:4' -- replace row [bettype 30 - betteam '0:4up'] by [bettype 30 - betteam '0:4']
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4&Over' THEN 'G4' -- replace row [bettype 179 - betteam 'G4&Over'] by [bettype 179 - betteam 'G4'] 
				ELSE cte.BetTeam
		   END AS BetTeam
		 , cte.[Set]
		 , cte.Game
		 , cte.[Value]
		 , cte.Goal
		 , cte.ValueHdp1
		 , cte.ValueHdp2
		 , cte.OddsId
		 , cte.Transdesc
	FROM CTE_ParsedBettypes cte	
	WHERE CASE
				WHEN cte.Id = 30 AND cte.BetTeam IN ('4:0', '0:4') THEN 0 -- exclude row [bettype = 30 - betteam in ('4:0', '0:4')]
				WHEN cte.Id = 179 AND cte.BetTeam = 'G4' THEN 0 -- exclude row [bettype = 179 - betteam = 'G4']
				ELSE 1
		  END = 1
	OPTION (OPTIMIZE FOR (@BetTypes = NULL))         	  
    
	BEGIN TRY   
		INSERT INTO #tblTransId ( transid )  
		SELECT DISTINCT CONVERT(BIGINT, value)   
		FROM STRING_SPLIT(ISNULL(@TransIds,''), ',')  
		WHERE value <> ''
		
		SET @CountSubTransId = @@ROWCOUNT
	END TRY  
	BEGIN CATCH  
		SELECT @ErrCode = 114  
		, @ErrMsg = 'Invalid TransIds.'	
		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers
		
		RETURN  
	END CATCH    

   -- Apply new way to lock parlay tickets
	INSERT INTO #tblMatchParlayProcess (MatchID, RefNo)
	SELECT @MatchID, b.refno
	FROM #tblTransId t
	  INNER JOIN dbo.bettransm b WITH(NOLOCK) ON t.transid = b.transid
	WHERE	b.matchid = @MatchID
		 AND b.statusID NOT IN (101, 102)   
   
	SET @totalSubParlay = @@ROWCOUNT
   	EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
		   ,@ThreadHold = @ThreadHold OUTPUT

   IF @totalSubParlay <= @ThreadHold
   BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
              @IsLockingByRefno   = 1
             ,@spName             = @spName
             ,@Session            = @Session
             ,@avaiableProcess    = @avaiableProcess OUTPUT
             ,@ErrCode            = @ErrCode OUTPUT
             ,@ErrMsg             = @ErrMsg OUTPUT
   END
   ELSE
   BEGIN
		---- Check for concurrent running  
		EXEC dbo.NAP_Admin_CheckingProcess  
			@isExistParlay   = 1  
		   ,@avaiableProcess = @avaiableProcess OUTPUT  
		   ,@ErrCode		 = @ErrCode OUTPUT  
		   ,@ErrMsg          = @ErrMsg OUTPUT  
	END
  
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN	
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers

		RETURN  
	END
    
	-- Apply for move match Cricket
	IF EXISTS ( SELECT TOP 1 1 
				FROM #tblTransId t
					INNER JOIN dbo.bettransm b WITH(NOLOCK) ON b.transid = t.transid
				WHERE b.matchid <> @MatchId
			)
	BEGIN
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Some tickets not found.'
		
		IF @totalSubParlay <= @ThreadHold
		BEGIN
		     EXEC dbo.NAP_Admin_CheckingProcess
                  @IsLockingByRefno = 1
                 ,@Session = @Session
                 ,@IsReleased = 1
		END
		ELSE
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
				 @isExistParlay  = 1  
				,@IsReleased     = 1	
		END

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers

		RETURN;
	END

 ------------------***** Insert all data into #BetDelete *****------------------  
	INSERT INTO #BetDelete (  refno, transid, custid, srecommend, mrecommend, recommend, betfrom, bettype, hdp1  
	  ,hdp2, odds, betteam, livehomescore, liveawayscore, liveindicator, org_betteam, statusID, status, betcheck, transdesc, creator, OddsId)  
	SELECT	b.refno  
			,b.transid  
			,c.custid  
			,c.srecommend  
			,c.mrecommend  
			,c.recommend  
			,b.betfrom  
			,b.bettype  
			,b.hdp1  
			,CASE WHEN b.bettype = 646 THEN ABS(b.hdp2) ELSE b.hdp2 END AS hdp2 --646: Match Handicap & Total
			,b.odds  
			,b.betteam    
			,b.livehomescore  
			,b.liveawayscore  
			,b.liveindicator  
			,b.betteam    
			,b.statusID
			,b.status 
			,b.betcheck  
			,b.transdesc  
			,b.creator  			
			,b.OddsId
	FROM (SELECT TOP (@CountSubTransId) * FROM #tblTransId) tmp		     
		 INNER JOIN dbo.bettransm AS b WITH(NOLOCK)        
			     ON	b.transid = tmp.transid
		 INNER JOIN custDB.dbo.customer AS c WITH(NOLOCK)   
			     ON	c.custid=b.custid		 
	WHERE	b.matchid=@MatchID   
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @Type = 1 THEN @LiveHomeScore ELSE b.livehomescore END  
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @Type = 1 THEN @LiveAwayScore ELSE b.liveawayscore END   
			AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL THEN @FromTransdate ELSE b.transdate END   
							    AND CASE WHEN @ToTransdate IS NOT NULL THEN @ToTransdate ELSE b.transdate END   
			AND b.statusID NOT IN (101, 102)
			AND b.betfrom <> 'p'
			AND b.SiteDBGroupID = @SiteDBGroupID
	OPTION (OPTIMIZE FOR (@CountSubTransId = 1))			  
   
	CREATE CLUSTERED INDEX cl_Ref_refno ON #BetDelete(refno)  
	CREATE NONCLUSTERED INDEX nl_Ref_StatusID ON #BetDelete(StatusID)  
	CREATE NONCLUSTERED INDEX nl_Ref_bettype_org_betteam ON #BetDelete(bettype,org_betteam)  
  
	-- remove unselected bettypes
	DELETE	r  
	FROM #BetDelete AS r   		  
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType s
					  WHERE r.bettype = s.Id)   
   
    /*
		filter for Betteam		

		filter for [Set] (+ [Quarter])
		[Set] : 8xx; 1324 : 8xxyy
		[Quarter] : 80X; 613 : 80XYY
		
		filter for Game : Only handle for bettype 1324
		 
		filter for [Value]
		 
		filter for Goal

		filter for ValueHdp1: for bettype 479, 481

		filter for ValueHdp2

		filter for OddsId (Cricket AIO P2)
	*/			
	BEGIN
	DELETE s
	FROM #BetDelete s		 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
					    AND CASE
								WHEN tp.BetTeam = 'ALL' THEN 1									
								ELSE CASE 
										WHEN s.org_betteam = tp.BetTeam THEN 1
										ELSE 0
									 END 
							END = 1)		
				
	DELETE s
	FROM #BetDelete s	 
	WHERE NOT EXISTS (SELECT TOP 1 1
					  FROM #tblBetType tp
					  WHERE tp.Id = s.bettype
						AND CASE
								WHEN tp.[Set] = 'ALL' THEN 1							
								ELSE CASE 						  
										WHEN s.betcheck LIKE tp.[Set] + '%' THEN 1
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
								WHEN (tp.Game LIKE '>%' AND RIGHT(s.betcheck, 2) > RIGHT(tp.Game, 2))
									 OR (RIGHT(s.betcheck, 2) = tp.Game)
										THEN 1											
								ELSE 0
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
								WHEN ISNULL(s.betcheck, 0) = tp.Goal THEN 1			
								ELSE 0
							END = 1)

	/*Apply for bettypes Cricket 2.0 [168080]*/
	DELETE s
	FROM  #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND (tp.OddsId IS NULL OR s.OddsId = tp.OddsId )) 
	
	DELETE s
	FROM  #BetDelete s
	WHERE NOT EXISTS (SELECT TOP 1 1 FROM #tblBetType tp
		WHERE tp.Id = s.Bettype AND  (tp.Transdesc IS NULL OR s.transdesc = tp.Transdesc))	 
	END				

	CREATE NONCLUSTERED INDEX nl_Ref_custid_transid ON #BetDelete(custid,transid)  
	--FOR DELETE SECTION  
   
	--check no data  
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)   
	BEGIN  
		SELECT @ErrCode = 99  
		, @ErrMsg = 'No ticket found.'  

		IF @totalSubParlay <= @ThreadHold
		BEGIN
		     EXEC dbo.NAP_Admin_CheckingProcess
                  @IsLockingByRefno = 1
                 ,@Session = @Session
                 ,@IsReleased = 1
		END
		ELSE
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess  
				 @isExistParlay  = 1  
				,@IsReleased     = 1	
		END	
		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @NegativeBalanceUsers AS NegativeBalanceUsers
	END  
	ELSE  
	BEGIN  
		UPDATE	r  
			SET mainbettype = b.bettype  
				,maintransid = b.transid
				,mainstatusID = b.statusID 
				,main_custid = b.custid
				,main_ruben = b.ruben
		FROM	#BetDelete r  
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)  
				ON	r.refno = b.refno  
					AND b.matchid = 29
					AND b.bettype = 29
					
		------------------***** BegIN Special Delete *****------------------  

		-- BackUp bettransm tickets into zzzbettrans  
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID
		)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, SYSDATETIME(), b.SiteDBGroupID
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r 
				ON	r.transid=b.transid   

		--BackUp tickets of bettransm  
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				 winlostdate, betfrom, betcheck, checktime, matchid, bettype, RepUpdateTime, SiteDBGroupID)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, SYSDATETIME(), b.SiteDBGroupID 
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r 
				ON	r.transid=b.transid   

		-- void process  
		DECLARE @rowcount		INT
				,@step			INT = 0
				,@transid_tmp	VARCHAR(2000)  

		--- void selection  
		DECLARE @transtbl TABLE (id INT IDENTITY, transid BIGINT)  
		
		INSERT INTO @transtbl (transid)  
		SELECT	transid  
		FROM	#BetDelete  
		   
		SELECT @rowcount = @@ROWCOUNT 
		 
		WHILE @step < @rowcount  
		BEGIN  
			SET @transid_tmp = ''  

			SELECT	@transid_tmp  = @transid_tmp + CONVERT(VARCHAR(20),transid)  + ','   
			FROM	@transtbl  
			WHERE	id > @step 
					AND id <= @step + 100  
			 
			SET @step = @step + 100  

			EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId  
			,@fth = 0  
			,@fta = 0  
			,@hth = 0  
			,@hta = 0  
			,@matchdate = @matchdate  
			,@mode = 'VOID'  
			,@VoidTransID = @transid_tmp  
			,@UserId = @UserId  
			 
		END  

		IF EXISTS ( SELECT TOP 1 1  
					FROM #BetDelete r 
						INNER HASH JOIN bettrans b WITH(NOLOCK)   
							ON	b.refno = r.refno  
					WHERE	b.matchid = 29 
							AND b.bettype = 29  
		)   
		BEGIN  

			BEGIN TRY  
				DECLARE @transids_29 VARCHAR(MAX) = ''  
				  ,@refnos_29  VARCHAR(MAX) = ''  
				   
				SELECT	@transids_29 = @transids_29 + CONVERT(VARCHAR(20), maintransid) + ','  
				FROM	#BetDelete  
				WHERE	mainbettype = 29  
				GROUP BY maintransid  
				  
				EXEC dbo.NAP_Admin_Calculate_MP_broker   
					@matchid = @matchid  
					,@matchdate = @matchdate  
					,@strXML = @transids_29  
					,@mode  = 'PRECAL-29'  		   
			END TRY  
			BEGIN CATCH   
				SELECT @ErrCode = 100  
				 , @ErrMsg = ERROR_MESSAGE()  
			END CATCH  

		---********* Calculate balance at bettrans table********---  
			CREATE TABLE #BeforeUpd (  
			  custid   INT,  
			  balance   MONEY)  
			    
			CREATE TABLE #AfterUpd(  
			   custid   INT,  
			   balance   MONEY)  
		     
			DECLARE @tblDebitPending TVP_BalanceList  
			DECLARE @tblCreditPending TVP_BalanceList  
		      
			--Get data before update  
			INSERT INTO #BeforeUpd (custid, balance)  
			SELECT	b.custid, SUM (b.wINlost - b.actual_stake + b.playercomm) balance  
			FROM #BetDelete r 	  
				INNER HASH JOIN bettrans b WITH (NOLOCK)
					ON	b.refno = r.refno  
			WHERE	b.matchid = 29 
					AND b.bettype = 29  
			GROUP BY b.CustID    

			--Prepare for Max Payout
			SELECT @MainParlay_MaxPO = (SELECT t.main_custId AS '@custid'
										,t.main_ruben AS '@ruben'
										,t.maintransid AS '@transid'
									FROM #BetDelete t
									GROUP BY main_custId, main_ruben, maintransid
									FOR XML PATH('r'), ROOT('root')
							)
		--Settlement System parlay (changed balance)  @strRefnos + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
			BEGIN TRY  
				SELECT  @refnos_29 = @refnos_29 + ',' +  CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), maintransid)  
				FROM	#BetDelete  
				WHERE	mainbettype = 29 
				  AND   (mainstatusID IS NULL OR mainstatusID <> 102)
				GROUP BY refno, maintransid   

				SET @refnos_29 = STUFF(@refnos_29,1,1,'')
				  
				EXEC dbo.NAP_Admin_Calculate_MP_broker   
					@matchdate = @matchdate  
					,@strXML = @refnos_29  
					,@mode  = '29'  
			END TRY  
			BEGIN CATCH   
				SELECT @ErrCode = 101  
				 , @ErrMsg = ERROR_MESSAGE()  

				 SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					, @NegativeBalanceUsers AS NegativeBalanceUsers
			END CATCH  
		 
			--Insert Max Payout Queue
			EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
				@MatchId= 29
				,@TransidList = @MainParlay_MaxPO
			
			--Get data after update  
			INSERT INTO #AfterUpd (custid, balance)  
			SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance  
			FROM #BetDelete r 	 
				INNER HASH JOIN bettrans b WITH (NOLOCK)
					ON	b.refno = r.refno  
			WHERE	b.matchid = 29 
					AND b.bettype = 29  
			GROUP BY b.CustID  
		 
			INSERT INTO @tblCreditPending (custID, balance)  
			SELECT	a.custid  
					,(a.balance - b.balance) AS Balance  
			FROM	#BeforeUpd b  
				INNER JOIN #AfterUpd a 
					ON	a.custid = b.custid  
			WHERE	(a.balance - b.balance) > 0  
		 
			IF @@rowcount <> 0  
				EXEC dbo.Dot_BalancePendingCreditIns   
				 @BalancePending = @tblCreditPending  
				 ,@Type   = 1 -- Sports  

			INSERT INTO @tblDebitPending (custID, balance)  
			SELECT	a.custid  
					,ABS(a.balance - b.balance) AS Balance  
			FROM	#BeforeUpd b  
				INNER JOIN #AfterUpd a 
					ON	a.custid = b.custid  
			WHERE	(a.balance - b.balance) < 0  
		 
			IF @@rowcount <> 0  
				EXEC dbo.Dot_BalancePendingDebitIns   
				 @BalancePending = @tblDebitPending  
				 ,@Type   = 1 -- Sports  

			SELECT @CustIds = @CustIds +
							  CASE WHEN @CustIds <> '' THEN ',' ELSE '' END + 
							  CONVERT(VARCHAR(20), b.custid)
			FROM #BeforeUpd b
				 INNER JOIN	#AfterUpd a ON a.custid = b.custid 
			WHERE b.balance > a.balance

			EXEC [dbo].[NAP_CustNegativeBalance_Sel] 	
				@CustIds = @CustIds,
				@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

			IF @NegativeBalanceUsers <> ''
			BEGIN
				SET @NegativeBalanceUsers = REPLACE(@NegativeBalanceUsers, ',', ', ')
			END

			DROP TABLE #BeforeUpd  
			DROP TABLE #AfterUpd  
		---********* End of calculate balance at bettrans table********---  
		END  

		IF @totalSubParlay <= @ThreadHold
		BEGIN
			------ releasing refno process  
		     EXEC dbo.NAP_Admin_CheckingProcess
                  @IsLockingByRefno = 1
                 ,@Session = @Session
                 ,@IsReleased = 1
		END
		ELSE
		BEGIN
			------ releasing SD process  
			EXEC dbo.NAP_Admin_CheckingProcess  
				 @isExistParlay  = 1  
				,@IsReleased     = 1	
		END

		SELECT @ErrCode AS ErrorCode
					, @ErrMsg AS ErrorMsg
					, @NegativeBalanceUsers AS NegativeBalanceUsers

		-- Return Match Info
		BEGIN  
			SELECT m.homeid,  
					m.awayid,  
					m.matchcode,  
					m.eventdate,  
					m.leagueid,  
					m.sporttype,
					ISNULL(m.isNeutral, CONVERT(BIT,0)) AS IsNeutral,
					l.LeagueGroupID
			FROM	dbo.match AS m WITH (NOLOCK)  
					INNER JOIN dbo.league AS l WITH(NOLOCK) ON m.leagueid = l.leagueid
			WHERE	m.matchid = @matchID  
		END
		
		-- Output new message structure  
		DECLARE @isITAdmin BIT   

		-- CHECK IT GROUP or NOT ?   
		SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)  
		
		;WITH CTE_CustIdAll 
		AS (  
			SELECT DISTINCT t.custid  
			FROM #BetDelete b  
			CROSS APPLY (  
					VALUES (custid)  
					,(creator)  
					,(recommend)  
					,(mrecommend)  
					,(srecommend)  
				) AS t (custid)  
		)
		,CTE_CustInfo AS (  
		SELECT	ci.custid  
				, ci.username  
				, ci.username2  
				, ci.site  
		FROM	CustDB.dbo.Customer ci WITH(NOLOCK)  
			INNER JOIN CTE_CustIdAll ca 
				ON	ci.custid = ca.custid  
		)  
		SELECT	b.transid
				,b.custid
				,b.transdate
				,b.stake
				,b.odds
				,b.OddsType
				,b.status
				,b.currency
				,b.CurrencyName
				,b.betteam
				,b.betcheck
				,b.modds AS MasterOdds
				,b.bettype AS BetTypeId
				,b.hdp1 AS Handicap1
				,b.hdp2 AS Handicap2
				,b.winlost-b.actual_stake AS winlost
				,r.refno
				,r.betfrom
				,r.transdesc AS SubTransDesc
				,r.livehomescore
				,r.liveawayscore
				,r.liveindicator AS IsLive
				,r.bettype AS SubBettype
				,r.hdp1 AS SubHdp1
				,r.hdp2 AS SubHdp2
				,r.odds AS SubOdds
				,r.betteam AS SubBetteam
				,r.betcheck AS SubBetCheck
				,1 AS IsMixParlay
				,r.status AS SubStatus
				,b.ExtraInfo
				,b.actual_stake AS ActualStake
				,r.OddsId AS SubOddsId
				,@MatchID AS MatchId
				,b.recommend
				,b.mrecommend
				,b.srecommend
				,ci.Username
				,ci.username2
				,ag.UserName AS AgUserName
				,ma.UserName AS MagUserName
				,su.Username AS SagUserName
				,CASE   
				WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair'   
				ELSE su.site   
				END AS EmailGroup  
				,su.site   
				,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit  
				,@isITAdmin AS IsITSupport 
				,CURRENT_TIMESTAMP AS [DateTime] 
				,b.SiteDBGroupID
		FROM #BetDelete AS r WITH(NOLOCK)   	 
			INNER HASH JOIN dbo.bettrans AS b WITH (NOLOCK) 
				ON	b.custid = r.custid AND b.refno = r.refno  
			INNER JOIN CTE_CustInfo ci WITH(NOLOCK)  
				ON	b.custid = ci.custid   
			INNER JOIN CTE_CustInfo ag WITH(NOLOCK)  
				ON	b.recommend = ag.custid  
			INNER JOIN CTE_CustInfo ma WITH(NOLOCK)  
				ON	b.mrecommend = ma.custid  
			INNER JOIN CTE_CustInfo su WITH(NOLOCK)  
				ON	b.srecommend = su.custid  
			LEFT JOIN custdb.dbo.Dep_CustSuper s with(nolock)
				ON	b.srecommend = s.custid   
		WHERE	b.matchid = 29   
				AND b.bettype = 29  
		ORDER BY b.transid   
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

	DROP TABLE #tblTransId  
	DROP TABLE #BetDelete    
	DROP TABLE #tblBettype
	DROP TABLE #tblMatchParlayProcess
	   
	SET NOCOUNT OFF  
END
