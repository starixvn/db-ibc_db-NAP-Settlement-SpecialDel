/*<info serverAlias="DBTXN-bodb02" executers="vnSAS" isFunction="0"></info>*/
CREATE PROC Task_LuckyDraw3rd_Freebets_Insert
AS
/*
	Created: Helen
	Date: 20210319
	Task: Deposit - Saba.Club - Free Bets [Redmine: #142369]
	DB: DBTRANS/bodb02
	
	Revisions:
		- 20210319@Helen: Deposit - Saba.Club - Free Bets [Redmine: #142369]
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @RoundID INT 
			, @Sporttype TINYINT 
			, @winlostdate DATETIME 
			, @IsTicket14 BIT = 0

	CREATE TABLE #testAccount (username VARCHAR(30),FreeSpinCount INT )			
	-- Input param value here
	SELECT  @Sporttype = 150
	
	SET @winlostdate = CONVERT(date, getdate()-1)
	SELECT DATENAME(dw,@winlostdate)

	IF DATENAME(dw,@winlostdate) = 'Saturday'
	BEGIN
						
		CREATE TABLE #temp_result (CustID INT, srecommend INT, mrecommend INT,recommend INT, NetWinLoss MONEY)
				
		SET @RoundID = 1 + ISNULL((SELECT MAX(roundID) 
							FROM dbo.LuckyDraw3rd WITH (NOLOCK) 
							WHERE sporttype = @Sporttype
							),0) 
		
		INSERT INTO #temp_result (CustID, srecommend, mrecommend, recommend, NetWinLoss)
		SELECT b.custid
			,b.srecommend,b.mrecommend,b.recommend
			,SUM (winlost - actual_stake) NetWinLoss
		FROM bettrans b WITH (NOLOCK) 
			INNER JOIN dbo.match m WITH (NOLOCK) ON b.matchid = m.matchid 
			INNER  JOIN dbo.league l WITH (NOLOCK) ON m.leagueID = l.leagueID 
			INNER JOIN CustDB.dbo.Customer c (NOLOCK) ON b.recommend = c.custid AND c.site IN ('11Bet','12Bet','Fabet','Five88','Lucky88','One88','zbet','Sunwin','Debet','Red88','Zowin','SV88','Nbet','OXbet','Sky88','Mansion88','N8B','N8G')
			INNER JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK) ON s.custid = b.srecommend
		WHERE m.sporttype IN (1,2,50) 
			AND eventstatus = 'completed'
			AND b.statusID IN (111,112,113)
			AND b.bettype < 19999
			AND b.bettype NOT IN (29)
			AND l.LeagueGroupID IN (42,74,108)
			AND l.isTest = 0
			AND b.currency = 51
			AND b.winlostdate = @winlostdate
			AND 1 = CASE WHEN m.sporttype = 1 AND l.leaguegroupid in (42, 74, 108) THEN 1
						 WHEN m.sporttype = 2 AND l.leaguegroupid = 42 THEN 1
						 WHEN m.sporttype = 50 AND l.leaguegroupid = 42 THEN 1
						 ELSE 0
					END	 
		GROUP BY b.custid,b.srecommend,b.mrecommend,b.recommend				
		
		IF EXISTS (SELECT TOP (1) 1 FROM #temp_result WHERE NetWinLoss < 0 )
		BEGIN				
			INSERT INTO LuckyDraw3rd (Sporttype, RoundID, CustID, FreeSpinCount, CreatedDate, SentDate, ShowBannerEndDate, StatusId, srecommend, mrecommend, recommend, NetWinLoss)
			SELECT @Sporttype Sporttype
				, @RoundID AS RoundID
				,custid
				,CASE 
					WHEN ABS(NetWinLoss) >= 500 AND ABS(NetWinLoss) < 1000 THEN 2
					WHEN ABS(NetWinLoss) >= 1000 AND ABS(NetWinLoss) < 5000 THEN 4
					WHEN ABS(NetWinLoss) >= 5000 AND ABS(NetWinLoss) < 8000 THEN 6
					WHEN ABS(NetWinLoss) >= 8000 AND ABS(NetWinLoss) < 10000 THEN 8
					WHEN ABS(NetWinLoss) >= 10000 THEN 10
				END AS FreeSpinCount
				,GETDATE() CreatedDate
				,NULL SentDate
				,NULL ShowBannerEndDate
				,0 StatusId
				,srecommend,mrecommend,recommend
				,NetWinLoss
			FROM #temp_result 
			WHERE NetWinLoss < 0 AND ABS(NetWinLoss) >= 500
		END

		INSERT INTO #testAccount (username,FreeSpinCount)
		VALUES ('Athena000UUS011904463',20),
			('Athena000UUS011904464',20),
			('Athena000UUS011904465',20),
			('Athena000UUS011904466',20),
			('Athena000UUS011904467',20),
			('Athena000UUS011904468',20),
			('Athena000UUS011904469',20),
			('Athena000UUS011904470',20),
			('Athena000UUS011904471',20),
			('Athena000UUS011904472',20),
			('Athena000UUS011904473',20),
			('Athena000UUS011904474',20),
			('Athena000UUS011904475',20),
			('Athena000UUS011904476',20),
			('Athena000UUS011904477',20),
			('Athena000UUS011904478',20),
			('Athena000UUS011904479',20),
			('Athena000UUS011904480',20),
			('Athena000UUS011904520',20),
			('Athena000UUS011904521',20),
			---20210312 Test N8B-----
			('N8BUUS01098',20),
			('N8BUUS01099',20)

		INSERT INTO dbo.LuckyDraw3rd (Sporttype, RoundID, CustID, FreeSpinCount, CreatedDate, SentDate, ShowBannerEndDate, StatusId, srecommend, mrecommend, recommend, NetWinLoss)
		SELECT @Sporttype Sporttype
			, @RoundID AS RoundID
			,c.custid
			,s.FreeSpinCount FreeSpinCount
			,GETDATE() CreatedDate
			,NULL SentDate
			,NULL ShowBannerEndDate
			,0 StatusId
			,c.srecommend,c.mrecommend,c.recommend
			,-1000000
		FROM #testAccount s 
			INNER JOIN custdb.dbo.Customer c WITH (NOLOCK) ON s.username = c.username
	
		INSERT INTO dbo.LuckyDraw3rd_Log (sporttype, RoundID, CreatedDate)
		SELECT 150,@RoundID,GETDATE()
		
	END
	
	DROP TABLE #temp_result
	DROP TABLE #testAccount
	
END