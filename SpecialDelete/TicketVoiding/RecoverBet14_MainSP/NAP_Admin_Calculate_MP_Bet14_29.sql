/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_Bet14_29]
	@strXML	VARCHAR(MAX)
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20210315@Kathy: get more combinations from bk range  [Redmine:#148870] 
		
	Param's Explanation:  
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @minRefno BIGINT	
			,@settlementTime DATETIME
			
			,@xml XML
			,@statusId TINYINT
			,@winlost MONEY
			,@winlostdate SMALLDATETIME
			,@currentDate SMALLDATETIME
			
			,@remoteQuery		NVARCHAR(MAX)
			,@strRefno			VARCHAR(4000)
			,@batchNo			INT
			,@id				INT
			
	DECLARE @tmpMissingRefno TABLE (id INT IDENTITY(1,1), refno BIGINT)
		
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
	
	CREATE TABLE #temp_source (transid BIGINT,winlostdate SMALLDATETIME,totalStake MONEY, winlost MONEY,awinlost MONEY,mwinlost MONEY,swinlost MONEY
								,playercomm MONEY,comm MONEY,acomm MONEY,scomm MONEY,ruben TINYINT)
	
	CREATE TABLE #tmpMissingCombination (
		refno				BIGINT
		,serial				INT
		,stake				MONEY
		,winlostdate		SMALLDATETIME
		,statusId			TINYINT
		,mOdds				MONEY
		,winlost			MONEY
		,awinlost			MONEY
		,mwinlost			MONEY
		,swinlost			MONEY
		,playercomm			MONEY
		,comm				MONEY
		,acomm				MONEY
		,scomm				MONEY		
	)
	
	SET @currentDate =  CONVERT(VARCHAR(10),GETDATE(),102)
	
	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno
	
	INSERT INTO @tmpMissingRefno(refno)
	SELECT  DISTINCT r.refno
	FROM	#Refno r
		CROSS APPLY (
			SELECT	COUNT(DISTINCT serial) AS cntDetail
			FROM	dbo.BetParlayDetail bpd WITH(NOLOCK)
			WHERE	r.refno = bpd.RefNo
		) AS bpd
		CROSS APPLY (
			SELECT	COUNT(DISTINCT serial) as cntResult
			FROM	dbo.BetParlayResult bpr WITH(NOLOCK)
			WHERE	r.refno = bpr.RefNo
		) AS bpr
	WHERE bpd.cntDetail > bpr.cntResult
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpMissingRefno) -- there are some combinations had moved on bk, need to get them from archive server
	BEGIN
		SET @id = 1
		SET @batchNo = 100

		WHILE (1=1)
		BEGIN
			SET @strRefno = ''
			SELECT	@strRefno = @strRefno + ',' + CAST(refno AS VARCHAR(30)) 
			FROM	@tmpMissingRefno
			WHERE	id between @id AND @id + @batchNo - 1

			IF ISNULL(@strRefno,'') = ''
				BREAK

			SET @strRefno = STUFF(@strRefno, 1, 1, '')
			
			SET @remoteQuery = 'INSERT INTO #tmpMissingCombination (refno, serial, stake, winlostdate, statusId, mOdds, winlost	,awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm)
								   SELECT refno, serial, stake, winlostdate, statusId, mOdds, winlost	,awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm
								   FROM OPENQUERY (DBARC,''SELECT refno, serial, stake, winlostdate, statusId, mOdds, winlost	,awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm
															FROM bodb_archive.dbo.BetParlayResult with(nolock) where refno in (' + @strRefno  +')'')'
			
			EXECUTE sys.sp_executesql @remoteQuery
			
			SET @id = @id + @batchNo
		END
	END
	
	INSERT INTO #temp_source (transid,winlostdate, totalStake, winlost, awinlost,mwinlost,swinlost,playercomm, comm, acomm, scomm, ruben)
	SELECT transid = b.transid
		,winlostdate = MAX(pr.winlostdate)
		,totalStake = SUM(pr.stake)
		,winlost = SUM(pr.winlost) 
		,awinlost = SUM(pr.awinlost) 
		,mwinlost = SUM(pr.mwinlost) 
		,swinlost = SUM(pr.swinlost) 
		,playercomm = SUM(pr.playercomm) 
		,comm = SUM(pr.comm) 
		,acomm = SUM(pr.acomm) 
		,scomm = SUM(pr.scomm) 			
		,ruben = CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
	FROM #Refno b 
		INNER JOIN 
			(SELECT	pr.winlostdate, pr.stake, pr.winlost, pr.awinlost,pr.mwinlost, pr.swinlost, pr.playercomm, pr.comm, pr.acomm, pr.scomm, pr.statusid, pr.RefNo, pr.Serial
			 FROM	dbo.BetParlayResult pr WITH(NOLOCK)
			 UNION
			 SELECT	t.winlostdate, t.stake, t.winlost, t.awinlost, t.mwinlost, t.swinlost, t.playercomm, t.comm, t.acomm, t.scomm, t.statusid, t.refno, t.serial
			 FROM	#tmpMissingCombination t
		) pr
			ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid
	
	SET @settlementTime = GETDATE();
	
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0
						WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
																WHEN s.winlost = b.actual_stake THEN 111
																WHEN s.winlost > b.actual_stake THEN 112
																WHEN s.winlost < b.actual_stake THEN 113 
															END 
						ELSE CASE
							WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
							WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
							WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
							ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
							END
					END
		,@winlost = s.winlost * s.ruben
		,SettlementTime = CASE WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime ELSE SettlementTime END
		,statusID = @statusId
		,[status] = CASE 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		,winlostdate = CASE WHEN @statusId = 113 AND b.winlostdate > @currentDate THEN @currentDate ELSE b.winlostdate END
		--,actual_stake = s.totalStake
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost =  @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
	FROM dbo.bettrans b
		INNER JOIN #temp_source s ON b.transid = s.transid
	
	UPDATE b WITH(ROWLOCK, UPDLOCK)
		SET @statusId = CASE 
						WHEN s.ruben = 0 THEN 0
						WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
																WHEN s.winlost = b.actual_stake THEN 111
																WHEN s.winlost > b.actual_stake THEN 112
																WHEN s.winlost < b.actual_stake THEN 113 
															END
					ELSE	CASE
							WHEN s.winlost = s.totalStake THEN 111 -- winlost = stake, member DRAW
							WHEN s.winlost > s.totalStake THEN 112 -- winlost > stake, member WIN
							WHEN s.winlost < s.totalStake THEN 113 -- winlost < stake, member LOSE
							ELSE b.statusID -- uncontrollale situation, hope it's not happen in real life
							END
					END
		,@winlost = s.winlost * s.ruben
		,SettlementTime = CASE WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime ELSE SettlementTime END
		,statusID = @statusId
		,[status] = CASE 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		--,actual_stake = s.totalStake 
		,betdaqid = s.totalStake							
		,ruben = s.ruben
		,winlost =   @winlost
		,awinlost = s.awinlost * s.ruben
		,mwinlost = s.mwinlost * s.ruben
		,swinlost = s.swinlost * s.ruben
		,playercomm = s.playercomm * s.ruben
		,comm = s.comm * s.ruben
		,acomm = s.acomm * s.ruben
		,scomm = s.scomm * s.ruben
	FROM dbo.bettrans14 b
		INNER JOIN #temp_source s ON b.transid = s.transid
	
	DROP TABLE #temp_source
	DROP TABLE #Refno
					
END
GO
