
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

CREATE TABLE #tmp_bettrans14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('ZFRT152','ZFRT166SW','4300','aws03','MTechCV','Fabbet','GSCFTWCV','Betway'
,'108bet','10BET','12betco','21Cash','28BET','369588vip','396Club','666VIP','67Bet','7Konline'
,'7Kplatfrom','88Goals','99UU','9dianyule','9wSB','9Wsports','ABB688','AK318','Allbetclub','alogeu'
,'Aongroup','Aonslot','Aplus','Apollo','Aragon88','Arlocash','Asia999','AsianBet','Athena000_2','Athena188'
,'Athenaqa','b88club','BananaTech','Baobet','Baolong','BB3','BBIN4','bcr999','BE7TH','Bet2day'
,'BetStar','BlueOcean','BoAPI01','BoAPI02','boapi03','BoAPI05','BoAPI06','BoAPI07','BoAPI08','Bobbet2'
,'Bodog','BoinGroup','BopingAPI0','Boying','bpdemotest','Brown888','Bsdbet','BuyWin','bvl8888','bw6688'
,'Bwinning','Cali','Calibet','Champion','Chris01TXN','Chris02TXN','ChrisTestR','Citibet','Citybk','cl668'
,'CQ11','cx5888','Dabet','dabo88','dafd','Datang','DAYWIN','db5688','Deebet','DELA'
,'demotest01','Diminter','Doctorgame','DTGW','DUOLE','Easywin22','EasywinSW','eb6688','Emmyo','Empire555'
,'ENT22','fg6666','fl5688','fx9888','FYyule','G2Win','Gameroom','gb688','gbkj','GDC'
,'GGBOOK','GGBOOKES','gi6688','gj7777','GOAB88','GOATbet','GooBet','gp1688','GPgaming88','Greenplay'
,'GWinner','Gworld','Haoying','HBO999','Hbobet','HeleThai','HJTK','hl5888','hn555','Holey'
,'Hong88','Hongtu','Hongtubet','HOT88','i228bet','i668bet','IBG','Inbet','Indowin','iuplay1'
,'iuplay2','Jarvis','JGQP8','jinmangguo','Jinyazhou','Jumbo88','Junbet','JZFortune','K8','K8sports'
,'KaiHao','Kasking88','Kbet','KGvip','kh5688','King10','Kraton','ks5555','Kudatogel','Lambo777'
,'lebao8888','Lefu','LEGaming','Leon','Lexibet','LiveBet365','LivebetIDR','LivebetKR','lj9888','LLGAME'
,'LongBao','lwl8888','LZYQ','MarvelDH','May88','Mbet','MFgame','Mgm88','Mirabet','MSbet'
,'mymbet','NEWBALL','Newbet','OBline','Onegaming','Opadmin','OWAPI01','OWAPI02','PCDD','pg5688'
,'Platinum','ReBoTest01','ReBoTest02','ReZeTest01','ReZeTest02','RICbet','Royalebet','RYB95','Salon365','Saloncs'
,'SampleSite2','SampleTest','sbcbet','sbt88','SDYCV','SG8','Sga88','SHABAING','shicaigw','Siamgame'
,'SLC88','Spark','Star99','Starnet','Sunbet138','Swin','Taipanbet','TCL','tcycyl','Test012901'
,'Test012902','test021701','test021702','test021703','test021704','test0624','TGame','THBET','TIC88','Titan365'
,'Tonybet','TooBet','TS','TXG','TYCgame','Tycoon','TYVNZZXL','UN168','UUSS','Uwin18'
,'UwinY','VCasia','VGS','Vietwin88','Wawaapi','Wawabet','WB101','Webet138','WeBet168','wg5688'
,'Win68Club','Winner99','winwin100','WKIBPH','wl5688','WM8888','WPlace','wsd666','Wuming','WUYICP'
,'wx7777','wy6666','Xinli','XINSHNEG','XinYo','XO88','XTD1','XTD2','XTD3','XuanYuan'
,'Yabo3','YHY1980','yq355','ZeAPI01','zeapi02','ZeAPI03','ZF057Celeb','ZF057SQ24','ZF132A','ZFRT069'
,'ZFRT122','ZFRT124','ZFRT125MGT','ZFRT127','ZFRT162','ZFRT193','ZhiFeng046','ZhiFeng071','ZhiFeng076','ZhiFeng083'
,'ZhiFeng178','ZhiFeng180','Bezbet','Ibobet'
)


-------------------DATA PREPARATION --------------------------
-- bettrans14
INSERT INTO #tmp_bettrans14_scaleout (transid)
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

---------------------- param declare to process data -----
DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 1

DECLARE @debug_message VARCHAR(500)

------ 2. bettrans14 - #tmp_bettrans14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans14_scaleout)
BEGIN 
	SET @tablename = 'bettrans14'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettrans14_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK

	END
END


/*
------------ CHECKING DATA AFTER RUN SCRIPT -----------------------
--bettrans
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettrans14
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm14
SELECT transid
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
	
-- bettransLC
SELECT transid
FROM bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransLC14
SELECT transid
FROM bettransLC14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG
SELECT transid
FROM bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG14
SELECT transid
FROM bettransRnG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG
SELECT transid
FROM bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG14
SELECT transid
FROM bettransG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog
SELECT translogid
FROM translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog14
SELECT translogid
FROM translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettrans
SELECT transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettransm
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

*/


