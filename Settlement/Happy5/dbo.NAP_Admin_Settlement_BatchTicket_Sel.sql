/*<info serverAlias="DBCTG-bodb02 , DBSIC-bodb02 , DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_BatchTicket_Sel
	 @MatchId			INT
	,@Sporttype			TINYINT
	,@Resources			VARCHAR(MAX)
	,@Action			VARCHAR(20)		= 'CAL'
	,@IsCentral			BIT				= 0

	,@LastCustId		INT				= 0
	,@LastTransID		BIGINT			= 0
	,@BatchSize			INT				= 2000
	,@BatchTotal		INT				= 5
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBTXN/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]
		- 20240930@Aries: Fix the issue duplicated settlement DBTrans and SiteDBs for HP5  [Redmine:#211434]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @TotalTicket		INT = 0
		   ,@BatchCount			INT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	
	CREATE TABLE #tmpBatchDataByCust(BatchNo SMALLINT,Custid INT, Transid BIGINT,PRIMARY KEY (BatchNo,Custid,Transid))
	CREATE TABLE #tmpBatchData(BatchNo SMALLINT,Custid INT, Transid BIGINT,PRIMARY KEY (BatchNo,Custid,Transid))

	DECLARE @tmpBatchData	TABLE(BatchNo SMALLINT, MinCustId INT, MaxCustId INT, MinCustId_MinTransID BIGINT, MinCustId_MaxTransID BIGINT,MaxCustId_MinTransID BIGINT,MaxCustId_MaxTransID BIGINT)
	DECLARE @tmpBettype		TABLE(BetType SMALLINT  PRIMARY KEY (BetType))

	SET @TotalTicket = @BatchSize*@BatchTotal;

	INSERT INTO @tmpBettype(BetType)
	SELECT DISTINCT p.Bettype
	FROM STRING_SPLIT(@Resources,',') AS r
		INNER JOIN SettlementSpecialBettypeProfile p WITH(NOLOCK) ON r.value = p.ResourceID AND p.sporttype = @Sporttype

	IF @Action LIKE 'CAL%' AND @LastCustId != 0
	BEGIN
		;WITH CTE_Ticket AS (
					SELECT   t1.custid 
							,t1.TransId
							,((ROW_NUMBER() OVER (ORDER BY t1.custid ASC, t1.TransId ASC)- 1)/@BatchSize) + 1  AS BatchNo
					FROM(
							SELECT   TOP(@TotalTicket) WITH TIES
									 b.custid
									,b.TransId
							FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
								CROSS APPLY(SELECT TOP 1 tbt.Bettype FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
							WHERE b.matchid = @MatchId 
								AND b.custid = @LastCustId
								AND b.TransId > @LastTransID
								AND b.statusID NOT IN (101,102)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							ORDER BY b.matchid ASC, b.custid ASC
					) AS t1
	
		)
	    INSERT INTO #tmpBatchDataByCust(BatchNo,custid,transid)
		SELECT BatchNo,custid,transid
		FROM CTE_Ticket
		
		;WITH CTE_Cust AS (
			   SELECT t2.BatchNo
					  ,MIN(t2.custid)  AS MinCustId
					  ,MAX(t2.custid)  AS MaxCustId
				FROM #tmpBatchDataByCust AS t2
				GROUP BY BatchNo
		),
		CTE_CustTrans AS (
			SELECT t2.BatchNo
					,custid
				  ,MIN(t2.TransID)  AS MinTransID
				  ,MAX(t2.TransID)  AS MaxTransID
			FROM #tmpBatchDataByCust AS t2
			GROUP BY BatchNo,custid
		)
		INSERT INTO @tmpBatchData(BatchNo,MinCustId,MaxCustId,MinCustId_MinTransID,MinCustId_MaxTransID,MaxCustId_MinTransID,MaxCustId_MaxTransID)
		SELECT c.BatchNo,c.MinCustId,c.MaxCustId,ct1.MinTransID,ct1.MaxTransID,ct2.MinTransID,ct2.MaxTransID
		FROM CTE_Cust AS c
			CROSS APPLY (SELECT MinTransID,MaxTransID
					FROM CTE_CustTrans as  t1
					WHERE	c.BatchNo = t1.BatchNo
						AND c.MinCustId = t1.custid

			)  AS ct1
			CROSS APPLY (SELECT MinTransID,MaxTransID
					 FROM CTE_CustTrans as  t1
					 WHERE	c.BatchNo = t1.BatchNo
						AND c.MaxCustId = t1.custid
		 )	 AS ct2
		
		SET @BatchCount  = @@ROWCOUNT
		SET @TotalTicket = @BatchSize*(@BatchTotal - @BatchCount);
	END

	IF @Action LIKE 'CAL%' AND @TotalTicket > 0
	BEGIN
		;WITH CTE_Ticket AS (
					SELECT   t1.custid 
							,t1.TransId
							,((ROW_NUMBER() OVER (ORDER BY t1.custid ASC, t1.TransId ASC)- 1)/@BatchSize) + 1  AS BatchNo
					FROM(
							SELECT   TOP(@TotalTicket) WITH TIES
									 b.custid
									,b.TransId
							FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
								CROSS APPLY(SELECT TOP 1 tbt.Bettype FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
							WHERE b.matchid = @MatchId 
								AND b.custid > @LastCustId
								AND b.statusID NOT IN (101,102)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							ORDER BY b.matchid ASC, b.custid ASC
					) AS t1
	
		)
	    INSERT INTO #tmpBatchData(BatchNo,custid,transid)
		SELECT BatchNo + @BatchCount,custid,transid
		FROM CTE_Ticket
		
		;WITH CTE_Cust AS (
			   SELECT t2.BatchNo
					  ,MIN(t2.custid)  AS MinCustId
					  ,MAX(t2.custid)  AS MaxCustId
				FROM #tmpBatchData AS t2
				GROUP BY BatchNo
		),
		CTE_CustTrans AS (
				SELECT t2.BatchNo
						,custid
					  ,MIN(t2.TransID)  AS MinTransID
					  ,MAX(t2.TransID)  AS MaxTransID
				FROM #tmpBatchData AS t2
				GROUP BY BatchNo,custid
		 )
		 INSERT INTO @tmpBatchData(BatchNo,MinCustId,MaxCustId,MinCustId_MinTransID,MinCustId_MaxTransID,MaxCustId_MinTransID,MaxCustId_MaxTransID)
		 SELECT c.BatchNo,c.MinCustId,c.MaxCustId,ct1.MinTransID,ct1.MaxTransID,ct2.MinTransID,ct2.MaxTransID
		 FROM CTE_Cust AS c
			CROSS APPLY (SELECT MinTransID,MaxTransID
						FROM CTE_CustTrans as  t1
						WHERE	c.BatchNo = t1.BatchNo
							AND c.MinCustId = t1.custid

			)  AS ct1
			CROSS APPLY (SELECT MinTransID,MaxTransID
						 FROM CTE_CustTrans as  t1
						 WHERE	c.BatchNo = t1.BatchNo
							AND c.MaxCustId = t1.custid
			) AS ct2

	END

	IF @Action LIKE 'REFUND%'  AND @LastCustId != 0
	BEGIN
		;WITH CTE_Ticket AS (
					SELECT   t1.custid 
							,t1.TransId
							,((ROW_NUMBER() OVER (ORDER BY t1.custid ASC, t1.TransId ASC)- 1)/@BatchSize) + 1  AS BatchNo
					FROM(
							SELECT   TOP(@TotalTicket) WITH TIES
									 b.custid
									,b.TransId
							FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
								CROSS APPLY(SELECT TOP 1 tbt.Bettype FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
							WHERE b.matchid = @MatchId 
								AND b.custid = @LastCustId
								AND b.TransId > @LastTransID
								AND	b.statusID NOT IN (103, 101, 102)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							ORDER BY b.matchid ASC, b.custid ASC
					) AS t1
	
		)
	    INSERT INTO #tmpBatchDataByCust(BatchNo,custid,transid)
		SELECT BatchNo,custid,transid
		FROM CTE_Ticket
		
		;WITH CTE_Cust AS (
			   SELECT t2.BatchNo
					  ,MIN(t2.custid)  AS MinCustId
					  ,MAX(t2.custid)  AS MaxCustId
				FROM #tmpBatchDataByCust AS t2
				GROUP BY BatchNo
		),
		CTE_CustTrans AS (
			SELECT t2.BatchNo
					,custid
				  ,MIN(t2.TransID)  AS MinTransID
				  ,MAX(t2.TransID)  AS MaxTransID
			FROM #tmpBatchDataByCust AS t2
			GROUP BY BatchNo,custid
		)
		INSERT INTO @tmpBatchData(BatchNo,MinCustId,MaxCustId,MinCustId_MinTransID,MinCustId_MaxTransID,MaxCustId_MinTransID,MaxCustId_MaxTransID)
		SELECT c.BatchNo,c.MinCustId,c.MaxCustId,ct1.MinTransID,ct1.MaxTransID,ct2.MinTransID,ct2.MaxTransID
		FROM CTE_Cust AS c
			CROSS APPLY (SELECT MinTransID,MaxTransID
					FROM CTE_CustTrans as  t1
					WHERE	c.BatchNo = t1.BatchNo
						AND c.MinCustId = t1.custid

			)  AS ct1
			CROSS APPLY (SELECT MinTransID,MaxTransID
					 FROM CTE_CustTrans as  t1
					 WHERE	c.BatchNo = t1.BatchNo
						AND c.MaxCustId = t1.custid
		 )	 AS ct2
		
		SET @BatchCount  = @@ROWCOUNT
		SET @TotalTicket = @BatchSize*(@BatchTotal - @BatchCount);
	
	END 

	IF @Action LIKE 'REFUND%'  AND @TotalTicket > 0
	BEGIN
		;WITH CTE_Ticket AS (
					SELECT   t1.custid 
							,t1.TransId
							,((ROW_NUMBER() OVER (ORDER BY t1.custid ASC, t1.TransId ASC)- 1)/@BatchSize) + 1  AS BatchNo
					FROM(
							SELECT   TOP(@TotalTicket) WITH TIES
									 b.custid
									,b.TransId
							FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
								CROSS APPLY(SELECT TOP 1 tbt.Bettype FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
							WHERE b.matchid = @MatchId 
								AND b.custid > @LastCustId
								AND	b.statusID NOT IN (103, 101, 102)
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
							ORDER BY b.matchid ASC, b.custid ASC
					) AS t1
	
		)
	    INSERT INTO #tmpBatchData(BatchNo,custid,transid)
		SELECT BatchNo + @BatchCount,custid,transid
		FROM CTE_Ticket
		
		;WITH CTE_Cust AS (
			   SELECT t2.BatchNo
					  ,MIN(t2.custid)  AS MinCustId
					  ,MAX(t2.custid)  AS MaxCustId
				FROM #tmpBatchData AS t2
				GROUP BY BatchNo
		),
		CTE_CustTrans AS (
			SELECT t2.BatchNo
					,custid
				  ,MIN(t2.TransID)  AS MinTransID
				  ,MAX(t2.TransID)  AS MaxTransID
			FROM #tmpBatchData AS t2
			GROUP BY BatchNo,custid
		)
		INSERT INTO @tmpBatchData(BatchNo,MinCustId,MaxCustId,MinCustId_MinTransID,MinCustId_MaxTransID,MaxCustId_MinTransID,MaxCustId_MaxTransID)
		SELECT c.BatchNo,c.MinCustId,c.MaxCustId,ct1.MinTransID,ct1.MaxTransID,ct2.MinTransID,ct2.MaxTransID
		FROM CTE_Cust AS c
			CROSS APPLY (SELECT MinTransID,MaxTransID
					FROM CTE_CustTrans as  t1
					WHERE	c.BatchNo = t1.BatchNo
						AND c.MinCustId = t1.custid

			)  AS ct1
			CROSS APPLY (SELECT MinTransID,MaxTransID
					 FROM CTE_CustTrans as  t1
					 WHERE	c.BatchNo = t1.BatchNo
						AND c.MaxCustId = t1.custid
		 )	 AS ct2
	END 

	DROP TABLE #tmpBatchData;
	DROP TABLE #tmpBatchDataByCust;

	SELECT BatchNo

		  ,MinCustId
		  ,MinCustId_MinTransID
		  ,MinCustId_MaxTransID

		  ,MaxCustId
		  ,MaxCustId_MinTransID
		  ,MaxCustId_MaxTransID
	FROM @tmpBatchData
	WHERE BatchNo <= @BatchTotal
END
GO
