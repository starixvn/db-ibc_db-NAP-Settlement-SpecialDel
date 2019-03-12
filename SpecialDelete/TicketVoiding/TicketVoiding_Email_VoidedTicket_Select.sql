/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Email_VoidedTicket_Select]
	@VoidingHistoryId		INT = NULL
AS
/*	Created by: Kathy
	Date 20181212
	Task: get voided ticket to send email [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @isITAdmin BIT

	DECLARE @tmpVoidingHistory TABLE (VoidingHistoryId INT)

	CREATE TABLE #tmpTicket (
		TransId			BIGINT
		,matchid		INT
		,custid			INT
		,recommend		INT
		,mrecommend		INT
		,Srecommend		INT
		,TransDate		DATETIME
		,actual_stake	MONEY
		,Stake			MONEY
		,winlost		MONEY
		,Status			NVARCHAR(10)
		,Betcheck		NVARCHAR(50)
		,betdaqid		BIGINT
		,betid			BIGINT
		,betfrom		NVARCHAR(1)
		,Betteam		NVARCHAR(10)
		,Bettype		SMALLINT
		,OriginalBettype SMALLINT
		,Currency		TINYINT
		,CurrencyName	NVARCHAR(50)
		,Hdp1			SMALLMONEY
		,Hdp2			SMALLMONEY
		,LiveHomeScore	SMALLINT
		,LiveAwayScore	SMALLINT
		,Odds			SMALLMONEY
		,Oddsspread		MONEY
		,oddstype		TINYINT
		,BonusId		INT
		,WalletType		TINYINT
		,RefCode		BIGINT
		,ExtraInfo		VARCHAR(1000)
		,TransDesc		NVARCHAR(1000)
		,Username		NVARCHAR(50)
		
		,IsMixParlay	BIT DEFAULT (0)
		,subbetcheck	NVARCHAR(50)
		,subOdds		SMALLMONEY
		,subbetteam		NVARCHAR(10)
		,subbettype		SMALLINT
		,subhdp1		SMALLINT
		,subhdp2		SMALLINT
		,subtransdesc	NVARCHAR(1000)
		
		,Refno			BIGINT
		,subTransId		BIGINT	
		,VoidedTime		DATETIME
		,IsCashOutMemberTicket BIT
		,isITAdmin		BIT
		
		,TicketType		TINYINT -- 1: single, 2 - parlay, 3 - cash out
	)

	SELECT @isITAdmin = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (UserId,2)),0)
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	WHERE	vh.VoidingHistoryId = @VoidingHistoryId

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId) VALUES (@VoidingHistoryId)		
			
	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Bettype, Refno, Odds)
	SELECT	z.transid			
			,z.matchid
			,z.status
			,z.VoidedTime
			,z.custid
			,z.winlost
			,z.bettype
			,z.refno
			,z.odds
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		CROSS APPLY (
			SELECT	z.transid
					,z.matchid
					,z.status
					,z.transdate AS VoidedTime
					,z.custid
					,z.winlost
					,z.bettype
					,z.refno
					,z.odds
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	z.VoidingHistoryId = vh.VoidingHistoryId
					AND 1 = CASE
								WHEN z.bettype = 911 THEN 1
								WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
								ELSE 0
							END
		) z
	WHERE	vh.VoidingHistoryId = @VoidingHistoryId

	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, Refno, Status, VoidedTime, custid)
	SELECT	zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status
			,zm.VoidedTime
			,zm.custid
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		CROSS APPLY (
			SELECT	zm.transid
					,zm.matchid
					,zm.refno 
					,zm.status
					,zm.transdate AS VoidedTime
					,zm.custid
			FROM	dbo.zzzbettransm zm WITH(NOLOCK)
			WHERE	zm.VoidingHistoryId = vh.VoidingHistoryId
		) zm
	WHERE	vh.VoidingHistoryId = @VoidingHistoryId

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE Bettype = 911)
	BEGIN
		UPDATE t
			SET OriginalBettype = b.bettype
				,odds = b.odds
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON t.Refno = b.transid
		WHERE	t.Bettype = 911
	END

	UPDATE t 
		SET actual_stake = b.actual_stake
			,Betcheck = b.betcheck
			,betdaqid = b.betdaqid
			,betid = b.betid
			,betteam = b.betteam
			,bettype = b.bettype
			,ExtraInfo = b.ExtraInfo
			,hdp1 = b.hdp1
			,hdp2 = b.hdp2
			,liveawayscore = b.liveawayscore
			,livehomescore = b.livehomescore
			,oddsspread = b.oddsspread
			,oddstype = b.oddstype
			,RefCode = b.RefCode
			,stake = b.stake
			,transdesc = b.transdesc
			,Username = b.Username
			,BonusId = b.BonusID
			,WalletType = b.WalletType
			,winlost = t.winlost - b.actual_stake
			,currency = b.currency
			,CurrencyName = b.CurrencyName
			,betfrom = b.betfrom
			,transdate = b.transdate
			,refno = b.refno

			,srecommend = b.srecommend
			,mrecommend = b.mrecommend
			,recommend = b.recommend
	FROM	#tmpTicket t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
			
	
	UPDATE	t
		SET transid = b.transid
			,actual_stake = b.actual_stake
			,Betcheck = b.betcheck
			,betdaqid = b.betdaqid
			,betid = b.betid
			,betteam = b.betteam
			,bettype = b.bettype
			,ExtraInfo = b.ExtraInfo
			,hdp1 = b.hdp1
			,hdp2 = b.hdp2
			,liveawayscore = b.liveawayscore
			,livehomescore = b.livehomescore
			,odds = b.odds
			,oddsspread = b.oddsspread
			,oddstype = b.oddstype
			,RefCode = b.RefCode
			,stake = b.stake
			,transdesc = b.transdesc
			,Username = b.Username
			,BonusID = b.BonusID
			,WalletType = b.WalletType
			,winlost = b.winlost
			,currency = b.currency
			,CurrencyName = b.CurrencyName
			,betfrom = b.betfrom
			,transdate = b.transdate

			,IsMixParlay = 1
			,subbetcheck = bm.betcheck
			,subOdds = bm.odds
			,subbetteam = bm.betteam
			,subbettype = bm.bettype
			,subhdp1 = bm.hdp1
			,subhdp2 = bm.hdp2
			,subtransdesc = bm.transdesc

			,srecommend = b.srecommend
			,mrecommend = b.mrecommend
			,recommend = b.recommend
	FROM	#tmpTicket t
		INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON	t.subTransId = bm.transid
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29
	
	SELECT	m.homeid
			,m.awayId
			,m.awayid AS subawayid 
			,m.homeid AS subhomeid
			,m.leagueid
			,m.sporttype
			,m.matchcode
			,m.showtime 
			,m.isneutral

			,CASE WHEN t.Bettype BETWEEN 801 AND 806 THEN t.Refno ELSE t.TransId END AS TransId
			,t.Refno
			,t.TransDate
			,t.actual_stake
			,t.Stake
			,t.winlost
			,t.Status
			,t.Betcheck
			,t.betdaqid
			,t.betid
			,t.betfrom
			,t.Betteam
			,t.Bettype AS BetTypeId
			,t.OriginalBettype
			,t.Currency
			,t.CurrencyName	
			,t.Hdp1 AS Handicap1
			,t.Hdp2 AS Handicap2 
			,t.LiveAwayScore
			,t.LiveHomeScore
			,t.Odds
			,t.Oddsspread
			,t.oddstype
			,t.WalletType
			,t.RefCode
			,t.ExtraInfo
			,t.TransDesc

			,t.IsMixParlay
			,t.subTransId
			,t.subbetcheck
			,t.subOdds
			,t.subbetteam
			,t.subbettype
			,t.subhdp1
			,t.subhdp2
			,t.subtransdesc
			
			,t.custId
			,t.recommend
			,t.mrecommend
			,t.srecommend
			,c.username
			,c.username2
			,ag.username AS AgUserName
			,ma.username AS MagUserName
			,su.username AS SagUserName
			
			,CASE 
				WHEN ag.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'BetFair'
				ELSE su.site
			END AS EmailGroup
			,su.site
			,CASE WHEN t.betdaqid = 0 AND t.extrainfo IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS isBetTrade
			,CASE WHEN t.betdaqid = 1 AND t.Bettype NOT BETWEEN 901 AND 920 THEN 1 ELSE 0 END AS isCashOut
			,@isITAdmin AS IsITSupport 

	FROM	#tmpTicket t
		INNER JOIN dbo.match m WITH(NOLOCK) ON t.matchid = m.matchid
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = t.custid
		LEFT JOIN CustDB.dbo.Customer ag WITH(NOLOCK) ON ag.custid = t.recommend 
		LEFT JOIN CustDB.dbo.Customer ma WITH(NOLOCK) ON ma.custid = t.mrecommend
		LEFT JOIN CustDB.dbo.Customer su WITH(NOLOCK) ON su.custid = t.srecommend 	
	ORDER BY TransId

	--Metric API Calling  
	SELECT t.refno  
		,t.Bettype  
		,t.custid  
		,b.statusID  
		,b.winlost  
		,t.odds  
		,t.OddsType  
		,t.stake   
		,t.transdesc  
		,tl.SiteId
	FROM #tmpTicket t  
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.transid = b.transid  
		INNER JOIN dbo.translog tl WITH(NOLOCK) ON	tl.translogid = t.refno  
	WHERE	t.Bettype IN (805,806)  
	ORDER BY t.refno  
	
END
GO
