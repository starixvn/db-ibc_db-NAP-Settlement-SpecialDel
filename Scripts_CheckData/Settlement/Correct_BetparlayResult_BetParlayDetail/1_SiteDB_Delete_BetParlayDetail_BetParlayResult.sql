/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	--1: delete BetParlayDetail/BetParlayResult belong to @MatchID
	--2: Ask Keyscore re-settle @MatchID
*/

-- Run on SiteDB only
USE bodb02
GO


BEGIN
	---input matchid
	DECLARE @MatchID INT = 0

	-----------------------------------------------------
	IF OBJECT_ID('tempdb..#tmpRefno') IS NOT NULL
	DROP TABLE #tmpRefno

	CREATE  TABLE #tmpRefno (RefNo BIGINT)

	INSERT INTO #tmpRefno (RefNo)
	SELECT bm.refno
	FROM dbo.bettransm bm WITH(ROWLOCK)
	WHERE bm.matchid = @matchid
		AND statusID <> 101

	DELETE pd
	FROM BetParlayDetail pd
		INNER JOIN #tmpRefno r1
			ON pd.Refno = r1.Refno

	DELETE pdr
	FROM BetParlayResult pdr
		INNER JOIN #tmpRefno r1
			ON pdr.Refno = r1.Refno
END

