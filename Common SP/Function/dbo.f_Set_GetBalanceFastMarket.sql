/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetBalanceFastMarket] (
	@MatchId 			INT
	, @Action			VARCHAR(20)
	, @FMResults		XML
)
RETURNS TABLE
AS
/*	Creator: 20170421@Bobby
	Task: 72789 - Implement bonus system into NAP Settlement
	DB: DBTXN/BODB02
	
	Revisions:
		- 20170421@Bobby: Initial
		- 20200928@Helen: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20210113@Louisa: Support settle determined [Readmine:#147141]
		- 20210406@Kathy: New bettype 229 [Readmine:#152748]
		
	Param's Explanation:
		- @MatchId: ID of match event
		- @Bettypes: List of captured/settled bettype
		- @FMResults: Fast Market results in XM formation
			+ Formation: '<b Id="221">
							<r p="0" r="36" />
							<r p="2" r="1" />
							<r p="2" r="4" />
						</b>
						<b Id="222">
							<r p="1" r="36" />
							<r p="1" r="1" />
							<r p="2" r="4" />
						</b>'
*/
RETURN (
	WITH CTE_FMResultDetail AS 
	(
		SELECT T.C.value('@Id', 'SMALLINT') AS BetType
			, CAST(T.C.value('@Id', 'SMALLINT') * 100 + 1 AS VARCHAR(20)) AS ResourceId
			, X.C.value('@p','TINYINT') AS Position
			, ISNULL(X.C.value('@r','TINYINT'),0) AS BetOption
			, ISNULL(X.C.value('@a','INT'),0) AS AccumulatedScore
			, ISNULL(X.C.value('@s','TINYINT'), 0) AS IsSettleDetermined
			, ISNULL(X.C.value('@i','BIT'), 0) AS HasInjuryTime
		FROM @FMResults.nodes('/r/b') AS T(C)
			CROSS APPLY C.nodes('r') AS X(C)
	), 
	Bettypes AS (
		SELECT DISTINCT f.Bettype
			
			, MAX(rs.Position) AS maxSelectedPosition
				 
			, MAX(CASE WHEN f.BetType = 228 THEN rs.AccumulatedScore ELSE 0 END) AS maxSelectedTotalGoal
			, SUM(CASE WHEN f.BetType = 228 THEN rs.BetOption ELSE 0 END) AS totalChangedScore
			, MAX(CASE WHEN f.BetType = 228 AND rs.IsSettleDetermined = 1 THEN 1 ELSE 0 END) AS IsSettleDetermined
			, MAX(CASE WHEN rs.HasInjuryTime = 1 THEN 1 ELSE 0 END) AS HasInjuryTime
		FROM f_Set_GetGroupBettypes() f
			INNER JOIN CTE_FMResultDetail rs 
			ON f.BetType = rs.BetType
		WHERE f.GroupId = 9 --FastMarket
		GROUP BY f.BetType
	)
	SELECT b.custid
		, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END AS BonusID
		, ISNULL(b.WalletType, 2) AS WalletType -- Cash Wallet as default
		, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		
	FROM dbo.bettrans b WITH (ROWLOCK)
		INNER JOIN Bettypes bt
			ON bt.bettype = b.bettype
		
	WHERE b.matchid	= @matchid	
		AND b.statusID NOT IN (101)
		AND ((EXISTS ( SELECT TOP 1 1 FROM CTE_FMResultDetail rsFM 
						WHERE 1 = CASE
									WHEN bt.HasInjuryTime = 0
										THEN CASE
												WHEN b.hdp1 = rsFM.Position THEN 1
												ELSE 0
											END
									ELSE CASE	
											WHEN rsFM.Position < 45 AND b.hdp1 = rsFM.Position THEN 1
											WHEN rsFM.Position > 45 AND b.hdp1 = rsFM.Position - 1 THEN 1
											ELSE 0
										END
									END)
				AND 1 = CASE
							WHEN b.bettype <> 228 THEN 1
							WHEN @Action = 'REFUND' AND IsSettleDetermined = 0 AND (b.oddsspread + 0.25) < bt.maxSelectedTotalGoal THEN 0
							WHEN @Action = 'UNDO' AND (b.oddsspread + 0.25) < bt.maxSelectedTotalGoal - bt.totalChangedScore THEN 0
							ELSE 1
						END)
			OR (bt.BetType = 228 
				AND 1 = CASE
							WHEN bt.maxSelectedPosition < 45 AND b.hdp1 > bt.maxSelectedPosition THEN 1  -- tickets belong to selected interval
							WHEN bt.maxSelectedPosition >= 45 AND b.hdp1 >= bt.maxSelectedPosition THEN 1
							ELSE 0 
						END
				AND 1 = CASE 
							WHEN @action = 'CAL' AND bt.maxSelectedTotalGoal > (b.oddsspread + 0.25)  THEN 1
							WHEN @action = 'UNDO' AND (b.oddsspread + 0.25) <= bt.maxSelectedTotalGoal AND (b.oddsspread + 0.25) >= bt.maxSelectedTotalGoal - bt.totalChangedScore THEN 1
							ELSE 0
						END
			)
		)
	GROUP BY b.custid
		, CASE WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID ELSE 0 END
		, ISNULL(b.WalletType, 2)
);
GO