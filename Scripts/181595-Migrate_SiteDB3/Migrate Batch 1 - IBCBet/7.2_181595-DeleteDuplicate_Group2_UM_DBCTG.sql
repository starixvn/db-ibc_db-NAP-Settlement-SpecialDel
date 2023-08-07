/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - table group 2 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--Bettrans 
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Bettrans_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransInfo 
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransInfo_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransLC
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransLC_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransRnG
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransRnG_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--bettransG
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	bettransG_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Translog
	;WITH cteDuplicate
	AS(
		SELECT	translogid	,ROW_NUMBER() OVER(PARTITION BY translogid ORDER BY translogid) as rn 
		FROM	Translog_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Transfer
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Transfer_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Transfer_Coll
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Transfer_Coll_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--TransferInfo
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	TransferInfo_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BetParlayResult
	;WITH cteDuplicate
	AS(
		SELECT	rID	,ROW_NUMBER() OVER(PARTITION BY rID ORDER BY rID) as rn 
		FROM	BetParlayResult_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalNetPosition
	;WITH cteDuplicate
	AS(
		SELECT	CustID, MatchID, Bettype	,ROW_NUMBER() OVER(PARTITION BY CustID, MatchID, Bettype ORDER BY CustID, MatchID, Bettype) as rn 
		FROM	BalNetPosition_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--CashOutSelling
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	CashOutSelling_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--MarkedTransaction
	;WITH cteDuplicate
	AS(
		SELECT	TransId, MatchId	,ROW_NUMBER() OVER(PARTITION BY TransId, MatchId ORDER BY TransId, MatchId) as rn 
		FROM	MarkedTransaction_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--NetPositionCalculationLog
	;WITH cteDuplicate
	AS(
		SELECT	NPCalculationLogID	,ROW_NUMBER() OVER(PARTITION BY NPCalculationLogID ORDER BY NPCalculationLogID) as rn 
		FROM	NetPositionCalculationLog_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--NetPositionTrans
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	NetPositionTrans_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--CustLimitBet_789
	;WITH cteDuplicate
	AS(
		SELECT	Matchid, CustID, EventTypeID	,ROW_NUMBER() OVER(PARTITION BY Matchid, CustID, EventTypeID ORDER BY Matchid, CustID, EventTypeID) as rn 
		FROM	CustLimitBet_789_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--CustLimitBet_MBC
	;WITH cteDuplicate
	AS(
		SELECT	Matchid, CustID, EventTypeID	,ROW_NUMBER() OVER(PARTITION BY Matchid, CustID, EventTypeID ORDER BY Matchid, CustID, EventTypeID) as rn 
		FROM	CustLimitBet_MBC_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

