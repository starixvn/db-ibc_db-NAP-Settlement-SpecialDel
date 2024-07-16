/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Acc_BettransSelBet_BatchMsg] (
	@TransIds 		VARCHAR(MAX)
	,@ProductIds 	VARCHAR(1000) = ''
	,@GroupName		VARCHAR(20)
) 
AS
/*  
 Created by: Daniel  
 Date:   
 Original: DBA_SelBet_BatchMsg  
 Task: Select batch msg  
 DB: DBACC/BODB02  
  
 Revisions:  
  - 20100823@Khoa: add more @TransIds  
  - 20101007@Henry: Change column transid from INT to BIGINT  
  - 20140224@Elodie: Apply LAS system [Redmine:#10701]  
  - 20150403@Kathy: Support uploading msg for ticket has been moved in bettrans14
  - 20150615@Dominic: Exclude 3 sub-tickets of BetTrade (901,902,903)  
  - 20150625@Dominic: Add ticket from translog/translog14 [Redmine:#38200]  
  - 20160317@bobby.nguyen: #54218 - Upload bacth message enhancement
  - 20160317@bobby.nguyen: #57700 - Add Macau Game product
  - 20160817@bobby.nguyen: #62572 - Exclude BT's bettype 904
  - 20161013@Kathy: Add NG2 [Redmine:#63211]
  - 20170309@Kent: Integrate Cash-out [Redmine:#72059]
  - 20190228@Alan: Implement Bet Builder - [106898]
  - 20220909@July: Change function STRING_SPLIT & remove code Metric Gaming [Redmine: #175412]
  - 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
  - 20240715@July: HotFix - Cannot upload message for SA Gaming [Redmine: #207967]
  
Explanation's Param:  
	- @ProductIds: [1-99]
		+ 1002: Bet Builder
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @invalidTransId 	VARCHAR(MAX)
		,@balanUpDate			SMALLDATETIME
		,@BetBuilder_ProductId	INT = 1002

	CREATE TABLE #transIdList 	( transid 	BIGINT)
	CREATE TABLE #productIdList ( ProductId INT)

	CREATE TABLE #productBettype (
		[ProductID]		INT
		,[Bettype]		SMALLINT
		,[SubProduct]	VARCHAR(500)
	)
	
	CREATE TABLE #BetDelete  (
		transid BIGINT
		, refno BIGINT
		, bettype SMALLINT
		, custid INT
		, recommend INT
		, mrecommend INT
		, srecommend INT
		, betfrom NVARCHAR(4)
	
	)
	
	-- set balanUpDate
	SELECT @balanUpDate = MIN(winlostdate)
	FROM dbo.bettrans14 WITH(NOLOCK)
	
	-- insert trans Id list
	INSERT INTO #transIdList(transid)
	SELECT DISTINCT (CONVERT(BIGINT, value))
	FROM STRING_SPLIT(@TransIds, ',')
	
	--Insert product list
	INSERT INTO #productIdList(ProductId)
	SELECT DISTINCT (CONVERT(INT, value))
	FROM STRING_SPLIT(@ProductIds, ',')
		
	-- Gather BettypeMatrix
	INSERT INTO #productBettype (ProductId, Bettype, SubProduct)
	SELECT DISTINCT p.ProductId, sb.Bettype, sb.SubProduct
	FROM dbo.SportBettypeMatrix sb (NOLOCK)
		INNER JOIN #productIdList p ON sb.ProductId = p.ProductId		
	WHERE sb.SubProduct NOT IN ('MG-SuperLive') 
		AND sb.Bettype 	NOT IN (500, 38)
	
	-- Check Bet Builder
	IF(EXISTS (SELECT 1 FROM #productIdList WHERE ProductId = @BetBuilder_ProductId))
	BEGIN
		INSERT INTO #productBettype (ProductId, Bettype, SubProduct)
		SELECT DISTINCT @BetBuilder_ProductId AS ProductId, sb.Bettype, sb.SubProduct
		FROM dbo.SportBettypeMatrix sb (NOLOCK)
		WHERE sb.Bettype = 38 	
	END
	-- search by group 1
	/*	
		- SB: ProductId = 1
		- NG: ProductId = 3
		- LC: ProductId = 4
		- VS: ProductId = 5
	*/
	IF @GroupName = 'Group 1'
	BEGIN
		INSERT INTO #BetDelete (
			transid
			, refno
			, bettype
			, custid
			, recommend
			, mrecommend
			, srecommend
			, betfrom
		)
		SELECT 
			b.transid
			, b.refno
			, b.bettype
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.transid = t.transid
			INNER JOIN #productBettype bt ON b.bettype = bt.bettype			   
			
		UNION ALL 
		SELECT 
			b.transid
			, b.refno
			, b.bettype
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM bettrans14 b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.transid = t.transid
			INNER JOIN #productBettype bt ON b.bettype = bt.bettype			   
	END
	-- search by group 2
	/*	
		- KN: ProductId = 8
		- GD: ProductId = 12
		- MGCLC: ProductId = 13
		- CB: ProductId = 15
		- CK: ProductId = 19
		- SB-MG: ProductId = 1 - SubProduct = 'MG-SuperLive'
	*/
	IF @GroupName = 'Group 2'
	BEGIN
		INSERT INTO #BetDelete (
			transid
			, refno
			, bettype
			, custid
			, recommend
			, mrecommend
			, srecommend
			, betfrom
		)
		SELECT b.translogid
			, b.translogid
			, b.gameid
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.translogid = t.transid
			INNER JOIN #productBettype bt ON b.gameid = bt.bettype
			
		UNION ALL 
		SELECT b.translogid
			, b.translogid
			, b.gameid
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM dbo.translog14 AS b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.translogid = t.transid
			INNER JOIN #productBettype bt ON b.gameid = bt.bettype
		WHERE b.winlostdate >= @balanUpDate		
	END	
	-- search by group 3
	/*	
		- AGC: ProductId = 11
		- AB: ProductId = 21
	*/
	IF @GroupName = 'Group 3'
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #productIdList WHERE ProductId = 39) --SA Gaming
		BEGIN
			INSERT INTO #BetDelete (
				transid
				, refno
				, bettype
				, custid
				, recommend
				, mrecommend
				, srecommend
				, betfrom
			)
			SELECT t.transid
				, b.RefNo
				, b.gameid
				, b.custid
				, b.recommend
				, b.mrecommend
				, b.srecommend
				, b.betfrom
			FROM #transIdList t 
				INNER JOIN dbo.bettransG btg WITH (NOLOCK) ON t.transId = btg.transid  
				INNER JOIN dbo.bettransLC b WITH (NOLOCK) ON btg.refno = b.transId
				INNER JOIN #productBettype bt ON b.gameid = bt.bettype
			
			UNION ALL
			SELECT t.transid
				, b.RefNo
				, b.gameid
				, b.custid
				, b.recommend
				, b.mrecommend
				, b.srecommend
				, b.betfrom
			FROM #transIdList t 
				INNER JOIN dbo.bettransG14 btg WITH (NOLOCK) ON t.transId = btg.transid  
				INNER JOIN dbo.bettransLC14 b WITH (NOLOCK) ON btg.refno = b.transId
				INNER JOIN #productBettype bt ON b.gameid = bt.bettype
			WHERE b.winlostdate  >= @balanUpDate
		END
		IF EXISTS (SELECT TOP 1 1 FROM #productIdList WHERE ProductId <> 39) 
		BEGIN
			INSERT INTO #BetDelete (
				transid
				, refno
				, bettype
				, custid
				, recommend
				, mrecommend
				, srecommend
				, betfrom
			)
			SELECT b.transid
				, b.RefNo
				, b.gameid
				, b.custid
				, b.recommend
				, b.mrecommend
				, b.srecommend
				, b.betfrom
			FROM dbo.bettransLC b WITH (NOLOCK)
				INNER JOIN #transIdList t ON b.transid = t.transid
				INNER JOIN #productBettype bt ON b.gameid = bt.bettype
			
			UNION ALL
			SELECT b.transid
				, b.RefNo
				, b.gameid
				, b.custid
				, b.recommend
				, b.mrecommend
				, b.srecommend
				, b.betfrom
			FROM dbo.bettransLC14 b WITH (NOLOCK)
				INNER JOIN #transIdList t ON b.transid = t.transid
				INNER JOIN #productBettype bt ON b.gameid = bt.bettype			
			WHERE b.winlostdate  >= @balanUpDate
		END
	END
	
	-- search by group 4
	/*	
		- CS: ProductId = 6
		- MGCRNG: ProductId = 17
		- VB: ProductId = 22
	*/
	IF @GroupName = 'Group 4'
	BEGIN
		INSERT INTO #BetDelete (
			transid
			, refno
			, bettype
			, custid
			, recommend
			, mrecommend
			, srecommend
			, betfrom
		)
			
		SELECT b.transid
			, b.RefNo
			, b.gameid
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM dbo.bettransRNG b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.transid = t.transid
			INNER JOIN #productBettype bt ON b.gameid = bt.bettype
	
		UNION ALL
		SELECT b.transid
			, b.RefNo
			, b.gameid
			, b.custid
			, b.recommend
			, b.mrecommend
			, b.srecommend
			, b.betfrom
		FROM dbo.bettransRNG14 b WITH (NOLOCK)
			INNER JOIN #transIdList t ON b.transid = t.transid
			INNER JOIN #productBettype bt ON b.gameid = bt.bettype			
		WHERE b.winlostdate >= @balanUpDate
	END
	
	;WITH CTE_CustInfo AS 
	(
		SELECT DISTINCT ct.custid, ci.username
		FROM #BetDelete bd
			CROSS APPLY (
				VALUES(custid)
				,(recommend)
				,(mrecommend)
				,(srecommend)
			) ct (custid)
			INNER JOIN dbo.custinfo ci WITH(NOLOCK) ON ct.custid = ci.custid
	)
	SELECT bd.transid
		, bd.custid
		, mem.UserName AS CustUserName
		, bd.recommend
		, ag.UserName AS AgUserName
		, bd.mrecommend
		, mag.UserName AS MagUserName
		, bd.srecommend
		, sag.Username AS SagUserName
	FROM #BetDelete bd
		INNER JOIN CTE_CustInfo mem ON bd.custid = mem.custid
		INNER JOIN CTE_CustInfo ag ON bd.recommend = ag.custid
		INNER JOIN CTE_CustInfo mag ON bd.mrecommend = mag.custid
		INNER JOIN CTE_CustInfo sag ON bd.srecommend = sag.custid
	
	--Gte invalid transids
	SELECT @invalidTransId = COALESCE(@invalidTransId + '^', '') + CAST(b.transid AS VARCHAR(20))
	FROM #transIdList b
		LEFT JOIN #BetDelete bd ON b.transid = bd.transid
	WHERE bd.transid IS NULL

	SELECT @invalidTransId AS InvalidTransID
	
	RETURN
END
