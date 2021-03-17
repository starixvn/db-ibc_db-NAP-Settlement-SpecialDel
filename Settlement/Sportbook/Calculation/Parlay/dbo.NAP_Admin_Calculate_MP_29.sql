/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MP_29]
	@matchdate	SMALLDATETIME
	,@strXML	VARCHAR(MAX)
AS
/*
	Created: Kathy
	Date: 20160419
	Task : Settle bettrans (for system parlay)
	DB: DBTXN.bodb02
	
	Original: 

	Revisions:
		- 20160728@Kathy: Using non clustered index PK_bettrans to settle [Redmine:#61193]
		- 20161114@Kathy: Wrongly update winlostdate of parlay running ticket [Redmine#67084]
		- 20190409@Sol: Settlement Time [Redmine:#99638]
		- 20201126@Louisa: God Of Fortune for Parlay [Redmine:#145774]
		- 20210315@Kathy: get combination from betparlaydetail if it moved to bk range  [Redmine:#148870] 

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xml XML
			,@statusId			TINYINT
			,@winlost			MONEY
			,@minRefno			BIGINT	
			,@settlementTime	DATETIME
			,@modds				MONEY
			,@commWinRate		SMALLMONEY
			,@commLostRate		SMALLMONEY

	DECLARE @tmpMissingCombination TABLE (
		MainTransId			BIGINT
		,refno				BIGINT
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

		,comstatus			NVARCHAR(20)
		,oddsspread			MONEY
		,actual_stake		MONEY
		,apositiontaking	SMALLMONEY
		,mpositiontaking	SMALLMONEY
		,spositiontaking	SMALLMONEY
		,playerdiscount		DECIMAL(9,8)
		,discount			DECIMAL(9,8)
		,adiscount			DECIMAL(9,8)
		,sdiscount			DECIMAL(9,8)
	)
		
	CREATE TABLE #Refno (refno BIGINT  PRIMARY KEY, transid BIGINT)
			
	SET @xml = CONVERT(XML, N'<root><r rn="' + REPLACE(REPLACE(@strXML, '|', '" t="'), ',', '"/><r rn="') + '"/></root>')
	
	INSERT INTO #Refno (refno, transid)
	SELECT T.C.value('./@rn', 'bigint')
			,T.C.value('./@t', 'bigint')
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
	
	SELECT @minRefno = MIN(refno)
	FROM #Refno

	SELECT	r.transid AS MainTransId, bpd.RefNo, bpd.Serial
		INTO #totalCombinationInDetail
	FROM	dbo.BetParlayDetail bpd WITH(NOLOCK)
		INNER JOIN #Refno r
			ON bpd.RefNo = r.refno
	GROUP BY r.transid, bpd.RefNo, bpd.Serial

	;WITH cteTotalCombinationInResult
	AS (
		SELECT	bpr.RefNo, bpr.Serial
		FROM	dbo.BetParlayResult bpr WITH(NOLOCK)
		WHERE	EXISTS (SELECT TOP 1 1 FROM #Refno r WHERE r.refno = bpr.RefNo)
	)
	INSERT INTO @tmpMissingCombination (MainTransId, refno, serial)
	SELECT	d.MainTransId, d.RefNo, d.Serial
	FROM	#totalCombinationInDetail d
		LEFT JOIN cteTotalCombinationInResult r
			ON	d.RefNo = r.RefNo
				AND d.Serial = r.Serial
	WHERE	r.RefNo IS NULL
			AND r.Serial IS NULL
	
	IF @@ROWCOUNT > 0 -- there are some combination had moved on bk, need to re-calculate winlost for them instead of getting from archive server
	BEGIN
		UPDATE t 
			SET comstatus = b.comstatus
				,oddsspread = b.oddsspread
				,actual_stake = b.actual_stake
				,apositiontaking = b.apositiontaking
				,mpositiontaking = b.mpositiontaking
				,spositiontaking = b.spositiontaking
				,playerdiscount = b.playerdiscount
				,discount = b.discount
				,adiscount = b.adiscount
				,sdiscount = b.sdiscount
		FROM	@tmpMissingCombination t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON t.MainTransId = b.transid

		;WITH ctedetail AS (
		SELECT pd.refno as refno
			,pd.serial
			,MAX(pd.stake) AS stake
			,SUM(CASE WHEN pd.statusID IN (121, 103) THEN 0 ELSE 1 END) as NoRefund
			,SUM(CASE WHEN pd.statuswinlost = 4	AND pd.statusID <> 102 THEN 1 ELSE 0 END) as loseCnt
			,SUM(CASE WHEN pd.statusID IN (0, 1) THEN 1 ELSE 0 END) as runningCnt
			,MAX(pd.winlostdate) as matchdate_max
			,CAST(dbo.PRODUCT(
				CASE WHEN pd.statusid = 102 THEN 1
					ELSE
						CASE pd.statuswinlost
							WHEN 0 THEN 1 -- draw
							WHEN 1 THEN 1+((pd.odds-1)/2) -- half won
							WHEN 2 THEN pd.odds -- won
							WHEN 3 THEN 0.5 -- half lose
							WHEN 4 THEN 0.000000000001 -- lose
							ELSE 1 -- VOID/REJECT
						END
				END
				) AS MONEY) AS modds
		FROM dbo.BetParlayDetail pd 
			INNER JOIN @tmpMissingCombination bpr 
				ON	pd.refno = bpr.refno
					AND pd.Serial = bpr.Serial
		GROUP BY pd.refno, pd.serial
		)
		UPDATE bpr			
		SET @statusID = statusID = CASE
						WHEN d.loseCnt > 0    THEN 113 -- Lose
						WHEN d.runningCnt > 0 THEN 0   -- running
						WHEN d.NoRefund = 0   THEN 103 -- Refund
						WHEN d.modds < 1      THEN 113 -- Lose
						WHEN d.modds = 1      THEN 111 -- Draw
						ELSE 112 -- Won
					END
			,winlostdate = d.matchdate_max
			,stake = d.stake
			,@modds = d.modds = CASE 
				WHEN d.loseCnt > 0 THEN 0
				WHEN @statusID = 0 THEN 0
				ELSE d.modds
				END
			,@commWinRate = CASE bpr.comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
				WHEN '0' THEN 1
				WHEN '1' THEN 0
				ELSE 1
				END
			,@commLostRate = CASE bpr.comstatus
				WHEN '0' THEN 1
				WHEN '1' THEN 2
				ELSE 1
				END
			,winlost = CASE 
				WHEN loseCnt > 0   THEN 0
				WHEN @statusID = 0 THEN 0
				WHEN  bpr.oddsspread = 1	THEN	CASE 
												WHEN @modds > 1 THEN @modds * bpr.stake + (bpr.actual_stake - bpr.stake)
												WHEN @modds < 1 THEN @modds * bpr.actual_stake
												ELSE bpr.actual_stake
												END
				ELSE ISNULL(bpr.stake * @modds,0)
				END
			,awinlost = CASE 
				WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
															WHEN bpr.oddsspread  = 1 THEN bpr.actual_stake 
																					ELSE bpr.stake
																					END	* apositiontaking

				WHEN @statusID = 112		         THEN - bpr.stake * (@modds - 1) * apositiontaking

				WHEN  @statusID = 113				THEN	CASE
															WHEN  bpr.oddsspread  = 1 THEN - bpr.actual_stake *(@modds - 1)
																					ELSE - bpr.stake * (@modds - 1)
																					END * apositiontaking
				ELSE 0
				END
			,mwinlost = CASE 
				WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
															WHEN bpr.oddsspread  = 1 THEN bpr.actual_stake 
																					ELSE bpr.stake
																					END	* mpositiontaking

				WHEN @statusID = 112		         THEN	- bpr.stake * (@modds - 1) * mpositiontaking

				WHEN  @statusID = 113				THEN	CASE
															WHEN  bpr.oddsspread  = 1 THEN - bpr.actual_stake *(@modds - 1)
																					ELSE - bpr.stake * (@modds - 1)
																					END * mpositiontaking
				ELSE 0
				END
			,swinlost = CASE 
				WHEN @statusID = 113 AND loseCnt > 0 THEN	CASE 
															WHEN bpr.oddsspread  = 1 THEN bpr.actual_stake 
																					ELSE bpr.stake
																					END	* spositiontaking

				WHEN @statusID = 112		         THEN	- bpr.stake * (@modds - 1) * spositiontaking

				WHEN  @statusID = 113				THEN	CASE
															WHEN  bpr.oddsspread  = 1 THEN - bpr.actual_stake *(@modds - 1)
																					ELSE - bpr.stake * (@modds - 1)
																					END * spositiontaking
				ELSE 0
				END
			,playercomm = CASE @statusID
				WHEN 112 THEN @commWinRate  * bpr.stake * bpr.playerdiscount
				WHEN 113 THEN @commLostRate * bpr.stake * bpr.playerdiscount
				ELSE 0
				END
			,comm = CASE @statusID
				WHEN 112 THEN @commWinRate  * bpr.stake * bpr.discount * (1 - bpr.apositiontaking)
				WHEN 113 THEN @commLostRate * bpr.stake * bpr.discount * (1 - bpr.apositiontaking)
				ELSE 0
				END
			,acomm = CASE @statusID
				WHEN 112 THEN @commWinRate  * bpr.stake * bpr.adiscount * (1 - bpr.apositiontaking - bpr.mpositiontaking)
				WHEN 113 THEN @commLostRate * bpr.stake * bpr.adiscount * (1 - bpr.apositiontaking - bpr.mpositiontaking)
				ELSE 0
				END
			,scomm = CASE @statusID
				WHEN 112 THEN @commWinRate  * bpr.stake * bpr.sdiscount * (1 - bpr.apositiontaking - bpr.mpositiontaking - bpr.spositiontaking)
				WHEN 113 THEN @commLostRate * bpr.stake * bpr.sdiscount * (1 - bpr.apositiontaking - bpr.mpositiontaking - bpr.spositiontaking)
				ELSE 0
				END
		FROM	@tmpMissingCombination bpr
			INNER JOIN ctedetail d 
				ON	bpr.refno = d.refno 
					AND bpr.serial = d.serial
	END
	   
	SET @settlementTime = GETDATE();

	;WITH _source AS (
	SELECT transid = b.transid
		,winlostdate = MAX(pr.winlostdate)
		,totalStake = SUM(pr.stake)
		--,modds = SUM(modds) 
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
			(SELECT	pr.winlostdate, pr.stake, pr.winlost, pr.awinlost,pr.mwinlost, pr.swinlost, pr.playercomm, pr.comm, pr.acomm, pr.scomm, pr.statusid, pr.RefNo
			 FROM	dbo.BetParlayResult pr WITH(NOLOCK)
			 UNION ALL
			 SELECT	t.winlostdate, t.stake, t.winlost, t.awinlost, t.mwinlost, t.swinlost, t.playercomm, t.comm, t.acomm, t.scomm, t.statusid, t.refno
			 FROM	@tmpMissingCombination t
		) pr
			ON pr.refno = b.refno
	WHERE pr.RefNo >= @minRefno
	GROUP BY b.refno, b.transid
	)
	UPDATE b WITH(ROWLOCK, UPDLOCK)
	SET @statusId = CASE
					WHEN s.ruben = 0 THEN 0
					WHEN ISNULL(b.oddsspread,0) = 1 THEN	CASE ---GoF
															WHEN s.winlost = b.actual_Stake THEN 111
															WHEN s.winlost > b.actual_Stake THEN 112
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
		,winlostdate = CASE WHEN @statusId <> b.statusID THEN s.winlostdate ELSE b.winlostdate END
		--,modds = s.modds
		---,actual_stake = s.totalStake
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
		INNER JOIN _source s
			ON b.transid = s.transid
END


GO
