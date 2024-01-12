/*<info serverAlias="DB05x-bodb02,DB06x-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	-- Correct BetParlayDetail/dbo.BetParlayResult follow DBTRANS
*/


--Run on Replicated Server
USE bodb02
GO

BEGIN
	
	--Input @MatchID OR @Refno_List
	DECLARE @MatchID INT
			,@Refno_List VARCHAR(MAX) = '300003522869'
	
	IF ( ISNULL(@MatchID,0) = 0 AND ISNULL(@Refno_List,'') = '' )
	 OR ( ISNULL(@MatchID,0) > 0 AND ISNULL(@Refno_List,'') <> '' )
	BEGIN
		SELECT 'Input @MatchID OR @Refno_List'
		RETURN
	END
	
	--------------------------------------------------------------
	DROP TABLE IF EXISTS #tmpRefno_List

	CREATE TABLE #tmpRefno_List (TransID BIGINT, RefNo BIGINT)

	IF ISNULL(@MatchID,0) > 0
	BEGIN
		INSERT INTO #tmpRefno_List (TransID, RefNo)
		SELECT DISTINCT bm.TransID, bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
		WHERE bm.matchid = @MatchID
			AND bm.statusID <> 101
	END
	IF ISNULL(@Refno_List,'') <> ''
	BEGIN
		INSERT INTO #tmpRefno_List (TransID, RefNo)
		SELECT DISTINCT bm.TransID, bm.refno
		FROM dbo.bettransm bm WITH(NOLOCK)
			INNER JOIN STRING_SPLIT(@Refno_List, ',') f
				ON f.value = bm.refno
		WHERE bm.statusID <> 101
	END

	----UPDATE/INSERT BetParlayDetail
	BEGIN	
		DROP TABLE IF EXISTS #tmp_DBTrans_BetParlayDetail

		CREATE TABLE #tmp_DBTrans_BetParlayDetail 
		(	RefNo			BIGINT
			,Serial			INT
			,transid		BIGINT
			,winlostdate	SMALLDATETIME
			,statuswinlost	TINYINT
			,statusid		TINYINT
			,matchid		INT
			,bettype		SMALLINT
			,stake			MONEY
			,odds			SMALLMONEY
			,betteam		NVARCHAR(20)
			,hdp1			SMALLMONEY
			,hdp2			SMALLMONEY
			,livehomescore	SMALLINT
			,liveawayscore	SMALLINT
			,liveindicator	BIT
			,betcheck		NVARCHAR(100)
			,transdesc		NVARCHAR(2000) NULL
		)
		INSERT INTO  #tmp_DBTrans_BetParlayDetail 
		(	RefNo
			,Serial
			,transid
			,winlostdate
			,statuswinlost
			,statusid
			,matchid
			,bettype
			,stake
			,odds
			,betteam
			,hdp1
			,hdp2
			,livehomescore
			,liveawayscore
			,liveindicator
			,betcheck
			,transdesc
		)
		SELECT pd.RefNo
			,pd.Serial
			,pd.transid
			,pd.winlostdate
			,pd.statuswinlost
			,pd.statusid
			,pd.matchid
			,pd.bettype
			,pd.stake
			,pd.odds
			,pd.betteam
			,pd.hdp1
			,pd.hdp2
			,pd.livehomescore
			,pd.liveawayscore
			,pd.liveindicator
			,pd.betcheck
			,pd.transdesc
		FROM DBCTG.bodb02.dbo.BetParlayDetail pd WITH(NOLOCK)
		INNER JOIN #tmpRefno_List tmp
			ON pd.RefNo = tmp.RefNo
				AND pd.transid = tmp.TransID
	
		--UPDATE BetParlayDetail at replicated Server, follow DBTRANS
		UPDATE pd
		SET winlostdate 	= tmp.winlostdate
			,statusid 		= tmp.statusid
			,statuswinlost	= tmp.statuswinlost
		FROM dbo.BetParlayDetail pd WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #tmp_DBTrans_BetParlayDetail tmp
				ON pd.RefNo = tmp.RefNo
					AND pd.transid = tmp.transid
					AND pd.Serial = tmp.Serial

		--INSERT BetParlayDetail if NOT existing: Copy data from DBTRANS
		INSERT INTO BetParlayDetail 
		(	RefNo
			,Serial
			,transid
			,winlostdate
			,statuswinlost
			,statusid
			,matchid
			,bettype
			,stake
			,odds
			,betteam
			,hdp1
			,hdp2
			,livehomescore
			,liveawayscore
			,liveindicator
			,betcheck
			,transdesc
		)
		SELECT tmp.RefNo
			,tmp.Serial
			,tmp.transid
			,tmp.winlostdate
			,tmp.statuswinlost
			,tmp.statusid
			,tmp.matchid
			,tmp.bettype
			,tmp.stake
			,tmp.odds
			,tmp.betteam
			,tmp.hdp1
			,tmp.hdp2
			,tmp.livehomescore
			,tmp.liveawayscore
			,tmp.liveindicator
			,tmp.betcheck
			,tmp.transdesc
		FROM #tmp_DBTrans_BetParlayDetail tmp
			LEFT JOIN bodb02.dbo.BetParlayDetail pd WITH(NOLOCK)
				ON pd.RefNo = tmp.RefNo
					AND pd.transid = tmp.TransID
					AND pd.Serial = tmp.Serial
		WHERE pd.transid IS NULL
	END

		
	---BetParlayResult
	BEGIN	
		DROP TABLE IF EXISTS #tmp_DBTrans_BetParlayResult
	
		CREATE TABLE #tmp_DBTrans_BetParlayResult 
		(	RefNo			BIGINT NULL
			,Serial			INT NULL
			,transid		BIGINT NULL
			,winlostdate	SMALLDATETIME NULL
			,statusid		TINYINT NULL
			,stake			MONEY NULL
			,Odds			MONEY NULL
			,mOdds			MONEY NULL
			,winlost		MONEY NULL
			,awinlost		MONEY NULL
			,mwinlost		MONEY NULL
			,swinlost		MONEY NULL
			,playercomm		MONEY NULL
			,comm			MONEY NULL
			,acomm			MONEY NULL
			,scomm			MONEY NULL
			,ExtraValue		MONEY NULL 
		)

		INSERT INTO #tmp_DBTrans_BetParlayResult 
		(	RefNo
			,Serial
			,transid
			,winlostdate
			,statusid
			,stake
			,Odds
			,mOdds
			,winlost
			,awinlost
			,mwinlost
			,swinlost
			,playercomm
			,comm
			,acomm
			,scomm
			,ExtraValue
		)
		SELECT pr.RefNo
			,pr.Serial
			,pr.transid
			,pr.winlostdate
			,pr.statusid
			,pr.stake
			,pr.Odds
			,pr.mOdds
			,pr.winlost
			,pr.awinlost
			,pr.mwinlost
			,pr.swinlost
			,pr.playercomm
			,pr.comm
			,pr.acomm
			,pr.scomm
			,pr.ExtraValue
		FROM DBCTG.bodb02.dbo.BetParlayResult pr WITH(NOLOCK)
			CROSS APPLY (	SELECT TOP 1 tmp.RefNo
							FROM #tmpRefno_List tmp
							WHERE pr.RefNo = tmp.RefNo
						) tmp

		--UPDATE BetParlayResult at Replicated Server, follow DBTRANS
		UPDATE pr
		SET ExtraValue		= tmp.ExtraValue
			,winlostdate	= tmp.winlostdate
			,odds			= tmp.odds
			,winlost		= tmp.winlost
			,awinlost		= tmp.awinlost
			,mwinlost		= tmp.mwinlost
			,swinlost		= tmp.swinlost
			,playercomm		= tmp.playercomm
			,comm			= tmp.comm
			,acomm			= tmp.acomm
			,scomm			= tmp.scomm
		FROM dbo.BetParlayResult pr WITH(ROWLOCK,UPDLOCK)
			INNER JOIN #tmp_DBTrans_BetParlayResult tmp
				ON tmp.RefNo = pr.RefNo
					AND tmp.Serial = pr.Serial

		--INSERT BetParlayResult if NOT existing: Copy data from DBTRANS
		INSERT INTO dbo.BetParlayResult 
		(	RefNo
			,Serial
			,transid
			,winlostdate
			,statusid
			,stake
			,Odds
			,mOdds
			,winlost
			,awinlost
			,mwinlost
			,swinlost
			,playercomm
			,comm
			,acomm
			,scomm
			,ExtraValue
		)
		SELECT tmp.RefNo
			,tmp.Serial
			,tmp.transid
			,tmp.winlostdate
			,tmp.statusid
			,tmp.stake
			,tmp.Odds
			,tmp.mOdds
			,tmp.winlost
			,tmp.awinlost
			,tmp.mwinlost
			,tmp.swinlost
			,tmp.playercomm
			,tmp.comm
			,tmp.acomm
			,tmp.scomm
			,tmp.ExtraValue
		FROM #tmp_DBTrans_BetParlayResult tmp
			LEFT JOIN dbo.BetParlayResult pr WITH(NOLOCK)
				ON tmp.RefNo = pr.RefNo
					AND tmp.Serial = pr.Serial
		WHERE pr.RefNo IS NULL
	END

END