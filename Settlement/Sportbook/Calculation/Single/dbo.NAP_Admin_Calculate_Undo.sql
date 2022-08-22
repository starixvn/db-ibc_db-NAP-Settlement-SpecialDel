/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Undo] 
	 @matchid		INT
	,@strBettypes	VARCHAR(MAX)	= NULL	
AS
/*
	Created: Kathy
	Date: 20140213
	Task : unsettle a match, called by main SP Acc_Settlement_Undo, uses Rep execution
	DB: DBTXN.bodb02
	Original: Admin_Calculate_Undo

	Revisions:
		- 20140905@Lukas: exclude virtual racing bettype 1231,1232,1233
		- 20140909@Kathy: Exclude virtual racing (bettype 1231,1232,1233, 1237, 1238), outright (bettype 10, 31, 32, 33), keno (1501 -> 1599)
		- 20141022@Jamie: Sporting Solution for Tennis [Redmine:#23034]
		- 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
		- 20150608@Johnson: Exclude SOLD/BOUGHT/COM tickets from bettrade [Redmine:#35921] 
		- 20150715@Johnson: Exclude range bettypes of Metric Gaming from settlement of SB [Redmine: #37688]
		- 20160106@Kathy: Integrate Cricket [Redmine:#49727]
		- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170328@Bobby: Integrate CashOut bettypes [Redmine:#73404]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20170911@Kathy: Auto BetRadar - correct affected tickets [Redmine:#72789]
		- 20180122@Kathy: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180717@Kathy: Allow to UNDO on DB042 [Redmine:#97842]
		- 20180815@Kathy: Change clustered index on DB042 [Redmine:99841]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190603@Sol: Incorporate PHAIO 4 [Redmine:#112885]
		- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
		
	Param's Explanation:
			• @matchid: matchid of match to be unsettled 
*/
BEGIN
	SET NOCOUNT ON
	
	-- CHECK SERVER BEFORE UNDO
	DECLARE @ServerName		SYSNAME 
			,@AllowUndo		BIT
			,@IsSiteDB	BIT  = 0

	SET @ServerName = @@SERVERNAME
	
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName	= @ServerName
			,@AllowUndo	= @AllowUndo	OUTPUT

		IF @AllowUndo = 0
			RETURN
	END
	-- END CHECK

	DECLARE	@xml					XML
		
			,@BatchCount			INT
			,@BatchNo				INT
			,@MinCustId				INT
			,@MaxCustId				INT
			,@MinTransId			BIGINT
			,@MaxTransId			BIGINT
			,@TransIdOfMinCust		BIGINT
			,@TransIdOfMaxCust		BIGINT
			,@totalWinScore			VARCHAR(10)
			,@odds					MONEY
			,@posOdds				INT
			,@posComma				INT
			,@IsUpd_Void			BIT = 0
			,@FcUpdateTime			DATETIME2
			,@transInfo	XML
	
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,modds MONEY, odds SMALLMONEY, oddsspread MONEY, statuswinlost VARCHAR(1)
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
			,bef_winlost MONEY ,bef_statusid TINYINT
			,FcUpdateTime DATETIME2
		)
		
	DECLARE @tblBettypes TABLE (bettype SMALLINT,GroupName VARCHAR(50), GroupId SMALLINT)

	DECLARE @tmpBatch AS TABLE (
		BatchNo					INT
		,CustId					INT
		,MinCustId				INT
		,MaxCustId				INT
		,MinTransId				BIGINT
		,MaxTransId				BIGINT
		,TransIdOfMinCust		BIGINT
		,TransIdOfMaxCust		BIGINT
		,UNIQUE CLUSTERED (BatchNo, CustId)
	)

	SELECT	@xml = CONVERT(XML, @strBettypes)
			,@BatchCount = 2000

	INSERT INTO @tblBettypes (bettype, GroupName, GroupId)
	SELECT	T.c.value('./@t','SMALLINT')
			,T.c.value('./@n','VARCHAR(50)')
			,T.c.value('./@g','SMALLINT')
	FROM	@xml.nodes('/root/r') AS T(c)
	OPTION ( OPTIMIZE FOR ( @xml = NULL ) )

	INSERT INTO @tmpBatch (BatchNo, CustId, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
	SELECT	BatchNo
			,CustId
			,MAX(CASE WHEN MinRn = 0 THEN CustId ELSE 0 END) AS FromCustId
			,MAX(CASE WHEN MaxRn = 1 THEN CustId ELSE 0 END) AS ToCustId
			,MAX(CASE WHEN TransIdAsc = 1 THEN transId ELSE 0 END ) AS FromTransId	
			,MAX(CASE WHEN TransIdDesc = 1 THEN transId ELSE 0 END ) AS ToTransId			
			,MAX(CASE WHEN MinRn = 0 THEN transid ELSE 0 END) AS TransIdOfMinCust
			,MAX(CASE WHEN MaxRn = 1 THEN transid ELSE 0 END) AS TransIdOfMaxCust
	FROM (
		SELECT	n.BatchNo
				,b.CustId
				,b.transid
				,(rn - 1)%@BatchCount AS MinRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
		FROM	(
			SELECT	transid
					,CustId
					,ROW_NUMBER() OVER (ORDER BY CustId, transid) AS rn
			FROM	dbo.bettrans b WITH(NOLOCK)
				INNER JOIN @tblBettypes t
					ON	b.bettype = t.bettype
			WHERE	matchid = @matchid
					AND	b.statusID NOT IN (101)  ---('reject')
					AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
		)b
		CROSS APPLY (	
			SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
		)n
	)b
	GROUP BY BatchNo, CustId
		
	SELECT @BatchNo = MAX(BatchNo)
	FROM @tmpBatch
		
	WHILE @BatchNo > 0
	BEGIN
		SELECT	@MinCustId = MAX(MinCustId)
				,@MaxCustId = MAX(MaxCustId)
				,@MinTransId = MAX(MinTransId)
				,@MaxTransId = MAX(MaxTransId)
				,@TransIdOfMinCust = MAX(TransIdOfMinCust)
				,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
		FROM	@tmpBatch
		WHERE	BatchNo = @BatchNo

		SET @FcUpdateTime = SYSDATETIME()

		UPDATE	b
			SET 
				@totalWinScore = CASE WHEN b.bettype IN (468,469) 
										THEN  CAST(CAST(
													CASE WHEN b.betteam IN ('h','o') THEN b.hdp1 - b.hdp2 + 1
														WHEN b.betteam IN ('a','u') THEN b.hdp1
													END
												 AS INT) AS VARCHAR(10))
										ELSE @totalWinScore
									END
				,@posOdds = CASE WHEN b.bettype IN (468,469) THEN CHARINDEX(@totalWinScore + ':', b.betcheck) + LEN(@totalWinScore) + 1 ELSE @posOdds END
				,@posComma = CASE WHEN b.bettype IN (468,469) THEN CHARINDEX(',', b.betcheck + ',', @posOdds) ELSE @posComma END
				,@odds = CASE WHEN b.bettype IN (468,469) THEN SUBSTRING(b.betcheck, @posOdds, @posComma - @posOdds) ELSE @odds END
				
				,@IsUpd_Void = CASE WHEN statusID = 102 OR mt.TransId IS NOT NULL THEN 0 ELSE 1 END
				
				,odds = CASE WHEN b.bettype IN (468,469) THEN @odds ELSE odds END
				,oddsspread = CASE WHEN b.bettype IN (468,469) THEN @totalWinScore ELSE oddsspread END
				
				,ruben = CASE 
							WHEN @IsUpd_Void = 0 THEN ruben 
							ELSE 0
						END
								
				,STATUS = CASE 
							WHEN @IsUpd_Void = 0 THEN b.[status] 
							ELSE 'running'
						END
						
				,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN statusID 
							ELSE 0
						END
				,winlost = CASE 
							WHEN @IsUpd_Void = 0 THEN winlost 
							ELSE 0
						END
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,statuswinlost = NULL
				,FcUpdateTime = CASE WHEN b.statusid = 0 THEN b.FcUpdateTime ELSE @FcUpdateTime END
		OUTPUT	inserted.transid
				,inserted.modds, inserted.odds, inserted.oddsspread
				, CASE WHEN inserted.StatusWinlost IS NULL THEN '' ELSE CAST(Inserted.Statuswinlost AS VARCHAR(1)  ) END AS statuswinlost
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.Status,inserted.StatusID,inserted.ruben	
				,deleted.winlost ,deleted.statusid
				,CASE WHEN inserted.FcUpdateTime <> deleted.FcUpdateTime THEN inserted.FcUpdateTime ELSE NULL END
			INTO @tmpTransInfo (
				transId
				,modds, odds, oddsspread, statuswinlost,WinLost,aWinLost
				,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben
				,bef_winlost  ,bef_statusid 
				,FcUpdateTime
			)
		FROM	dbo.bettrans b WITH (ROWLOCK)
			INNER JOIN @tmpBatch c
				ON	c.BatchNo = @BatchNo
					AND c.CustId = b.custid
			CROSS APPLY (
				SELECT	TOP 1 bettype, GroupId, GroupName
				FROM	@tblBettypes t
				WHERE	b.bettype = t.bettype
			)t
			CROSS APPLY (
				SELECT CASE
							WHEN c.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
							WHEN c.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
							WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
							ELSE 0
						END AS IsCalculated
			)i
			OUTER APPLY (
					SELECT	TOP (1) mt.TransId
					FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
					WHERE	mt.TransId = b.transid
							AND mt.CustId = c.custId
				) mt
				
		WHERE	b.matchid = @matchid 
				AND	b.statusID NOT IN (101)  ---('reject')
				AND 1 = CASE WHEN b.statusID IN (0, 1) AND mt.TransId IS NOT NULL THEN 1 
							 WHEN b.statusID NOT IN (0, 1) THEN 1
							ELSE 0 END
							
				AND i.IsCalculated = 1				
				AND ISNULL(b.betdaqid,0) <> - 2	
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
		
		IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo)
		BEGIN
			SET @transInfo = (
				SELECT	transId AS '@t'
						,modds AS '@m'	
						,odds AS '@o'
						,oddsspread AS '@os'
						,statuswinlost AS '@statuswl'
						,WinLost AS '@w' 
						,aWinLost AS '@aw' 
						,mWinLost AS '@mw' 
						,sWinLost AS '@sw' 
						,PlayerComm AS '@pc' 
						,Comm AS '@c' 
						,aComm AS '@ac' 
						,sComm AS '@sc' 
						,Status AS '@s' 
						,StatusID AS '@sid' 
						,ruben AS '@r'		
						,bef_winlost AS '@bef_w' 
						,bef_statusid AS '@bef_sid' 
						,FcUpdateTime AS '@rut'
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			SELECT 'Settlement', 'Undo', 'bettrans', @MatchId, @transInfo
			
			DELETE FROM @tmpTransInfo
		END
		SET @BatchNo = @BatchNo - 1

		WAITFOR DELAY '00:00:00:010'
	END
END
GO
