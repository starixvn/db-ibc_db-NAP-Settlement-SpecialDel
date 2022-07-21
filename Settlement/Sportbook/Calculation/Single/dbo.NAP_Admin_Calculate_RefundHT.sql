/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_RefundHT] @matchid INT
    ,@IsExcludeBetdaq BIT = 0
    ,@IsExcludeBetfair BIT = 0
    ,@strBettypes VARCHAR(MAX) = NULL
AS
/*    Created by: Kathy
    Date: 20140213
    Task: Refund HT 
    DB: DBTXN/BODB02
    Revisions:
        - 20140426@Kathy: Add 1H total goal (126) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140620@Kathy: Apply BetRadar:
                            - Add 1st Correct Score(151)     
                            - Refund FT bettypes  [Redmine:#17142]
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]        
        - 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]    
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)    
        - 20151016@Kathy: Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626]
        - 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
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
        + @IsExcludeBetdaq: 
            = 1 : Refund Excluding BetDaq
            = 0 : Refund HT including BetDaq 
        + @IsExcludeBetfair: 
            = 1 : Refund Excluding Betfair
            = 0 : Refund HT including Betfair
                
*/
BEGIN
    SET NOCOUNT ON
	
	-- CHECK SERVER BEFORE REFUND
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
	-- END CHECK
	
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
			,modds MONEY, statuswinlost TINYINT,SettlementTime DATETIME
			,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT
		)
		
	DECLARE @tblBettypes TABLE (bettype SMALLINT)

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
	
	INSERT INTO @tblBettypes (bettype)
	SELECT	T.c.value('./@t','SMALLINT')
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

		UPDATE b
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
				,statusID =  CASE 
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
		FROM	dbo.bettrans b --WITH (ROWLOCK, UPDLOCK)
			INNER JOIN @tmpBatch c
				ON	c.BatchNo = @BatchNo
					AND c.CustId = b.custid
			CROSS APPLY (
				SELECT TOP 1 bettype
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
		WHERE	b.matchid = @matchid
				AND b.statusID NOT IN (103, 101)          
				AND i.IsCalculated = 1
				AND 1 = CASE 
							WHEN @IsExcludeBetdaq = 1 AND (b.custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR b.recommend = 1688156) THEN 0
							WHEN @IsExcludeBetfair = 1 AND b.custid IN (2331, 1077687, 115770, 15523642) THEN 0
							ELSE 1
						END
				AND ISNULL(b.betdaqid,0) <> -2

		SET @BatchNo = @BatchNo - 1

		WAITFOR DELAY '00:00:00:050'
	END
END
GO
