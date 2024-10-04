/*<info serverAlias="DBSIG-bodb02" executers="" isFunction="0"></info>*/
DECLARE
	@TransIds			VARCHAR(MAX) = '305468974722711571, 305473703481704505, 305513522123505695, 305471126501326892'
	,@ErrCode			INT = 0 
	,@ErrMsg			NVARCHAR(200) = '' 

/* 
	Created by: 20241004@Helen
	Task: Void invalid ticket - [211859]
	DB: SITEDB01/bodb02
	
	Revisions: 
		NAP_SpecialDelete_VoidBetId_UUS
*/

SELECT @ErrCode				= 0
	, @ErrMsg				= ''
	
DECLARE @beforeUpd 	TVP_BalanceWalletChange
		, @afterUpd 	TVP_BalanceWalletChange
		
CREATE TABLE #tblTransIds (transid BIGINT PRIMARY KEY)	
	
CREATE TABLE #BetDelete (
	GroupTransId	BIGINT -- parent Id (translog.traslogid | bettrans.transid)
	,transid		BIGINT PRIMARY KEY --bettrans.transid
	,matchid		INT
	,Bettype		SMALLINT
	,betid			BIGINT
	,stake			MONEY
	,odds			MONEY
	,refno			BIGINT 
	,betfrom		NVARCHAR(4)
	,statusid		TINYINT
	,betdaqid		BIGINT		
	,winlostdate	SMALLDATETIME
	,status			VARCHAR(10)
	,oddstype		TINYINT
	,transdate		DATETIME
	,betteam		NVARCHAR(10)
	,betcheck		NVARCHAR(50)
	,hdp1			SMALLMONEY
	,hdp2			SMALLMONEY
	,livehomescore	SMALLINT
	,liveawayscore	SMALLINT
	,liveindicator	BIT
	,winlost		MONEY
	,playercomm		MONEY
	,currency		TINYINT
	,transdesc		NVARCHAR(1000)
	,custid			INT
	,creator		INT
	,homeid			INT DEFAULT (0)
	,awayid			INT DEFAULT (0)
	,matchcode		NVARCHAR(50)
	,eventdate		DATETIME
	,leagueid		INT DEFAULT (0)
	,isNeutral		BIT
	,showtime		NVARCHAR(50)
	,username		VARCHAR(30)
	,recommend		INT
	,mrecommend		INT
	,srecommend		INT
	,sporttype		SMALLINT
	,oddsid			INT
	,ExtraInfo		VARCHAR(1000)
	,awinlost		MONEY
	,CurrencyName	NVARCHAR(50)
	,modds			SMALLMONEY
	,WalletType		TINYINT
	,RefCode		BIGINT
	,BonusID		INT
	,IsFinish		BIT
	,actual_stake   MONEY
)
	
CREATE TABLE #tblMatch (matchid INT)
	
BEGIN TRY
	INSERT INTO #tblTransIds (transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds,',')		
		
END TRY
BEGIN CATCH
	SELECT	@ErrCode = 101
			,@ErrMsg = 'Invalid TransIds.'										
		
	RETURN
END CATCH		
		
INSERT INTO #BetDelete(
	GroupTransId	
	,transid			
	,matchid		
	,Bettype		
	,betid			
	,stake			
	,odds	
	,refno			
	,betfrom		
	,statusid				
	,betdaqid		
	,winlostdate
	,status		
	,oddstype		
	,transdate		
	,betteam		
	,betcheck		
	,hdp1			
	,hdp2			
	,livehomescore	
	,liveawayscore	
	,liveindicator	
	,winlost		
	,playercomm		
	,currency	
	,transdesc		
	,custid			
	,creator	
	,recommend
	,mrecommend
	,srecommend
	,eventdate
	,oddsid
	,ExtraInfo
	,awinlost
	,CurrencyName
	,modds
	,WalletType
	,RefCode
	,BonusID
	,actual_stake
)
SELECT	
	b.transid AS groupTransId
	,b.transid
	,b.matchid
	,b.bettype
	,b.betid
	,b.stake
	,b.odds
	,b.refno
	,b.betfrom
	,b.statusID
	,b.betdaqid
	,b.winlostdate
	,b.status
	,b.oddstype
	,b.transdate
	,b.betteam
	,b.betcheck
	,b.hdp1
	,b.hdp2
	,b.livehomescore
	,b.liveawayscore
	,b.liveindicator
	,b.winlost - b.actual_stake
	,b.playercomm
	,b.currency
	,b.transdesc
	,b.custid
	,b.creator
	,b.recommend
	,b.mrecommend
	,b.srecommend
	,b.winlostdate
	,b.oddsid
	,b.ExtraInfo
	,b.awinlost
	,b.CurrencyName
	,b.modds
	,b.WalletType
	,b.RefCode
	,b.BonusID
	,b.actual_stake
FROM dbo.bettrans b WITH(NOLOCK)
	INNER JOIN #tblTransIds t
		ON b.transid = t.transid
WHERE b.statusID NOT IN (101, 102)

-- gather match Ids
INSERT INTO #tblMatch (matchid)
SELECT	matchid
FROM	#BetDelete
GROUP BY matchid
	
--check no data
IF NOT EXISTS (SELECT TOP 1 1 FROM #BetDelete)
BEGIN
 		SELECT	@ErrCode = 99
 				,@ErrMsg = 'No ticket found.' 									
		
	RETURN
END

-- STEP 1 : BackUp bettrans
-- 1.1  backup for normal tickets
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
	,SiteDBGroupID
	,RepUpdateTime
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
	,main.SiteDBGroupID
	,NULL --do not need to IH-Rep from SiteDB to Central because central already inserted too
FROM dbo.bettrans AS main WITH (NOLOCK)
	INNER JOIN #tblMatch tm 
	ON main.matchid = tm.matchid
	INNER JOIN #BetDelete AS tmpmain WITH (NOLOCK) 
	ON	main.transid = tmpmain.transid 
	AND main.matchid = tmpmain.matchid		
--capture balance before
INSERT INTO @BeforeUpd (
		matchid
	,custid
	,balanceType
	,BonusID
	,WalletType
	,balance
)
SELECT matchid
		, custid
		, CASE 
			WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
			WHEN tmp.sporttype = 162 THEN 3 -- Casino
			ELSE 4  -- Others
		END AS balanceType
		, CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		, ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		, SUM(winlost - actual_stake + playercomm) AS balance
FROM
(
	-- normal ticket
	SELECT tmpmain.custid
			, main.BonusID
			, main.WalletType
			, main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
	FROM dbo.bettrans main WITH (NOLOCK)
		INNER JOIN #BetDelete tmpmain
			ON	main.transid = tmpmain.transid
				AND main.transid = tmpmain.grouptransid
				AND main.matchid = tmpmain.matchid
) tmp
GROUP BY matchid
		, CustID
		, CASE 
			WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
			WHEN tmp.sporttype = 162 THEN 3 -- Casino
			ELSE 4  -- Others
		    END
		, CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		, ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets


/**********************************************   *************************************************************/
DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, BetId BIGINT)
DECLARE @TransIds_tmp VARCHAR(MAX) = ''

-- STEP 2 : Update bettrans/translog
-- 2.1. Update bettrans	for normal ticket
WHILE (1=1)
BEGIN
	DELETE @tmpTransIDBatch

	UPDATE TOP(2000) t
		SET IsFinish = 1
	OUTPUT  DELETED.transid
			,DELETED.BetID
	INTO @tmpTransIDBatch (TransId, BetId)
	FROM #BetDelete t
		INNER JOIN #tblMatch tm ON t.matchid = tm.matchid
	WHERE IsFinish IS NULL

	IF @@ROWCOUNT = 0 BREAK
	SELECT @TransIds_tmp = CAST((SELECT     m.TransId AS '@transid'
											,m.BetId AS '@betid'
								FROM @tmpTransIDBatch m
								FOR XML PATH('r')
									,ROOT('root')
							) AS VARCHAR(MAX));

	EXEC dbo.TicketVoiding_Admin_VoidingTransId
		@TransIds = @TransIds_tmp,
		@UserId = 10278938, --StarixIT
		@IssueTypeId = -1

	SET @TransIds_tmp = ''

END	
--capture balance after
INSERT INTO @AfterUpd (
			matchid
		,custid
		,balanceType
		,BonusID
		,WalletType
		,balance
	)
SELECT matchid	
		, custid
		, CASE 
			WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
			WHEN tmp.sporttype = 162 THEN 3 -- Casino
			ELSE 4  -- Others
		END AS balanceType
		, CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END AS BonusID
		, ISNULL(WalletType, 2) AS WalletType -- normal tickets are treated as cash tickets
		, SUM(winlost - actual_stake + playercomm) balance
FROM
(
	-- normal ticket
	SELECT tmpmain.custid
			, main.BonusID
			, main.WalletType
			, main.winlost, main.actual_stake ,main.playercomm, tmpmain.bettype, tmpmain.matchid,tmpmain.sporttype
	FROM dbo.bettrans main WITH (NOLOCK)
		INNER JOIN #BetDelete tmpmain
			ON	main.transid = tmpmain.transid
				AND main.transid = tmpmain.grouptransid
				AND main.matchid = tmpmain.matchid
) tmp
GROUP BY matchid
		, CustID
		, CASE 
			WHEN (tmp.sporttype BETWEEN 1 AND 99 OR tmp.sporttype = 154) OR tmp.bettype IN (9,29,10) THEN 1 -- Sports
			WHEN tmp.sporttype = 162 THEN 3 -- Casino
			ELSE 4  -- Others
			END
		, CASE WHEN BonusID > 0 AND WalletType = 1 THEN BonusID ELSE 0 END
		, ISNULL(WalletType, 2) -- normal tickets are treated as cash tickets

---INSERT data into pending balance table   
EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
		@BalanceWalletBefore	= @BeforeUpd
	, @BalanceWalletAfter	= @AfterUpd
	, @ActionId				= 0
		
DROP TABLE #tblTransIds
DROP TABLE #BetDelete
DROP TABLE #tblMatch


