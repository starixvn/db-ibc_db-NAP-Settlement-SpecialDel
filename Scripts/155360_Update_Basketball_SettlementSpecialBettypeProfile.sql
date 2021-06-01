/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210524@Louisa
	Task	  : SOP for Basketball [Redmine:#155360]
	DB		  : DBTXN/bodb02

	Revisions:
		20210524@Louisa: Move bettype 605, 617 from Calculate popup to Early popup   [Redmine:#155360]
*/

USE bodb02
GO


	UPDATE sp
	SET  sp.SettleType = 'EAR'
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(ROWLOCK,UPDLOCK)
	WHERE sp.SportType = 2
	AND sp.BetType IN ( 605, 617 )

GO

	IF OBJECT_ID ('tempdb..#tmp613' ) IS NOT NULL
	BEGIN	
		DROP TABLE #tmp613
	END

	CREATE TABLE #tmp613  (RoundID	VARCHAR(10), MaxOrd SMALLINT)

	INSERT INTO #tmp613 (RoundID, MaxOrd)
		 SELECT  DISTINCT  sp.RoundID
				, MAX(sp.OrdNo) OVER(PARTITION BY sp.RoundId) AS MaxOrd
		 FROM SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		 WHERE sp.sporttype = 2
			 AND sp.settletype = 'EAR'
			 AND sp.bettype IN (613)
	  
	
	UPDATE dbo.SettlementSpecialBettypeProfile
	SET  OrdNo = #tmp613.MaxOrd + 1
	FROM dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK)
		INNER JOIN #tmp613  ON sp.RoundID = #tmp613.RoundID
	WHERE sp.sporttype = 2
	AND sp.settletype = 'EAR'
	AND sp.bettype IN (617)

