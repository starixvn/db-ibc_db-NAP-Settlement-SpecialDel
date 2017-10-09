/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlayBet_Update]  
	@MatchID			INT,  
	@Type				SMALLINT   = 0,    
	@LiveHomeScore		SMALLINT   = NULL,  
	@LiveAwayScore		SMALLINT   = NULL,  
	       
	@Handicap			SMALLMONEY  = 9999,  -- 1, 3, 7, 8, 17, 153, 183, 1303, 1306, 1308, 21, 603, 604, 605, 606, 607: Handicap, Odd/Even, Over/Under...     
	@Handicap155		SMALLMONEY  = 9999,  -- 155, 1316  
	@Handicap178		SMALLMONEY		= 9999,		-- 178,197,198,204,205, 401, 402, 403, 404, 18, 461, 462, 463, 464
	@Handicap609		SMALLMONEY	= 9999, -- 609,612,613,617
	@OverUnder156		SMALLMONEY  = 9999,  -- 156, 1312 
	@OverUnder610		SMALLMONEY	= 9999, -- 610,615,616 
	  
	@FromTransdate		DATETIME   = NULL,  
	@ToTransdate		DATETIME   = NULL,  
	  
	    
	@BetTypes			VARCHAR(1000) = '',   
	@BetTeam1378		VARCHAR(10) 	= 'ALL',	-- 1, 2, 3, 7, 8, 12, 17, 20, 153,157,168,183,185,191, 1301, 1303, 1305, 1306, 1308, 411, 501,432, 425, 21, 603, 604, 605, 606, 607, 25, 460: Handicap, Odd/Even, Over/Under...   
	@BetTeam515			VARCHAR(10) 	= 'ALL',	-- 5,15,160,164,167,176,177,180,430, 458, 459, 22
	@BetTeam430			VARCHAR(120)  = '',  -- 4, 30, 405: All Correct Scores  
	@BetTeam6			VARCHAR(120)  = '',  -- 6, 126, 131, 132  
	@BetTeam14    		VARCHAR(120)  = '',  
	@BetTeam16    		VARCHAR(120)  = '',  
	@BetTeam128    		VARCHAR(120)  = '',  
	@BetTeam129    		VARCHAR(120)  = '',  -- 129, 130  
	@BetTeam136			VARCHAR(10)		= 'ALL',	-- 136, 137, 138, 139, 184,194,203,428
	@BetTeam143    		VARCHAR(120) = '',  -- 143, 144, 163   
	@BetTeam154    		VARCHAR(3)  = 'ALL',  -- 154, 155, 1311, 1316   
	@BetTeam156    		VARCHAR(3)  = 'ALL',  -- 156, 1312   
	@BetTeam1302   		VARCHAR(120) = 'ALL',  -- 1302   
	@BetTeam1317   		VARCHAR(120) = 'ALL',  -- 1317   
	@BetTeam1318   		VARCHAR(3)  = 'ALL',  -- 1318    
	@BetTeam1324   		VARCHAR(3)  = 'ALL',  -- 1324  
	@BetTeam178			VARCHAR(10)		= 'ALL',	-- 178,197,198,204,205, 401, 402, 403, 404, 18, 461, 462, 463, 464: 2H Over/Under...
	@BetTeam165    		VARCHAR(120) = 'ALL', -- 165,166  
	@BetTeam159    		VARCHAR(120) = 'ALL', -- 159,179,406: All Exact Total Goals  
	@BetTeam161    		VARCHAR(120) = 'ALL', -- 161,162,181,182, 407, 409, 412,429: All Exact Team Goals  
	@BetTeam199    		VARCHAR(120) = 'ALL', -- 199  
	@BetTeam202    		VARCHAR(120) = 'ALL', -- 202  
	@BetTeam195    		VARCHAR(120) = 'ALL', -- 195,196  
	@BetTeam200    		VARCHAR(120) = 'ALL', -- 200,201  
	@BetTeam169    		VARCHAR(120) = 'ALL', -- 169,193  
	@BetTeam210    		VARCHAR(10)  = 'ALL', -- 210,173,174,188,189,190,211,212,213,214,215,133,134,135,145,146,147,148,149,150  
	@BetTeam216    		VARCHAR(240) = 'ALL', -- 216  
	@BetTeam408    		VARCHAR(120) = 'ALL', -- 171, 408, 426: Winning Margin   
	@BetTeam24			VARCHAR(120)	= 'ALL',	-- 24, 151, 186, 410,431: All Double Chance
	@BetTeam609			VARCHAR(10) 	= 'ALL', -- 609,612,613,617
	@BetTeam611			VARCHAR(10) 	= 'ALL', -- 611
	@BetTeam610			VARCHAR(10) 	= 'ALL', -- 610,615,616
	@BetTeam614			VARCHAR(MAX) 	= 'ALL', -- 614
	@BetTeam602			VARCHAR(MAX) 	= 'ALL', -- 602,608
	@BetTeam601			VARCHAR(MAX) 	= 'ALL', -- 601
	@BetTeam140			VARCHAR(MAX) 	= 'ALL', -- 140, 452, 442
	@BetTeam448			VARCHAR(MAX) 	= 'ALL', -- 448
	@BetTeam449			VARCHAR(MAX) 	= 'ALL', -- 449
	@BetTeam450			VARCHAR(MAX) 	= 'ALL', -- 450
	@BetTeam451			VARCHAR(MAX) 	= 'ALL', -- 451
	@BetTeam416			VARCHAR(MAX) 	= 'ALL', -- 416
	   	
	@Quarter609			VARCHAR(10)		= 'ALL', -- 609,612,613,617				
	@Quarter611			VARCHAR(10)		= 'ALL', -- 611			
	@Quarter610			VARCHAR(10)		= 'ALL', -- 610,615,616				
	@Quarter614			VARCHAR(10)		= 'ALL', -- 614			
	
	@Set154     		VARCHAR(3)  = 'ALL',  -- 154, 155, 1311, 1316   
	@Set156     		VARCHAR(3)  = 'ALL', -- 156, 1312   
	@Set1317    		VARCHAR(3)  = 'ALL',  -- 1317  
	@Set1318    		VARCHAR(3)  = 'ALL',  -- 1318   
	@Set1324    		VARCHAR(3)  = 'ALL',  -- 1324   
	  
	@Game1324			VARCHAR(3)  = 'ALL',  -- 1324   
	  
	@BetID160			TINYINT   = 100,  --160,164,180, 22  
	  
	@TransIds			VARCHAR(MAX) ='',  
	  
	@UserId				INT,  
	@UserName			NVARCHAR(50),  
	@UserPassword		NVARCHAR(50),  
	@Ip					VARCHAR(15)  = '',  
	@Reason				NVARCHAR(500) ='',  
	@Language			NVARCHAR(2)  = 'E',  
	@NegativeBalanceUsers	VARCHAR(MAX)	= ''	OUTPUT,

	@ErrMsg				NVARCHAR(200) = '' OUTPUT,  
	@ErrCode			INT    = 0  OUTPUT       
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

	 Param's Explanation:   
   
*/  
BEGIN   
	SET NOCOUNT ON  
   
	DECLARE @LogData			NVARCHAR(500)  
			,@avaiableProcess	BIT = 1
			,@CustIds			VARCHAR(MAX) = ''

	SET @NegativeBalanceUsers = ''
			
	CREATE TABLE #BetDelete (   
		  refno			BIGINT,   
		  transid		BIGINT,   
		  custid		INT,   
		  srecommend	INT,   
		  mrecommend	INT,   
		  recommend		INT,   
		  betfrom		NVARCHAR(1),   
		  bettype		SMALLINT,   
		  hdp1			SMALLMONEY,   
		  hdp2			SMALLMONEY,   
		  odds			MONEY,   
		  betteam		NVARCHAR(20),   
		  livehomescore SMALLINT,  
		  liveawayscore SMALLINT,   
		  liveindicator BIT,   
		  org_betteam	NVARCHAR(10),   
		  statusID		INT,    
		  betcheck		NVARCHAR(50),  
		  transdesc		NVARCHAR(200),  
		  creator		INT,      
		  mainbettype	SMALLINT,  
		  maintransid	BIGINT  ,
		  mainstatusID	INT
	)  
       
	CREATE TABLE #tblTransId (transid BIGINT PRIMARY KEY)								 
    
	SELECT @ErrCode = 0  
   
	IF NOT EXISTS (SELECT 1  FROM custDB.dbo.customer WITH (NOLOCK) WHERE userpwd = @UserPassword  AND custid = @UserId AND roleid>=5)  
	BEGIN  
		SELECT @LogData ='fail to void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' for Mix Parlay Special Delete reason: ' + @Reason  
	    
		EXEC WriteLog_UserLog   
			@UserId = @UserId  
			,@Doing = @LogData  
	  
		SELECT @ErrMsg = 'Sorry. You cannot process void bets due to either wrong password or insufficient permission!', @ErrCode = 101	    		
		
		RETURN  
	END  
  
 -----------            	  
    
	BEGIN TRY   
		INSERT INTO #tblTransId ( transid )  
		SELECT DISTINCT CONVERT(BIGINT, val)   
		FROM dbo.strSplit(ISNULL(@TransIds,''), ',')  

	END TRY  
	BEGIN CATCH  
		SELECT @ErrCode = 102  
		, @ErrMsg = 'Invalid TransIds.'		 		
		
		RETURN  
	END CATCH    
  
 ---- Check for concurrent running  
	EXEC dbo.NAP_Admin_CheckingProcess  
		@isExistParlay   = 1  
		, @avaiableProcess  = @avaiableProcess OUTPUT  
		, @ErrCode   = @ErrCode OUTPUT  
		, @ErrMsg   = @ErrMsg OUTPUT  
  
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN	
		RETURN  
	END
    
 ------------------***** Insert all data into #BetDelete *****------------------  
	INSERT INTO #BetDelete (  refno, transid, custid, srecommend, mrecommend, recommend, betfrom, bettype, hdp1  
	  ,hdp2, odds, betteam, livehomescore, liveawayscore, liveindicator, org_betteam, statusID, betcheck, transdesc, creator)  
	SELECT	b.refno  
			,b.transid  
			,c.custid  
			,c.srecommend  
			,c.mrecommend  
			,c.recommend  
			,b.betfrom  
			,b.bettype  
			,b.hdp1  
			,b.hdp2  
			,b.odds  
			,b.betteam    
			,b.livehomescore  
			,b.liveawayscore  
			,b.liveindicator  
			,b.betteam    
			,b.statusID  
			,b.betcheck  
			,b.transdesc  
			,b.creator  			
	FROM	dbo.bettransm AS b WITH(NOLOCK)     
		INNER JOIN custDB.dbo.customer AS c WITH(NOLOCK)   
			ON	c.custid=b.custid    
		INNER JOIN #tblTransId tmp   
			ON	b.transid = tmp.transid		 
	WHERE	b.matchid=@MatchID   
			AND b.livehomescore = CASE WHEN @LiveHomeScore IS NOT NULL AND @Type = 1 THEN @LiveHomeScore ELSE b.livehomescore END  
			AND b.liveawayscore = CASE WHEN @LiveAwayScore IS NOT NULL AND @Type = 1 THEN @LiveAwayScore ELSE b.liveawayscore END   
			AND b.transdate BETWEEN CASE WHEN @FromTransdate IS NOT NULL THEN @FromTransdate ELSE b.transdate END   
							    AND CASE WHEN @ToTransdate IS NOT NULL THEN @ToTransdate ELSE b.transdate END   
			AND b.statusID NOT IN (101, 102)
			AND b.betfrom <> 'p'  
   
	CREATE CLUSTERED INDEX cl_Ref_refno ON #BetDelete(refno)  
	CREATE NONCLUSTERED INDEX nl_Ref_StatusID ON #BetDelete(StatusID)  
	CREATE NONCLUSTERED INDEX nl_Ref_bettype_org_betteam ON #BetDelete(bettype,org_betteam)  
  
	DELETE	r  
	FROM	#BetDelete AS r   
		LEFT JOIN dbo.strSplit(@BetTypes,'^') AS bt 
			ON	bt.val=r.bettype  
	WHERE	bt.val IS NULL -- remove unselected bettypes  
   
	IF @BetTeam1378 <> 'All'  
		DELETE	r  
		FROM	#BetDelete AS r   
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype  
		WHERE	r.bettype IN (1, 2, 3, 7, 8, 12, 17, 20, 153,157,168,183,185,191, 1301, 1303, 1305, 1306, 1308,411,501,432, 425
							, 21, 603, 604, 605, 606, 607
							, 25, 460) 
				AND (r.org_betteam<>@betteam1378)

	IF @BetTeam515 <> 'All'  
		DELETE	r  
		FROM	#BetDelete AS r   
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype  
		WHERE	r.bettype in (5,15,160,164,167,176,177,180,430, 458, 459, 22) 
				AND (r.org_betteam<>@betteam515)

	IF @BetTeam140<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (140, 452, 442) AND (r.org_betteam<>@BetTeam140)
	
	IF @BetTeam448<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (448) AND (r.org_betteam<>@BetTeam448)
	
	IF @BetTeam449<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (449) AND (r.org_betteam<>@BetTeam449)
	
	IF @BetTeam450<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (450) AND (r.org_betteam<>@BetTeam450)
	
	IF @BetTeam451<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (451) AND (r.org_betteam<>@BetTeam451)
	
	IF @BetTeam416<>'All'  
		DELETE r  
		FROM #BetDelete AS r   
		INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt ON bt.val=r.bettype  
		WHERE r.bettype in (416) AND (r.org_betteam<>@BetTeam416)
	
	IF @Handicap <> 9999  
		DELETE	r  
		FROM	#BetDelete AS r   
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype  
		WHERE	r.bettype IN (1,3,7,8, 17, 153, 183, 1303, 1306, 1308
							, 21, 603, 604, 605, 606, 607) 
				AND (hdp1<>@Handicap-hdp2)   
    
	IF @Handicap178 <> 9999    
		DELETE	r    
		FROM	#BetDelete AS r     
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype    
		WHERE	r.bettype IN (178,197,198,204,205, 401, 402, 403, 404, 18, 461, 462, 463, 464) 
				AND (hdp1<>@Handicap178-hdp2)
     
    
	IF @BetTeam430 = ''   
		DELETE	#BetDelete  
		WHERE	bettype IN (4,30,405,413,414)   
	ELSE IF @BetTeam430<> 'All'  
	BEGIN  
		DELETE	r    
		FROM	#BetDelete AS r    
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype   
			LEFT JOIN dbo.strSplit(@BetTeam430,'^') AS b4   
				ON  r.org_betteam = CASE 
										WHEN r.Bettype = 30 AND r.betteam = '4:0' AND b4.val = '4:0up' THEN '4:0'   
										WHEN r.Bettype = 30 AND r.betteam = '0:4' AND b4.val = '0:4up' THEN '0:4'  
										WHEN r.Bettype = 30 AND r.betteam IN ('0:4', '4:0') AND b4.val NOT IN ('4:0up','0:4up') THEN NULL  
										ELSE b4.val  
									END        
		WHERE	(r.bettype IN (4,30,405,413,414) AND (b4.val IS NULL))  
	END     
   
	IF @BetTeam6 = ''  
		DELETE	#BetDelete  
		WHERE	bettype in (6, 126, 131, 132)  
	ELSE IF @BetTeam6<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype   
			LEFT JOIN dbo.strSplit(@BetTeam6,'^') AS b6 
				ON	b6.val=r.org_betteam    
		WHERE	r.bettype in (6, 126, 131, 132) AND (b6.val IS NULL)  
   
	IF @BetTeam14 = ''  
		DELETE	#BetDelete  
		WHERE	bettype in (14, 127)  
	ELSE IF @BetTeam14<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype   
			LEFT JOIN dbo.strSplit(@BetTeam14,'^') AS b14 
				ON	b14.val=r.org_betteam    
		WHERE	r.bettype in (14, 127) 
				AND (b14.val IS NULL)  

	IF @BetTeam16 = ''  
		DELETE	#BetDelete  
		WHERE	bettype=16  
	ELSE IF @BetTeam16<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam16,'^') AS b16 
				ON	b16.val=r.org_betteam    
		WHERE	r.bettype=16 
				AND (b16.val IS NULL)  

	IF @BetTeam128 = ''  
		DELETE	#BetDelete  
		WHERE	bettype=128  
	ELSE IF @BetTeam128<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam128,'^') AS b128 
				ON	b128.val=r.org_betteam    
		WHERE	r.bettype=128 
				AND (b128.val IS NULL)  

	IF @BetTeam129 = ''  
		DELETE	#BetDelete  
		WHERE	bettype in (129, 130)  
	ELSE IF @BetTeam129<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam129,'^') AS b129 
				ON	b129.val=r.org_betteam    
		WHERE	r.bettype in (129, 130) 
				AND (b129.val IS NULL)  

	IF @BetTeam136 = ''  
		DELETE	#BetDelete  
		WHERE	bettype in (136, 137, 138, 139, 184,194,203,428)
	ELSE IF @BetTeam136<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam136,'^') AS b136 
				ON	b136.val=r.org_betteam    
		WHERE	r.bettype in (136, 137, 138, 139, 184,194,203,428) 
				AND (b136.val IS NULL)

	IF @BetTeam143 = ''  
		DELETE	#BetDelete  
		WHERE	bettype in (143, 144, 163 )  
	ELSE IF @BetTeam143<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam143,'^') AS b143 
				ON	b143.val=r.org_betteam    
		WHERE	r.bettype in (143, 144, 163 ) 
				AND (b143.val IS NULL)  

	IF @BetTeam178=''    
		DELETE	#BetDelete    
		WHERE	bettype in (178,197,198,204,205, 401, 402, 403, 404, 18, 461, 462, 463, 464)
	ELSE IF @BetTeam178<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam178,'^') AS b178 
				ON	b178.val=r.org_betteam      
		WHERE	r.bettype in (178,197,198,204,205, 401, 402, 403, 404, 18, 461, 462, 463, 464) 
				AND (b178.val IS NULL)	

	IF @BetTeam165=''    
		DELETE	#BetDelete    
		WHERE	bettype in (165,166)  
	ELSE IF @BetTeam165<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam165,'^') AS b165 
				ON	b165.val=r.org_betteam      
		WHERE	r.bettype in (165,166) 
				AND (b165.val IS NULL)   

	IF @BetTeam159=''    
		DELETE	#BetDelete    
		WHERE	bettype in (159,179,406)  
	ELSE IF @BetTeam159<>'All'     
	BEGIN  
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam159,'^') AS b159 
				ON	b159.val=r.org_betteam      
		WHERE	r.bettype in (159,406) 
				AND (b159.val IS NULL)   

		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam159,'^') AS b159 
				ON	b159.val=r.org_betteam      
		WHERE	r.bettype in (179) AND   
				(  
				(r.org_betteam <> 'G4' AND b159.val IS NULL)   
				OR  
				(  
				(r.org_betteam = 'G4')  
				AND  
				'G4&Over' NOT IN (SELECT CONVERT(VARCHAR, val) FROM dbo.strSplit(@BetTeam159, '^'))  
				)  
				)  
	END   

	IF @BetTeam161=''    
		DELETE	#BetDelete    
		WHERE	bettype in (161,162,181,182,407, 409, 412, 429)  
	ELSE IF @BetTeam161<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam161,'^') AS b161 
				ON	b161.val=r.org_betteam      
		WHERE	r.bettype in (161,162,181,182,407, 409, 412, 429) 
				AND (b161.val IS NULL)    

	IF @BetTeam199=''    
		DELETE	#BetDelete    
		WHERE	bettype in (199)  
	ELSE IF @BetTeam199<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam199,'^') AS b199 
				ON	b199.val=r.org_betteam      
		WHERE	r.bettype in (199) 
				AND (b199.val IS NULL)    


	IF @BetTeam202=''    
		DELETE	#BetDelete    
		WHERE	bettype in (202)  
	ELSE IF @BetTeam202<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam202,'^') AS b202 
				ON	b202.val=r.org_betteam      
		WHERE	r.bettype in (202) 
				AND (b202.val IS NULL)   


	IF @BetTeam195=''    
		DELETE	#BetDelete    
		WHERE	bettype in (195,196)  
	ELSE IF @BetTeam195<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam195,'^') AS b195 
				ON	b195.val=r.org_betteam      
		WHERE	r.bettype in (195,196) 
				AND (b195.val IS NULL)  


	IF @BetTeam200=''    
		DELETE	#BetDelete    
		WHERE	bettype in (200,201)  
	ELSE IF @BetTeam200<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam200,'^') AS b200 
				ON	b200.val=r.org_betteam      
		WHERE	r.bettype in (200,201) 
				AND (b200.val IS NULL)    


	IF @BetTeam169=''    
		DELETE	#BetDelete    
		WHERE	bettype in (169,193)  
	ELSE IF @BetTeam169<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam169,'^') AS b169 
				ON	b169.val=r.org_betteam      
		WHERE	r.bettype in (169,193) 
				AND (b169.val IS NULL)   

	IF @BetTeam210<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam210,'^') AS b210 
				ON	b210.val=r.org_betteam      
		WHERE	r.bettype in (210,173,174,188,189,190,211,212,213,214,215,133,134,135,145,146,147,148,149,150,427, 433, 434, 435, 436, 437, 438, 439, 440, 441) 
				AND (b210.val IS NULL)   

	IF @BetTeam216<>'All'     
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam216,'^') AS b216 
				ON	b216.val=r.org_betteam      
		WHERE	r.bettype in (216)   
				AND (b216.val IS NULL)  

	IF @BetTeam154<>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam154,'^') AS b154 
				ON	b154.val=r.org_betteam    
		WHERE	r.bettype in (154, 155, 1311, 1316)   
				AND b154.val IS NULL  

	IF @Set154 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype IN (154, 155, 1311, 1316)  
				AND r.betcheck <> @Set154  

	IF @Handicap155 <> 9999  
		DELETE	r  
		FROM	#BetDelete AS r   
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype  
		WHERE	r.bettype IN (155, 1316) 
				AND (hdp1<>@Handicap155-hdp2)   

	IF @BetTeam156 <>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam156,'^') AS b156 
				ON	b156.val=r.org_betteam    
		WHERE	r.bettype in (156, 1312)   
				AND b156.val IS NULL  

	IF @Set156 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype IN (156, 1312)  
				AND r.betcheck <> @Set156  

	IF @OverUnder156 <> 9999  
		DELETE	r  
		FROM	#BetDelete AS r   
			INNER JOIN dbo.strSplit(@BetTypes,'^') AS bt 
				ON	bt.val=r.bettype  
		WHERE	r.bettype IN (156, 1312) 
				AND (hdp1<>@OverUnder156)   

	IF @BetTeam1302 = ''  
		DELETE	#BetDelete  
		WHERE	bettype = 1302  
	ELSE IF @BetTeam1302 <>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam1302,'^') AS b1302 
				ON	b1302.val=r.org_betteam    
		WHERE	r.bettype = 1302 AND (b1302.val IS NULL)  

	IF @BetTeam1317 = ''  
		DELETE	#BetDelete  
		WHERE	bettype = 1317  
	ELSE IF @BetTeam1317 <>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam1317,'^') AS b1317 
				ON	b1317.val=r.org_betteam    
		WHERE	r.bettype = 1317  
				AND b1317.val IS NULL  


	IF @BetID160 <> 100  
	BEGIN  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 160  
				AND r.betcheck <> CAST((816000 + @BetID160) AS NVARCHAR(50))   

		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 164  
				AND r.betcheck <> CAST((816400 + @BetID160) AS NVARCHAR(50))  

		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 180  
				AND r.betcheck <> CAST((818000 + @BetID160) AS NVARCHAR(50)) 
				
		DELETE r
		FROM #BetDelete AS r
		WHERE r.bettype = 22
		AND r.betcheck <> CAST((816000 + @BetID160) AS NVARCHAR(50))				 
	END  

	IF @Set1317 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 1317  
				AND r.betcheck <> @Set1317  

	IF @BetTeam1318 <>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam1318,'^') AS b1318 
				ON	b1318.val=r.org_betteam    
		WHERE	r.bettype = 1318  
				AND b1318.val IS NULL  

	IF @Set1318 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 1318  
				AND r.betcheck <> @Set1318  

	IF @BetTeam1324 <>'All'   
		DELETE	r  
		FROM	#BetDelete AS r    
			LEFT JOIN dbo.strSplit(@BetTeam1324,'^') AS b1324 
				ON	b1324.val=r.org_betteam    
		WHERE	r.bettype = 1324  
				AND b1324.val IS NULL  

	IF @Set1324 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 1324  
				AND @Set1324 <> LEFT(r.betcheck, 3)  

	IF @Game1324 <> 'ALL'  
		DELETE	r  
		FROM	#BetDelete AS r  
		WHERE	r.bettype = 1324  
				AND(  
				(@Game1324 <> '13' AND @Game1324 <> RIGHT(r.betcheck, 2))  
				OR   
				(@Game1324 = '13' AND CAST(RIGHT(r.betcheck, 2) AS INT) < CAST(@Game1324 AS INT))   
				)  

	IF @Betteam408 <>'All'    
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@Betteam408,'^') AS b408 
				ON	b408.val=r.org_betteam      
		WHERE	r.bettype IN (171, 408, 426)   
				AND b408.val IS NULL  

	IF @BetTeam24 <> 'ALL'  
		DELETE	r    
		FROM	#BetDelete AS r      
			LEFT JOIN dbo.strSplit(@BetTeam24,'^') AS b24 
				ON	b24.val=r.org_betteam      
		WHERE	r.bettype IN (24, 151, 186, 410,431) 
				AND b24.val IS NULL  
					
	IF @Quarter609 <> 'ALL' -- 80X, 80XYY
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (609, 612, 613, 617)
		AND (r.betcheck IS NULL OR r.betcheck NOT LIKE '80' + @Quarter609 + '%')
	
	IF @BetTeam609 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam609,'^') AS b609 ON b609.val=r.org_betteam
		WHERE r.Bettype IN (609, 612, 613, 617)
		AND b609.val IS NULL
	
	IF @Handicap609 <> 9999
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (609, 612, 613, 617)
		AND (r.hdp1 IS NULL OR r.hdp2 IS NULL OR r.hdp1 <> @Handicap609-r.hdp2)
		
	IF @Quarter611 <> 'ALL' -- 80X
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (611)
		AND (r.betcheck IS NULL OR r.betcheck <> '80' + @Quarter611)
	
	IF @BetTeam611 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam611,'^') AS b611 ON b611.val=r.org_betteam
		WHERE r.Bettype IN (611)
		AND b611.val IS NULL
		
	IF @Quarter610 <> 'ALL' -- 80X
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (610, 615, 616)
		AND (r.betcheck IS NULL OR r.betcheck <> '80' + @Quarter610)
	
	IF @BetTeam610 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam610,'^') AS b610 ON b610.val=r.org_betteam
		WHERE r.Bettype IN (610, 615, 616)
		AND b610.val IS NULL
	
	IF @OverUnder610 <> 9999
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (610, 615, 616)
		AND (r.hdp1 IS NULL OR r.hdp1 <> @OverUnder610)
		
	IF @Quarter614 <> 'ALL' -- 80X
		DELETE r
		FROM #BetDelete AS r
		WHERE r.Bettype IN (614)
		AND (r.betcheck IS NULL OR r.betcheck <> '80' + @Quarter614)
	
	IF @BetTeam614 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam614,'^') AS b614 ON b614.val=r.org_betteam
		WHERE r.Bettype IN (614)
		AND b614.val IS NULL
		
	IF @BetTeam602 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam602,'^') AS b602 ON b602.val=r.org_betteam
		WHERE r.Bettype IN (602, 608)
		AND b602.val IS NULL
		
	IF @BetTeam601 <> 'ALL'
		DELETE r
		FROM #BetDelete AS r
			 LEFT JOIN dbo.strSplit(@BetTeam601,'^') AS b601 ON b601.val=r.org_betteam
		WHERE r.Bettype IN (601)
		AND b601.val IS NULL				

	CREATE NONCLUSTERED INDEX nl_Ref_custid_transid ON #BetDelete(custid,transid)  
	--FOR DELETE SECTION  
   
	--check no data  
	IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)   BEGIN  
		SELECT @ErrCode = 99  
		, @ErrMsg = 'No ticket found.'  

		EXEC dbo.NAP_Admin_CheckingProcess  
			@isExistParlay  = 1  
			, @IsReleased  = 1								
	END  
	ELSE  
	BEGIN  
		UPDATE	r  
			SET mainbettype = b.bettype  
				,maintransid = b.transid
				,mainstatusID = b.statusID  
		FROM	#BetDelete r  
			INNER JOIN dbo.bettrans b WITH(NOLOCK)  
				ON	r.refno = b.refno  
					AND b.matchid IN (9,29)  
					AND b.bettype IN (9,29)  
					
		------------------***** BegIN Special Delete *****------------------  

		-- BackUp bettransm tickets into zzzbettrans  
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype
		)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r 
				ON	r.transid=b.transid   

		--BackUp tickets of bettransm  
		INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				 winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				 winlostdate, betfrom, betcheck, checktime, matchid, bettype)  
		SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
				b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
				b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype  
		FROM	dbo.bettransm AS b WITH (nolock)  
			INNER JOIN #BetDelete AS r 
				ON	r.transid=b.transid   

		-- void process  
		DECLARE @matchdate		DATETIME
				,@match_tmp		VARCHAR(20)
				,@rowcount		INT
				,@step			INT
				,@transid_tmp	VARCHAR(2000)  

		SELECT	@matchdate = eventdate,  
				@match_tmp = CONVERT(VARCHAR(20),matchid),  
				@step = 0  
		FROM	match WITH(NOLOCK)   
		WHERE	matchid = @matchid  	 
		 
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
					FROM bettrans b WITH(NOLOCK)   
						INNER JOIN #BetDelete r 
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
			FROM	bettrans b WITH (NOLOCK)  
				INNER JOIN #BetDelete r 
					ON	b.refno = r.refno  
			WHERE	b.matchid = 29 
					AND b.bettype = 29  
			GROUP BY b.CustID    

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
			END CATCH  
		 
			--Get data after update  
			INSERT INTO #AfterUpd (custid, balance)  
			SELECT	b.custid, SUM (b.winlost - b.actual_stake + b.playercomm) balance  
			FROM	bettrans b WITH (NOLOCK) 
				INNER JOIN #BetDelete r 
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

		------ releasing SD process  
		EXEC dbo.NAP_Admin_CheckingProcess  
			@isExistParlay  = 1  
			, @IsReleased  = 1 

		SELECT	@LogData ='Void bet for matchid ' + CONVERT(VARCHAR(20), @matchid) + ' for Mix Parlay Special Delete'   
		  + ' IP=' + COALESCE(CAST(@Ip AS VARCHAR(15)),SPACE(1)) + ' reason: ' + @Reason 
		   
		EXEC WriteLog_UserLog @UserId = @UserId, @Doing = @LogData   

		--after delete, return all deleted tickets with additional information for mailing    
		IF EXISTS(SELECT 1 FROM dbo.strSplit(@bettypes,'^') WHERE CONVERT(INT, val) = 10)  --@bettype = 10  
		BEGIN  
			SELECT	MATCH.teamid AS homeid,  
					0 AS awayid,  
					MATCH.matchcode,  
					MATCH.eventdate,  
					MATCH.leagueid,  
					GETDATE() AS DATETIME,  
					CONVERT(BIT,0) AS IsNeutral  
					FROM Outright AS MATCH WITH (NOLOCK)  
					WHERE MATCH.orid = @matchID  
		END     
		ELSE  
		BEGIN  
			SELECT MATCH.homeid,  
					MATCH.awayid,  
					MATCH.matchcode,  
					MATCH.eventdate,  
					MATCH.leagueid,  
					GETDATE() AS DATETIME,  
					ISNULL(MATCH.isNeutral, CONVERT(BIT,0)) AS IsNeutral  
			FROM	MATCH WITH (NOLOCK)  
			WHERE	MATCH.matchid = @matchID  
		END  
		 
		-- Output new message structure  
		DECLARE @isITAdmin BIT   

		-- CHECK IT GROUP or NOT ?     
		IF EXISTS (SELECT TOP 1 1 FROM DBPOLICY.bodb02.dbo.accCustomer_1 a WHERE a.GroupID = 1 AND a.custid = @UserID) -- Check UserID in IT group  
		BEGIN    
			SELECT @isITAdmin = 1     
		END      

		
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
		SELECT	b.transid,  
				r.transid AS SubTransID,  
				r.refno,  
				b.custid,  
				b.transdate,     
				b.stake,  
				b.winlost-b.actual_stake AS winlost,  
				b.odds,     
				b.OddsType,    
				b.bettype,  
				b.status,  
				b.spositiontaking,  
				b.mpositiontaking,  
				b.apositiontaking,      
				b.currency,    
				b.CurrencyName AS CurrencyCode
				,r.bettype AS SubBettype  
				,m.homeid AS SubHomeId  
				,m.awayid AS SubAwayId  
				,r.hdp1 AS SubHdp1  
				,r.hdp2 AS SubHdp2  
				,b.hdp1  
				,b.hdp2  
				,r.odds AS SubOdds  
				,r.betfrom  
				,r.betteam as SubBetteam  
				,b.betteam  
				,r.livehomescore AS SubLiveHomeScore  
				,r.liveawayscore AS SubLiveAwayScore  
				,r.liveindicator AS SubLiveIndicator  
				,m.leagueid  
				,m.sporttype AS SubSportType  
				,m.isNeutral  
				,m.matchID  
				,m.matchCode  
				,b.betcheck  
				,r.betcheck AS SubBetCheck  
				,b.modds  
				,r.transdesc  
				,b.recommend  
				,b.mrecommend  
				,b.srecommend  
				-----------------------------  
				,ci.Username  
				,ci.username2  
				,cr.username AS creator   
				,ci.username AS CustUserName  
				,ci.username2 as CustUserName2  
				,ag.UserName AS AgUserName  
				,ma.UserName AS MagUserName  
				,su.Username AS SagUserName  
				---------------------------------------  
				,CASE   
				WHEN b.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair'   
				ELSE su.site   
				END AS EmailGroup  
				,su.site   
				,CASE WHEN s.custid IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS IsDeposit  
				,@isITAdmin AS IsITSupport  
		FROM	dbo.bettrans AS b WITH (NOLOCK)  
			INNER JOIN #BetDelete AS r WITH(NOLOCK)   
				ON	b.custid = r.custid AND b.refno = r.refno  
			INNER JOIN CTE_CustInfo ci WITH(NOLOCK)  
				ON	b.custid = ci.custid  
			INNER JOIN CTE_CustInfo cr WITH(NOLOCK)  
				ON	b.creator = cr.custid   
			INNER JOIN CTE_CustInfo ag WITH(NOLOCK)  
				ON	b.recommend = ag.custid  
			INNER JOIN CTE_CustInfo ma WITH(NOLOCK)  
				ON	b.mrecommend = ma.custid  
			INNER JOIN CTE_CustInfo su WITH(NOLOCK)  
				ON	b.srecommend = su.custid  
			LEFT JOIN custdb.dbo.Dep_CustSuper s with(nolock)
				ON	b.srecommend = s.custid  
			OUTER APPLY (  
				SELECT	m.homeid  
						,m.awayid  
						,m.leagueid  
						,m.sporttype  
						,m.isNeutral  
						,m.matchID  
						,m.matchCode  
				FROM	dbo.match AS m WITH(NOLOCK)   
				WHERE	m.matchid = @MatchID  
			) AS m  
		WHERE	b.matchid  IN (9,29)   
				AND b.bettype  IN (9,29)  
		ORDER BY b.transid   
	END   

	DROP TABLE #tblTransId  
	DROP TABLE #BetDelete    
	   
	SET NOCOUNT OFF  
END
GO