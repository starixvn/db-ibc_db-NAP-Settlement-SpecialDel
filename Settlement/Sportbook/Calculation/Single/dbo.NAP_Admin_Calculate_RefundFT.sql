/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_RefundFT] 
	@matchid					INT
    ,@IsExcludeBetdaq			BIT = 0
    ,@IsExcludeBetfair			BIT = 0
    ,@IsSettleAbandonedMatchIBC BIT = 0
    ,@fth						SMALLMONEY = 0
    ,@fta						SMALLMONEY = 0
    ,@IsRefundHT				BIT = 0
    ,@IsHTCal					BIT = 0
    ,@strBettypes				VARCHAR(MAX) = NULL
AS
/*  Created by: Kathy
    Date: 20140213
    Task: Refund FT 
    DB: DBTXN/BODB02
    
    Revisions:
        - 20140304@Kathy: Execute settlement for abandoned/postponed matches- Clean Sheet, Both/One/Neither team to score, To Win To Nil 
        - 20140411@Kathy: Add more param for LAS command
        - 20140426@Kathy: Add 1H FGLG, 1H Total Goal (126, 127) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140620@Kathy: Apply BetRadar [Redmine:#17142]
        - 20140728@Kathy: Settle determined tickets for Correct Score(4,30), Total Goal (6,126) [Redmine:#19310]
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]
        - 20140905@Lukas: exclude virtual racing bettype 1231,1232,1233
        - 20140909@Kathy: Exclude virtual racing (bettype 1237, 1238), outright (bettype 10, 31, 32, 33), keno (1501 -> 1599)
        - 20150422@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
        - 20150605@Johnson: Exclude SOLD/BOUGHT/COM tickets from bettrade [Redmine:#35921] 
		- 20150716@Johnson: Exclude range bettypes of Metric Gaming from settlement of SB [Redmine: #37688]
		- 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
        - 20160106@Kathy: Integrate Cricket [Redmine:#49727]
        - 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
        - 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
		- 20160825@Bobby: #62921 - Include FGLG bet types
		- 20160428@Kathy: Exclude Fast Market bettypes [Redmine:#56367]
		- 20170321@Bobby: #73407 - CashOut integration
		- 20180122@Kathy: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
        - 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20211104@Kathy: Upd RepUpdateTime [Redmine:#164184]
		- 20211129@Kathy: New Cashout model [Redmine:#164838]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
    Param's Explanation:
        @IsRefundHT: Indicate whether or not match has been refunded HT
        @IsHTCal: Indicate whether or not match has been calculated HT
                    
    Note: For settlement SPs should hardcode the custid of betdaq customer to avoid replication problem
*/
BEGIN
    SET NOCOUNT ON
    
	DECLARE @ServerName		SYSNAME 
			,@AllowRefund	BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName		= @ServerName
			,@AllowRefund	= @AllowRefund	OUTPUT

		IF @AllowRefund = 0
			RETURN
	END

    DECLARE @xml					XML	

			,@BatchCount			INT
			,@BatchNo				INT
			,@MinCustId				INT
			,@MaxCustId				INT
			,@MinTransId			BIGINT
			,@MaxTransId			BIGINT
			,@TransIdOfMinCust		BIGINT
			,@TransIdOfMaxCust		BIGINT		
			,@IsUpd_Void			BIT = 0
			,@RepUpdateTime			DATETIME2
			,@transInfo	XML
	DECLARE @tmpTransInfo TABLE (transId BIGINT
			,statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
		)
		
	DECLARE @tblBettypes TABLE (bettype SMALLINT, groupId SMALLINT)

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
	
	INSERT INTO @tblBettypes (bettype, groupId)
	SELECT	T.c.value('./@t','SMALLINT')
			,T.c.value('./@g','SMALLINT')
	FROM @xml.nodes('/root/r') AS T(c)
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
					ON b.bettype = t.bettype
			WHERE	b.matchid = @matchid
					AND b.statusID NOT IN (103, 101) 
		)b
		CROSS APPLY (	
			SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
		)n
	)b
	GROUP BY BatchNo, CustId
		
	SELECT @BatchNo = MAX(BatchNo)
	FROM @tmpBatch

	DECLARE @settlementTime DATETIME

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

		SET @settlementTime = GETDATE();
		SET @RepUpdateTime = SYSDATETIME()

		UPDATE	b
			SET 
				@IsUpd_Void = CASE WHEN statusID = 102 THEN 0 ELSE 1 END
				,[status] = CASE 
								WHEN @IsUpd_Void = 0 THEN [status]
								ELSE N'Refund'
							END
				,SettlementTime = CASE 
								WHEN @IsUpd_Void = 0 THEN SettlementTime
								ELSE CASE WHEN winlost <> actual_stake OR statusID <> 103 THEN @settlementTime ELSE SettlementTime END
							END
				,statusID = CASE 
								WHEN @IsUpd_Void = 0 THEN statusID
								ELSE 103
							END
				,ruben = 1
				,winlost = actual_stake
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,statuswinlost = 6
				,RepUpdateTime = CASE WHEN b.statusId = 103 THEN b.RepUpdateTime ELSE @RepUpdateTime END
		OUTPUT	inserted.transid
				,inserted.Status
				,CASE WHEN inserted.SettlementTime <> deleted.SettlementTime THEN inserted.SettlementTime ELSE NULL END
				,inserted.StatusID		
				,inserted.WinLost,inserted.aWinLost,inserted.mWinLost,inserted.sWinLost
				,inserted.PlayerComm,inserted.Comm,inserted.aComm,inserted.sComm
				,inserted.ruben
				,inserted.statuswinlost
			INTO @tmpTransInfo (
				transId
				,Status
				,SettlementTime
				,StatusID
				,WinLost,aWinLost,mWinLost,sWinLost
				,PlayerComm,Comm,aComm,sComm
				,ruben
				,statuswinlost
			)
		FROM	dbo.bettrans b --WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpBatch c
				ON	c.BatchNo = @BatchNo
					AND c.CustId = b.custid
			CROSS APPLY (
				SELECT TOP 1 bettype, groupId
				FROM	@tblBettypes t
				WHERE	b.bettype = t.bettype
			) t
			CROSS APPLY (
					SELECT CASE
								WHEN c.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
								WHEN c.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
								WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
								ELSE 0
							END AS IsCalculated
				)i
		WHERE	matchid = @matchid 
				AND statusID NOT IN (103, 101) 
				AND i.IsCalculated = 1
				AND 1 = CASE 
							WHEN @IsExcludeBetdaq = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 0
							WHEN @IsExcludeBetfair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 0
							WHEN @IsSettleAbandonedMatchIBC = 1 AND (b.custid NOT IN (50057, 879241, 103873, 78761, 851668, 878902, 2331, 1077687, 115770, 15523642) 
								AND b.recommend <> 1688156) AND (b.statusID IN (112, 113) OR (b.statusID = 102 AND b.statuswinlost IN (1,2,3,4)))  
								AND t.groupId IN (2,4,6)
								--AND b.bettype IN (SELECT bettype FROM @tblBettypes WHERE groupId IN (2,4,6))					
								THEN 0
							ELSE 1
						END
				AND ISNULL(b.betdaqid,0) <> -2
		
		IF OBJECT_ID('Service_SideDB_CalculationLog','U') IS NOT NULL 
		BEGIN
			SET @transInfo = (
				SELECT	transId AS '@t'
						,SettlementTime AS '@st' 
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
						,statuswinlost AS '@statuswl' 
				FROM	@tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
			)

			INSERT INTO dbo.Service_SideDB_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
			VALUES ('Settlement', 'CalculateOtherSport', 'bettrans', @MatchId, @transInfo)		
		END

		SET @BatchNo = @BatchNo - 1

		WAITFOR DELAY '00:00:00:050'
	END
END
GO
