/*<info serverAlias="DBBAH-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TicketListing_SettlementHistory] 
(
	 @MatchId	INT
)		
AS
/*	
	Created by: 20221110@Max
	Task: Scale out DBTrans - Enhancement to prevent high latency on Balance Record [Redmine: #180225]
	DB: DBBAH/bodb02
	
	Revisions:	
		- 20221110@Max: Create SP [Redmine: #180225]
		- 20230524@July: Support sport Cricket for all functions [Redmine: #188374]
		- 20240529@July: [TVS] Ticket Listing - Get affected tickets of Result Amendment for Bet Builder and Other Sports [Redmine: #203615]
		- 20240730@July: [TVS] Ticket Listing - Change way to get affected tickets of result amendment [Redmine: #208591]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]
		- 20250724@July: Get Result Amendment for main parlay ticket of matchid input [Redmine: #233478]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @CheckDate		DATETIME
		   ,@RowCount		INT = 0 

	SET @CheckDate = DATEADD(DAY,-2,CAST(GETDATE() AS DATE))

	DECLARE @tmpMatchId TABLE (MatchId INT, Sporttype SMALLINT)

	INSERT INTO @tmpMatchId (MatchId, Sporttype)
	SELECT MatchId, sporttype
	FROM dbo.match WITH(NOLOCK)
	WHERE matchid = @MatchId
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchId WHERE Sporttype IN (50,8)) --Cricket/Baseball
	BEGIN
		INSERT INTO @tmpMatchId (MatchId)
		SELECT MatchId
		FROM dbo.match WITH(NOLOCK)
		WHERE ParentID = @MatchId AND Sporttype IN (50,8)
			AND ISNULL(ChildMatchType,0) = 200
	END

	CREATE TABLE #tblSettlementHistory (
		  TransId BIGINT
		, SettlementType TINYINT
		, CreatedDate DATETIME
		, BalanceChanged MONEY
		, RN_settle INT
	)
	CREATE CLUSTERED INDEX IDX_tblSettlementHistory_TransId ON #tblSettlementHistory (TransId)

	CREATE TABLE #tblResultAmendment (TransId BIGINT PRIMARY KEY)
	
	INSERT INTO #tblResultAmendment (TransId)
	SELECT DISTINCT TransId
	FROM dbo.SettlementHistory WITH(NOLOCK)
	WHERE SettlementType IN (2,3,12,13)
	  AND MatchId = 29 AND CreatedDate >= @CheckDate -- Special case for MatchId Sub

	BEGIN
		INSERT INTO #tblSettlementHistory (TransId, SettlementType, CreatedDate, BalanceChanged, RN_settle)
		SELECT TransId
		    , SettlementType
		    , CreatedDate
		    , BalanceChanged
			, CASE WHEN SettlementType NOT IN (2,3,12) THEN NULL 
			       ELSE ROW_NUMBER() OVER (PARTITION BY TransId ORDER BY CASE WHEN SettlementType NOT IN (2,3,12) THEN 0 ELSE 1 END DESC, CreatedDate DESC) 
			  END AS RN_settle
		FROM dbo.SettlementHistory WITH(NOLOCK) 
		WHERE Matchid IN (SELECT MatchId FROM @tmpMatchId)
		SET @RowCount = @@ROWCOUNT

		INSERT INTO #tblSettlementHistory (TransId, SettlementType, CreatedDate, BalanceChanged, RN_settle)
		SELECT h.TransId
		    , SettlementType
		    , CreatedDate
		    , BalanceChanged
			, CASE WHEN SettlementType NOT IN (2,3,12) THEN NULL  
			       ELSE ROW_NUMBER() OVER (PARTITION BY h.TransId ORDER BY CASE WHEN SettlementType NOT IN (2,3,12) THEN 0 ELSE 1 END DESC, CreatedDate DESC) 
			  END AS RN_settle
		FROM #tblResultAmendment r
			INNER JOIN dbo.SettlementHistory h WITH(NOLOCK) ON r.TransId = h.TransId
		WHERE h.MatchId = 29
		SET @RowCount += @@ROWCOUNT
		
		IF @RowCount <> 0 
		BEGIN 
			;WITH CTE_Repeat AS (
				SELECT TransId, BalanceChanged
						,COUNT(RN_settle) OVER (PARTITION BY TransId ORDER BY CreatedDate DESC) AS Rownumber
				FROM #tblSettlementHistory
			)
			,CTE_Sum AS (
				SELECT TransId, Rownumber
						,SUM(a.BalanceChanged) as Sum_BalanceChanged
				FROM CTE_Repeat a
				GROUP BY TransId, Rownumber
			)
			SELECT DISTINCT sh.TransId
			FROM #tblSettlementHistory sh
				INNER JOIN CTE_Sum c ON sh.TransId = c.TransId AND ISNULL(sh.RN_settle,0) = c.Rownumber --ISNULL for case SettlementType = 13
			WHERE  1 = CASE WHEN sh.SettlementType = 3 THEN 1
							WHEN sh.SettlementType IN (2,12,13) AND c.Sum_BalanceChanged <> 0 THEN 1 
							ELSE 0 END 
		END
	END

	DROP TABLE #tblSettlementHistory
	DROP TABLE #tblResultAmendment

END
