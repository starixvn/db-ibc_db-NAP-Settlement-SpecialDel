/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[vndba_sync_data_ComboParlay]
/*
	Created by: Vicky
	Date:20181129
	Task: Sync table  betParlayResult & betParlayDetail from DBTXN to DBACC
	DB: DBACC.BODB02

	Revisions:
		- 20181129@Vicky: move from DB to GIT (Redmine: #95874)
		
*/
AS
BEGIN
	-- Define list of test matchid to sync here
	/*Declare @matchids varchar(MAX)
		
	SET @matchids = '18605221,18683691,18683709'

	Declare @rc int
	-- sync betParlayResult
	SELECT * INTO #x FROM DBTrans.bodb02.dbo.betParlayResult
	WHERE RefNo IN (SELECT refno FROM bettransm WITH (NOLOCK) WHERE matchid in (SELECT val FROM dbo.strSplit(@matchids, ',')))
	*/
	
	----------------------START SYNC BY LEAGUEID----------------------------------
	DECLARE @leagueIds VARCHAR(MAX)
	DECLARE @tblRefNo TABLE (refno BIGINT)
		
	SET @leagueIds = '61914,61915,61916,61917,61918,61919,61939'
	
	INSERT INTO @tblRefNo (refno)
	SELECT DISTINCT refno 
	FROM bettransm WITH (NOLOCK) 
	WHERE matchid in (SELECT matchid 
					  FROM dbo.[match] WITH (NOLOCK)
					  WHERE leagueID IN (SELECT val 
					  					 FROM dbo.strSplit(@leagueIds, ',')
					  					 )
					  )
	----------------------END SYNC BY LEAGUEID----------------------------------
	
	Declare @rc int
	-- sync betParlayResult
	SELECT * INTO #x FROM DBTrans.bodb02.dbo.betParlayResult
	WHERE RefNo IN (SELECT refno 
					FROM @tblRefNo)
	
	
	SET @rc = @@ROWCOUNT

	MERGE dbo.betparlayResult AS t
	USING (
		SELECT
			RefNo, Serial, transid, winlostdate, 
			statusid, stake, odds, mOdds, 
			winlost, awinlost, mwinlost, swinlost, 
			playercomm, comm, acomm, scomm
		FROM #x
		) AS s (
			RefNo, Serial, transid, winlostdate, 
			statusid, stake, odds, mOdds, 
			winlost, awinlost, mwinlost, swinlost, 
			playercomm, comm, acomm, scomm
		)
	ON (
		t.RefNo = s.RefNo
		AND t.Serial = s.Serial
		)
	WHEN MATCHED AND 
	(t.statusID <> s.statusID
	OR t.winlost <> s.winlost
	OR t.playercomm <> s.playercomm)
	THEN
		UPDATE SET 
			t.transid = s.transid,
			t.winlostdate = s.winlostdate,
			t.statusid =s.statusid,
			t.stake = t.stake, 
			t.odds = s.odds, 
			t.mOdds = s.mOdds, 
			t.winlost = s.winlost,
			t.awinlost = s.awinlost,
			t.mwinlost = s.mwinlost,
			t.swinlost = s.swinlost,
			t.playercomm = s.playercomm,
			t.comm = s.comm,
			t.acomm = s.acomm,
			t.scomm = s.scomm
	WHEN NOT MATCHED THEN
		INSERT (
			RefNo, Serial, transid, winlostdate, 
			statusid, stake, odds, mOdds, 
			winlost, awinlost, mwinlost, swinlost, 
			playercomm, comm, acomm, scomm
		)
		VALUES (
			s.RefNo, s.Serial, s.transid, s.winlostdate, 
			s.statusid, s.stake, s.odds, s.mOdds, 
			s.winlost, s.awinlost, s.mwinlost, s.swinlost, 
			s.playercomm, s.comm, s.acomm, s.scomm
		)
	;

	PRINT '     betParlayResult sync ' + CAST(@@ROWCOUNT as varchar(20)) + '/' + CAST(@rc as varchar(20)) + ' rows     '

	DROP TABLE #x

	-- sync betParlayDetail
	SELECT * INTO #y FROM DBTrans.bodb02.dbo.betParlayDetail WITH (NOLOCK) 
	WHERE RefNo IN (SELECT refno 
					FROM @tblRefNo)

	SET @rc = @@ROWCOUNT

	MERGE dbo.betParlayDetail AS t
	USING (
		SELECT
			RefNo, Serial, transid, winlostdate, 
			statuswinlost, statusid, matchid, bettype, stake, odds, 
			betteam, hdp1, hdp2, livehomescore, liveawayscore, liveindicator,
			betcheck, transdesc
		FROM #y
		) AS s (
			RefNo, Serial, transid, winlostdate, 
			statuswinlost, statusid, matchid, bettype, stake, odds, 
			betteam, hdp1, hdp2, livehomescore, liveawayscore, liveindicator,
			betcheck, transdesc
		)
	ON (
		t.RefNo = s.RefNo
		AND t.Serial = s.Serial
		AND t.transid = s.transid
		)
	WHEN MATCHED AND 
	(t.statusID <> s.statusID
	OR t.statuswinlost <> s.statuswinlost
	OR t.winlostdate <> s.winlostdate)
	THEN
		UPDATE SET 
			t.winlostdate = s.winlostdate,
			t.statuswinlost = s.statuswinlost,
			t.statusid = s.statusid,
			t.matchid = s.matchid,
			t.bettype = s.bettype,
			t.stake = t.stake,
			t.odds = s.odds,
			t.betteam = s.betteam,
			t.hdp1 = s.hdp1,
			t.hdp2 = s.hdp2,
			t.livehomescore = s.livehomescore,
			t.liveawayscore = s.liveawayscore,
			t.liveindicator = s.liveindicator,
			t.betcheck = s.betcheck,
			t.transdesc = s.transdesc
	WHEN NOT MATCHED THEN
		INSERT (
			RefNo, Serial, transid, winlostdate, 
			statuswinlost, statusid, matchid, bettype, stake, odds, 
			betteam, hdp1, hdp2, livehomescore, liveawayscore, liveindicator,
			betcheck, transdesc
		)
		VALUES (
			s.RefNo, s.Serial, s.transid, s.winlostdate, 
			s.statuswinlost, s.statusid, s.matchid, s.bettype, s.stake, s.odds,
			s.betteam, s.hdp1, s.hdp2, s.livehomescore, s.liveawayscore, s.liveindicator,
			s.betcheck, s.transdesc
		)
	;

	PRINT '     betParlayDetail sync ' + CAST(@@ROWCOUNT as varchar(20)) + '/' + CAST(@rc as varchar(20)) + ' rows     '

	DROP TABLE #y
 END