/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MainParlay14] (@transIds VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		
	Param's Explanation:  
		   
		@transIds = '104730774034,104729373985'
					
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT
			,@SiteDBGroupID		SMALLINT = 0
			,@TransInfo			VARBINARY(MAX) = NULL
			,@MatchId			INT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @xml XML
		    ,@RowNumber			INT	= 1
			,@tmp_TransIds		VARCHAR(MAX)
			,@refnos_29			VARCHAR(MAX)
			,@tmp_MatchId		INT
			,@MatchDate			DATETIME
			,@sqlOpenqueryCommand NVARCHAR(MAX) = ''
			,@strSetting		VARCHAR(MAX)
		   
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)
	
	DECLARE @tblNoResettleTransIds TABLE (transid BIGINT PRIMARY KEY)
	DECLARE @tmpBoostSite TABLE(SiteId INT, srecommend INT, IsDeposit BIT DEFAULT(0))
	DECLARE @tmpBoostSetting TABLE (SiteId INT, OverOdds DECIMAL(9,4), Boost TINYINT)

	DECLARE @tmpTransInfo TABLE(
			  matchid INT, transid BIGINT, status NVARCHAR(10) , statusID TINYINT, ruben TINYINT, modds SMALLMONEY
			, winlost MONEY, aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
			, PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
			, statuswinlost TINYINT, creator INT, ExtraInfo VARCHAR(1000), FcUpdateTime DATETIME2
			, transdate DATETIME, comstatus NVARCHAR(40)
			)

	DECLARE @tmpMatchidInfo TABLE (MatchId INT, IsFinish BIT)

	CREATE TABLE #tblRecoverBet( 
		 transid		BIGINT
		,matchid		INT
		,refno			BIGINT 
		,custid			INT
		,mrecommend		INT
		,recommend		INT
		,isdeposit		BIT
		,winlostdate    SMALLDATETIME
		,ruben			TINYINT
		,SiteID			INT
		,betteam		NVARCHAR(20)
		,oddsspread		MONEY
		,srecommend		INT
	)
	CREATE INDEX IX_RecoverBet ON #tblRecoverBet (refno)
	
	DECLARE @tblMatchIds TABLE ( RowNumber		INT 	IDENTITY (1,1)									
								,matchid		INT
								,eventdate		DATETIME
								,transid		BIGINT
								,refno			BIGINT
								)							
								
		
	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	--Transid list is recovered
	--Transid list is recovered
		INSERT INTO #tblRecoverBet (
					transid
					,matchid
					,refno
					,custid
					,mrecommend
					,recommend
					,isdeposit
					,winlostdate
					,ruben
					,SiteID
					,betteam
					,oddsspread
					,srecommend
		)
		SELECT	b.transid
				,b.matchid
				,b.refno
				,b.custid
				,b.mrecommend
				,b.recommend
				,case when EXISTS (select TOP 1 1 from custDB.dbo.Dep_CustSuper with(nolock) WHERE custid = b.srecommend) then 1 else 0 end AS isdeposit
				,b.winlostdate
				,b.ruben
				,si.siteid
				,b.betteam
				,b.oddsspread
				,b.srecommend
	FROM	@tbl_transIDs s 
		INNER LOOP JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.transid = b.transid
		INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
		INNER JOIN CustDB.dbo.Site si WITH (NOLOCK) ON c.site = si.site
	WHERE b.matchid = 29 AND b.bettype = 29 AND b.statusID = 102
	
	INSERT INTO @tblMatchIds (matchid, eventdate, transid, refno)
	SELECT t.matchid, t.eventdate, t.transid, t.refno
	FROM(
		SELECT	ROW_NUMBER() OVER (PARTITION BY b14.transid ORDER BY m14.eventdate DESC) AS RowNumber
				,bm14.matchid, m14.eventdate,  b14.transid, b14.refno
		FROM	dbo.bettransm14 bm14 WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet b14 ON b14.refno = bm14.refno	
			INNER JOIN dbo.match14 m14 WITH (NOLOCK) ON bm14.matchid = m14.matchid		
	) t
	WHERE	t.RowNumber = 1
	
	-- Reset main to running
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
			,ExtraInfo = dbo.f_SD_SetExtraInfoAbnormalBet(2,'recover',b.ExtraInfo,NULL, b.bettype)
		OUTPUT deleted.matchid, deleted.TransId, inserted.status, inserted.statusID, inserted.ruben, inserted.modds
			, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost
			, inserted.playercomm, inserted.comm, inserted.acomm, inserted.scomm
			, inserted.statuswinlost, inserted.creator, inserted.ExtraInfo
		INTO @tmpTransInfo(matchid, transid, status, statusID, ruben, modds, winlost, aWinLost, mWinLost, sWinLost
							,PlayerComm, Comm, aComm, sComm, statuswinlost, creator, ExtraInfo)
	FROM dbo.bettrans14 b
		INNER JOIN #tblRecoverBet t ON b.transid = t.transid
	WHERE b.SiteDBGroupID = @SiteDBGroupID

	IF @SiteDBGroupID <> 0 AND EXISTS (SELECT TOP 1 1 FROM @tmpTransInfo)
	BEGIN
		INSERT INTO @tmpMatchidInfo (MatchId)
		SELECT DISTINCT MatchId FROM @tmpTransInfo

		WHILE (1=1)
		BEGIN
			UPDATE TOP(1)m
			SET IsFinish = 1, @matchid = MatchId 
			FROM @tmpMatchidInfo m
			WHERE IsFinish IS NULL

			IF @@ROWCOUNT = 0 BREAK;
			SET @TransInfo = COMPRESS((
			SELECT	matchid AS 'mid'
					, transId AS 't'
					, STATUS AS 's'
					, statusID AS 'sid'
					, ruben AS 'r'
					, modds AS 'm'
					, winlost AS 'w'
					, awinlost AS 'aw'
					, mwinlost AS 'mw'
					, swinlost AS 'sw'
					, playercomm AS 'pc'
					, comm AS 'c'
					, acomm AS 'ac'
					, scomm AS 'sc'
					, CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS 'statuswl'
					, creator AS 'cr'
					, ExtraInfo AS 'ex'
					, FcUpdateTime AS 'rut'
			FROM	@tmpTransInfo WHERE matchid = @MatchId 
			FOR JSON PATH))

			INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
			SELECT 'TVS', 'RecoverMainParlay', 'bettrans14', 'U', @MatchId, @TransInfo, 'p'
		END

		DELETE FROM @tmpTransInfo
		DELETE FROM @tmpMatchidInfo
	END

	
	WHILE (1 = 1)
	BEGIN
		SELECT	TOP 1 @tmp_MatchId = matchid
		FROM	@tblMatchIds
		WHERE	RowNumber = @RowNumber
	
		IF @@rowcount = 0
			BREAK		
	
		SET @RowNumber = @RowNumber + 1
	
		SELECT  @MatchDate = eventdate
		FROM	dbo.match14 WITH(NOLOCK)
		WHERE	matchid = @tmp_MatchId

		SELECT @tmp_TransIds = ''
		SELECT  @tmp_TransIds = @tmp_TransIds + CONVERT(VARCHAR(20), transid) + ','
		FROM	@tblMatchIds
		WHERE	matchid = @tmp_MatchId

		SELECT @refnos_29 = ''
		SELECT 	@refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
		FROM	@tblMatchIds
		WHERE	matchid = @tmp_MatchId

		SET @refnos_29 = STUFF(@refnos_29,1,1,'')

		DELETE @tmpBoostSite
		INSERT INTO @tmpBoostSite(SiteId, srecommend )
		SELECT DISTINCT SiteID, srecommend
		FROM	@tblMatchIds t
			INNER JOIN #tblRecoverBet r ON r.transid = t.transid
		WHERE	t.matchid = @tmp_MatchId
			AND r.betteam = '1' -- mix parlay
			AND r.oddsspread = 2 -- offer parlay bonus
			AND NOT EXISTS (SELECT 	TOP 1 1 
								FROM 	dbo.bettransm bm WITH(NOLOCK) 
								WHERE 	t.refno = bm.refno 
										AND ((ISNULL(bm.statuswinlost,0) = 4 AND bm.statusID = 113)
											OR bm.statusId = 0
										)
						) -- lose/running

		UPDATE si 
		SET IsDeposit = 1
		FROM	@tmpBoostSite si
			INNER JOIN CustDB.dbo.Dep_CustSuper d WITH(NOLOCK)
				ON si.srecommend = d.custid
			
		SET @sqlOpenqueryCommand = ''
		SET @sqlOpenqueryCommand = 'SELECT SiteId, OverOdds, Boost FROM OPENQUERY(DBPRO,''SELECT SiteId, OverOdds, Boost FROM bodb02.dbo.ParlayOddsBoostSetting p WITH(NOLOCK) WHERE p.SiteId IN ('
								+ (SELECT  STRING_AGG(CAST(s.SiteID AS VARCHAR(MAX)),',') 
									FROM (
										SELECT SiteId
										FROM (
											SELECT SiteId
											FROM @tmpBoostSite t
											UNION
											SELECT -1
											UNION 
											SELECT -2
										) t
										GROUP BY t.SiteID
									) s 
								)
						+ ')'')'

		DELETE @tmpBoostSetting
		INSERT INTO @tmpBoostSetting(SiteId, OverOdds, Boost)							
		EXEC (@sqlOpenqueryCommand)

		SET @strSetting = ''
		SELECT @strSetting = CAST((
			SELECT	si.SiteId AS 's'
					,(SELECT t.OverOdds AS 'o', t.Boost AS 'b' -- get its own settings
						FROM (SELECT se.SiteId, se.OverOdds, se.Boost
							FROM	@tmpBoostSetting se
							WHERE	EXISTS (SELECT TOP 1 1 FROM	@tmpBoostSite si WHERE se.SiteId = si.SiteId)
							UNION
							SELECT	si.SiteId, se.OverOdds, se.Boost -- If the site ID does not have its own settings, the default value will be taken on default SiteId (-1 if it's credit, -2 if it's licensee)
							FROM	@tmpBoostSite si
								CROSS APPLY (
									SELECT	se.OverOdds, se.Boost
									FROM	@tmpBoostSetting se
									WHERE	se.SiteId = CASE WHEN si.IsDeposit = 1 THEN -2 ELSE -1 END
								) se
							WHERE	NOT EXISTS (SELECT TOP 1 1 FROM @tmpBoostSetting se WHERE si.SiteId = se.SiteId)
						) t
					WHERE si.SiteId = t.SiteId
					FOR JSON AUTO
					) AS v
			FROM	@tmpBoostSite si
			FOR JSON AUTO
		) AS VARCHAR(MAX))
	
		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_PreCal_29 
			 @matchdate = @matchdate
			,@strXML = @tmp_TransIds
			,@strSetting = @strSetting
			,@MatchId = @tmp_MatchId

		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_29
				@strXML	= @refnos_29
				
	END
	
END
GO