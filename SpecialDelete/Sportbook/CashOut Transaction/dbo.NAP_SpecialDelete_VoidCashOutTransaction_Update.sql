/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Update]
(
	 @TransIds			VARCHAR(MAX)	= ''
	,@UserName 			NVARCHAR(50)
    ,@UserPassword		NVARCHAR(50)
    ,@UserId			INT
    ,@IP				VARCHAR(15)		= ''
    ,@Reason			NVARCHAR(500)	= ''
	,@ReasonSC			NVARCHAR(500)	= ''
)	
AS
/*
    Created by: 20170403@Kent
	Original: 
	Task: Delete Cash-out transaction
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20170424@Kent: Implement Concurrency Checking [Redmine:#72059]
		- 20170525@Kent: Remove dummy tables and fix bit datatype columns [Redmine:#77040]
		- 20171127@Kent: Integrate BullFighting [Redmine:#86832]	
		- 20180808@Helen: DB05.DBPOLICY migration - Move to DBCUST [Redmine:99462]
		- 20181207@Alan: Support Chinese Email [105976]
		- 20190731@Raymond.Le: Return column for display Deposit name in Email [Redmine: #117896]
		- 20210514@July: SD - Remove unused code/products [Redmine: #121752]
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20211105@July: Update column RepUpdateTime when Void/Recover - [Redmine: #164236]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220221@Max: TVS Auto Calculate When Cancel Cash Out Transaction [Redmine: #168774]
		- 20220303@Max: [TVS] Update Virtual Setting when Cancel CO and some enhancements [Redmine: #169237]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230328@July: [TVS] Remove write log to DBTrans DBLog [Redmine: #185245]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185245]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230818@Max: [TVS] Cancel Cash Out Action - Search by BetID [Redmine: #186624]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240725@Max: [TVS] Return betid to call remoting ref [Redmine: #205983]
		- 20241125@Lani: [TVS] Update the value of 'EmailGroup' returned, change serverAlias [Redmine: #213451]

	Explanation's Param:

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
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_VoidCashOutTransaction_Update '
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE '@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @UserName IS NULL THEN '' ELSE ',@UserName = ' + CONVERT(NVARCHAR(50), @UserName) END
				+ CASE WHEN @UserPassword IS NULL THEN '' ELSE ',@UserPassword = ''' + CONVERT(NVARCHAR(50), @UserPassword) + '''' END
				+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END
				+ CASE WHEN @Reason IS NULL THEN '' ELSE ',@Reason = ''' + CONVERT(NVARCHAR(500), @Reason) + '''' END
				+ CASE WHEN @ReasonSC IS NULL THEN '' ELSE ',@ReasonSC = ''' + CONVERT(NVARCHAR(500), @ReasonSC) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @avaiableProcess 	BIT = 0
		  , @isITAdmin			BIT = 0
		  , @Movebetdate		DATETIME
		  , @FCUpdateTime		DATETIME2
		  , @xmlTransId			VARCHAR(MAX) = ''
		  , @SiteDBGroupID		SMALLINT
		  , @ErrCode			INT				= 0		
		  , @ErrMsg				VARCHAR(300)	= ''	
		  , @InvalidTransIds	VARCHAR(MAX)	= ''	
		  , @transInfo			VARBINARY(MAX) 
		  , @MatchId			INT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @session NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))

	CREATE TABLE #tblTransIds (transid BIGINT)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #SpecialDeleteBets (
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				SMALLMONEY,
		OddsType			INT,
		WinLost				MONEY,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Status				NVARCHAR(10),
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,
		RefNo				BIGINT,
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		UserName			VARCHAR(30),
		UserName2			VARCHAR(50),
		TransDate			DATETIME,
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		mrecommend			INT,
		srecommend			INT,
		matchid				INT,
		awinlost			MONEY,
		CurrencyName		NVARCHAR(50),
		BetFrom				NVARCHAR(4),
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		ActualStake			MONEY,
		statuswinlost		TINYINT,
		modds				SMALLMONEY,
		SiteDBGroupID		SMALLINT,
		BetId				BIGINT,
	)
	CREATE INDEX IDX_SpecialDeleteBets_RefNo_Bettype_matchid_custid	
	ON #SpecialDeleteBets(RefNo, BetType, matchid, custid) INCLUDE(stake)

	CREATE TABLE #tblCustInfo (
		custid INT,
		username NVARCHAR(30),
		username2 NVARCHAR(50),
		currency TINYINT,
		[site] VARCHAR(10)		
	)
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange

	DECLARE @tmpTransInfo TABLE (transId BIGINT, matchId INT
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT, ruben TINYINT
		,FcUpdateTime DATETIME2,creator INT, betdaqid BIGINT, virtualrate FLOAT
	)

	DECLARE @tmpMatchId AS TABLE (MatchId INT, IsFinish BIT)
	
	SELECT @ErrCode	= 0
		 , @ErrMsg = ''
		 , @InvalidTransIds	= ''	
	
	IF NOT EXISTS (SELECT 1
					FROM custDB.dbo.customer WITH(NOLOCK)
					WHERE userpwd = @UserPassword
						AND custid = @UserID
						AND roleid>=5)
	BEGIN
		SELECT @ErrMsg = 'Sorry. You can not process void bet due to either wrong password or insufficient permission!'
			 , @ErrCode  = 113

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds
		
		RETURN
	END		
	
	--> parse @TransIds
	INSERT INTO #tblTransIds (transid)
	SELECT	t.value
	FROM STRING_SPLIT(@TransIds, ',') t
		
	INSERT INTO #SpecialDeleteBets(
					TransId,
					BetType,
					BetTeam,
					Stake,
					Odds,
					OddsType,
					WinLost,
					Hdp1,
					Hdp2,
					Status,
					IsLiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					RefNo,
					BetCheck,
					TransDesc,
					UserName,
					TransDate,
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,
					mrecommend,
					srecommend,
					matchid,
					awinlost,
					betfrom,
					CurrencyName,
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode,
					EventDate,
					ActualStake,
					statuswinlost,
					modds,
					SiteDBGroupID,
					BetId
			)
	SELECT 	sub.TransId,
			sub.BetType,
			sub.BetTeam,
			sub.Stake,
			sub.Odds,
			sub.OddsType,
			sub.WinLost - sub.Actual_Stake AS WinLost,
			sub.Hdp1,
			sub.Hdp2,
			sub.Status,
			sub.liveindicator AS IsLiveIndicator,
			sub.LiveHomeScore,
			sub.LiveAwayScore,
			sub.RefNo,
			sub.BetCheck,
			sub.TransDesc,
			sub.UserName,
			sub.TransDate,
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			sub.recommend,
			sub.mrecommend,
			sub.srecommend,
			sub.matchid,
			sub.awinlost,
			sub.betfrom,
			sub.CurrencyName,
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.eventdate,
			sub.actual_stake AS ActualStake,
			sub.statuswinlost,
			sub.modds,
			sub.SiteDBGroupID,
			sub.betid
	FROM dbo.bettrans sub WITH(NOLOCK)
		 INNER JOIN dbo.match m WITH(NOLOCK) 
				 ON m.matchid = sub.matchid
	WHERE	sub.transid IN (SELECT t.transid FROM #tblTransIds t)
			AND sub.betdaqid = -2 
			AND sub.statusID IN (103, 111, 112, 113)
			AND sub.SiteDBGroupID = @SiteDBGroupID
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS ( SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE EventDate <= @Movebetdate )
	BEGIN
		SELECT @ErrCode = 112
			 , @ErrMsg = 'Could not void some tickets due to Movebet process. Please try Search again.'
				
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds

		RETURN
	END

	--> check no data
	IF (NOT EXISTS( SELECT 1 FROM #SpecialDeleteBets))
	BEGIN
		IF @InvalidTransIds = ''		
			SELECT @ErrMsg = 'No ticket found.'
				 , @ErrCode  = 119

		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds

		RETURN
	END
	
	--> check and not allow attempt to void tickets of this match while it's being calculated
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid, 1 AS KeyID
	FROM #SpecialDeleteBets
		
	EXEC dbo.NAP_Admin_CheckingProcess
		  @isExistMatch		= 1
		, @spName			= @spName
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN		
		SELECT @ErrCode AS ErrorCode
			, @ErrMsg AS ErrorMsg
			, @InvalidTransIds AS InvalidTransIds

		RETURN
	END	
	
	--> backup cash-out transaction ticket
	INSERT INTO dbo.zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
				winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
				winlostdate,betfrom,betcheck,checktime,matchid, bettype, comstatus, RepUpdateTime, SiteDBGroupID)
	SELECT  b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
			b.winlostdate, b.betfrom, @session AS betcheck, b.checktime, b.matchid, b.bettype, 'CO', SYSDATETIME(), b.SiteDBGroupID
	FROM	dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #SpecialDeleteBets s
			ON	s.transId = b.transid
	
	--> capture before		
	INSERT INTO @BeforeUpd (custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets s
			ON s.transId = b.transid
	) AS temp
	GROUP BY temp.custid
	
	--> update bettrans
	/*1. Update to running for CO Transaction*/
	SET @FCUpdateTime = SYSDATETIME()
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET		b.winlost = 0
			,b.awinlost = 0
			,b.mwinlost = 0
			,b.swinlost = 0
			,b.playercomm = 0
			,b.comm = 0
			,b.acomm = 0
			,b.scomm = 0
			,b.status = 'running'
			,b.statusID = 0
			,b.ruben = 0
			,b.creator = @UserId
			,b.betdaqid = -1
			,b.virtualrate = CASE WHEN c.VirtualRate = 0 THEN b.virtualrate ELSE c.VirtualRate END
			,b.FcUpdateTime  = @FCUpdateTime
		OUTPUT inserted.TransId, inserted.matchid, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost, inserted.playercomm, inserted.comm, inserted.acomm
			, inserted.scomm, inserted.status, inserted.statusID, inserted.ruben, inserted.creator, inserted.betdaqid, inserted.virtualrate, inserted.FcUpdateTime
		INTO @tmpTransInfo (transId, matchId, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, Status, StatusID, ruben, creator, betdaqid, virtualrate, FcUpdateTime)
	FROM	dbo.bettrans b 
		INNER JOIN #SpecialDeleteBets s ON	b.transid = s.transId
		INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON b.transid = c.TransID		

	/*Sycn ticket SiteDB to Central*/
	IF @SiteDBGroupID <> 0
	BEGIN
		INSERT INTO @tmpMatchId (MatchId)
		SELECT DISTINCT t.matchId
		FROM @tmpTransInfo t

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1) m SET @MatchId = m.MatchId
				, m.IsFinish = 1			
			FROM @tmpMatchId m 
			WHERE m.IsFinish IS NULL

			IF @@ROWCOUNT = 0
				BREAK

			SET @transInfo = COMPRESS((
			SELECT	b.transId AS 't'
					, b.winlost AS 'w'
					, b.awinlost AS 'aw'
					, b.mwinlost AS 'mw'
					, b.swinlost AS 'sw'
					, b.playercomm AS 'pc'
					, b.comm AS 'c'
					, b.acomm AS 'ac'
					, b.scomm AS 'sc'
					, b.status AS 's'
					, b.statusID AS 'sid'			
					, b.ruben AS 'r'
					, b.creator AS 'cr'
					, b.betdaqid AS 'bdaq'
					, b.virtualrate AS 'v'
					, b.FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo b
			WHERE b.matchId = @MatchId
			FOR JSON PATH))

			IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
			BEGIN
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'Cancel_CO', 'bettrans', 'U', @matchid, @transInfo, 's'
			END
		END
	END

	/*2. Re-Cal for CO Transaction already has statuswinlost*/
	SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									FROM	#SpecialDeleteBets t
									WHERE t.statuswinlost IS NOT NULL
									FOR XML PATH('r'), ROOT('root')
								)
	IF @xmlTransId <> ''
	BEGIN
		EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
			@TransIds = @xmlTransId
	END

	--> capture after
	INSERT INTO @AfterUpd(custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #SpecialDeleteBets s
			ON s.transId = b.transid							
	) AS temp
	GROUP BY temp.custid				
	
	--> compare BALANCE
	EXEC [dbo].[NAP_Admin_BalancePendingIns]
		@BeforeUpd	 = @beforeUpd
		, @AfterUpd	 = @afterUpd

	--Update CashoutSelling
	UPDATE s
	SET s.CashOutStatus = 6
		, s.CashoutExtraInfo = REPLACE(s.CashoutExtraInfo, '</root>', c.CashOutExtraInfo) + '</root>'
		, s.ChangeDate = CONVERT(DATETIME,@FCUpdateTime)
	FROM dbo.CashOutSelling s WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (
				SELECT N'<r ct=''' + CONVERT(VARCHAR(30),CONVERT(DATETIME,@FCUpdateTime),21) + ''' s=''6'' w=''0''/>' AS CashOutExtraInfo
				FROM #SpecialDeleteBets t
				WHERE t.TransId = s.TransID
			)c

	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
		
	-- CHECK IT GROUP or NOT ?   
	SET @IsITAdmin  = ISNULL((SELECT IsValid FROM dbo.f_NAP_UserControl_UserSelect (@UserId,2)),0)

	--1. Output table validate
	SELECT @ErrCode AS ErrorCode
		, @ErrMsg AS ErrorMsg
		, @InvalidTransIds AS InvalidTransIds
	
	--- Return all additional information for mailing 
	;WITH CTE_CustIdAll AS (
		SELECT DISTINCT t.custid
		FROM #SpecialDeleteBets b
		CROSS APPLY (
			VALUES (custid)
			,(recommend)
			,(mrecommend)
			,(srecommend)
		) AS t (custid)
	)
	INSERT INTO #tblCustInfo (
		custid
		,username
		,username2
		,site
		,currency
	)
	SELECT ci.custid
		,ci.username
		,ci.username2
		,ci.site
		,ci.currency
	FROM CustDB.dbo.Customer AS ci WITH (NOLOCK)
	INNER JOIN CTE_CustIdAll AS ca ON ci.custid = ca.custid		
	
	SELECT	d.TransId,
			d.BetType AS BetTypeId,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,
			d.WinLost,
			d.Hdp1 AS Handicap1,
			d.Hdp2 AS Handicap2,
			d.Status,
			d.IsLiveIndicator AS IsLive,
			d.LiveHomeScore,
			d.LiveAwayScore,
			d.RefNo,
			d.BetCheck,
			d.TransDesc,
			d.UserName,
			ci.username2,
			d.TransDate,
			d.ExtraInfo,
			d.BetdaqId,
			d.matchid,
			d.custid,
			d.recommend,
			ag.UserName AS AgUserName,
			d.mrecommend,
			ma.UserName AS MagUserName,
			d.srecommend,  
			su.Username AS SagUserName, 
			ci.Site,
			CASE 
				WHEN d.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'Betfair' 
				ELSE ci.Site 
			END AS EmailGroup, 
			ag.currency,
			d.CurrencyName, 				
			@isITAdmin AS IsITSupport,
			d.BetFrom,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode ,
			d.ActualStake,
			d.modds AS MasterOdds,
			d.SiteDBGroupID,
			d.BetId
	FROM #SpecialDeleteBets AS d
	LEFT JOIN #tblCustInfo AS ci ON d.custid = ci.custid
	LEFT JOIN #tblCustInfo AS ag ON d.recommend = ag.custid	
	LEFT JOIN #tblCustInfo AS ma ON d.mrecommend = ma.custid
	LEFT JOIN #tblCustInfo AS su ON d.srecommend = su.custid
	ORDER BY ci.site ASC, d.TransId ASC
	
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, NULL, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH

	DROP TABLE #tblTransIds
	DROP TABLE #tblMatchProcess
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblCustInfo

	SET NOCOUNT OFF
END
GO