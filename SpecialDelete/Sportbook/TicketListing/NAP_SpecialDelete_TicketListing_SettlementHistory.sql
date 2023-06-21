/*<info serverAlias="DBBAH-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
		
	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpMatchId TABLE (MatchId INT)

	INSERT INTO @tmpMatchId (MatchId)
	SELECT MatchId
	FROM dbo.match WITH(NOLOCK)
	WHERE  1 = CASE WHEN sporttype <> 50 AND matchid = @MatchId THEN 1
					WHEN sporttype = 50 AND (matchid = @MatchId OR ParentID = @MatchId) THEN 1
					ELSE 0 END

	CREATE TABLE #tmpAffectTickets (Transid BIGINT PRIMARY KEY)
	CREATE TABLE #tblSettlementHistory (transid BIGINT, winlost MONEY, StatusId TINYINT, SettlementType TINYINT, CreatedDate DATETIME , BalanceChanged MONEY, Rownumber INT, RN_settle INT)
	CREATE CLUSTERED INDEX IDX_tblSettlementHistory_transid ON #tblSettlementHistory (transid)

	IF EXISTS (SELECT TOP 1 1 FROM bodb02.dbo.settlementhistory WITH(NOLOCK) WHERE MatchId IN (SELECT MatchId FROM @tmpMatchId))
	BEGIN
		INSERT INTO #tblSettlementHistory (transid, winlost, StatusId, SettlementType, CreatedDate, BalanceChanged, Rownumber, RN_settle)
		SELECT transid, winlost, StatusId, SettlementType, CreatedDate, BalanceChanged
				, ROW_NUMBER() OVER (PARTITION BY transid ORDER BY CreatedDate DESC) Rownumber
				, CASE WHEN SettlementType <> 0 THEN ROW_NUMBER() OVER (PARTITION BY transid ORDER BY CASE WHEN SettlementType <> 0 THEN 1 ELSE 0 END DESC, CreatedDate DESC) ELSE 0 END AS RN_settle
		FROM bodb02.dbo.settlementhistory WITH(NOLOCK) 
		WHERE Matchid IN (SELECT MatchId FROM @tmpMatchId)

		INSERT INTO #tmpAffectTickets(Transid)
		SELECT bt.transid
		FROM #tblSettlementHistory bt
		OUTER APPLY ( 
			SELECT  bt1.SettlementType, bt1.Rownumber --get settle before
			FROM #tblsettlementhistory bt1 
			WHERE  bt.transid = bt1.transid
					AND bt1.RN_settle = 2 
		)bt1 
		OUTER APPLY ( 
			SELECT  bt2.SettlementType, SUM(bt2.BalanceChanged) sumbalance 
			FROM #tblsettlementhistory bt2
			WHERE  bt.transid = bt2.transid
					AND 1 = CASE WHEN bt1.Rownumber IS NOT NULL AND  bt2.Rownumber > 1 and bt2.Rownumber < bt1.Rownumber THEN 1
								WHEN bt1.Rownumber IS NULL AND bt2.Rownumber > 1 THEN 1
								ELSE 0  
							END
			GROUP BY bt2.SettlementType
		)bt2
		WHERE bt.Rownumber = 1 
		AND 1 = CASE WHEN bt.SettlementType = 3 THEN 1 
						WHEN bt.SettlementType = 2 AND bt.BalanceChanged + bt2.sumbalance <> 0 THEN 1
						ELSE 0
				END
	END

	SELECT t.Transid
	FROM #tmpAffectTickets t

	DROP TABLE #tblSettlementHistory
	DROP TABLE #tmpAffectTickets
END
