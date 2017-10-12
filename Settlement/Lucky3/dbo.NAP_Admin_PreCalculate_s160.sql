/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_PreCalculate_s160
	@MatchId				INT
	,@Mode					VARCHAR(20)
	,@Action				VARCHAR(20) 	= NULL
	,@FirstBall				TINYINT 		= NULL
	,@SecondBall			TINYINT 		= NULL
	,@ThirdBall				TINYINT 		= NULL
	,@FirstPrizeMaxCount	TINYINT 		= NULL
	,@PrizeSettingId		INT 			= NULL
	,@strCustSetting		VARCHAR(MAX) 	= NULL
	,@strVoidedTransId		VARCHAR(MAX)	= NULL
AS
/*
	Created by: Kathy
	Date: 20170426
	Task: Lucky 3 - Settlement 
	DB: DBTXN/DBAGE/DBEXT/DBACC.BODB02
	
	Revisions:	
		- 20170426@Kathy: Lucky 3 - Settlement  [Redmine:#77170]
		
	Param's Explanation:	
		@Mode:	preCAL/CAL
		@Action: CAL/REFUND/UNDO/VOID
		
*/
BEGIN
	SET NOCOUNT ON
					
	DECLARE	@StatusId		TINYINT
			,@PrizeAmount	MONEY
			,@strCustId		VARCHAR(MAX) = ''
			,@NumberOfFirstPrize INT
			
	CREATE TABLE #tmpBettrans (
		MatchId				INT
		,TransId			BIGINT
		,CustId				INT
		,Stake				MONEY
		,betid				BIGINT -- Combination
		,livehomescore		SMALLINT -- BallCount
		,odds				SMALLMONEY -- Multipy
		,hdp1				SMALLMONEY -- UnitCost
		,Currency			TINYINT
		,PlayerDiscount		DECIMAL(9,8)
		,Discount			DECIMAL(9,8)
		,aDiscount			DECIMAL(9,8)
		,sDiscount			DECIMAL(9,8)
		,aPositionTaking	SMALLMONEY
		,mPositionTaking	SMALLMONEY
		,sPositionTaking	SMALLMONEY
		,FirstBall			VARCHAR(2)
		,SecondBall			VARCHAR(2)
		,ThirdBall			VARCHAR(2)
		,HitCount			TINYINT
		,WinlostDate		SMALLDATETIME
	)
	
	CREATE TABLE #tmpVoidedTransId (TransId BIGINT)
	DECLARE @xmlVoidedTransId XML
	
	IF @Mode = 'preCAL'
	BEGIN
		IF @Action IN ('REFUND', 'UNDO', 'CAL')
		BEGIN
			WHILE (1 = 1)
			BEGIN
				DELETE	TOP (1000)
				FROM	dbo.BetLucky3Result WITH (ROWLOCK, UPDLOCK)
				WHERE	MatchId = @MatchId
				
				IF @@rowcount < 1000
					BREAK
			END
		END
		
		IF @Action = 'VOID'
		BEGIN
			SET @xmlVoidedTransId = CAST((REPLACE('<root><r t="' + @strVoidedTransId + '"/></root>', ',','"/><r t="')) AS XML)
			
			INSERT INTO #tmpVoidedTransId (TransId)
			SELECT T.c.value('./@t','BIGINT')
			FROM @xmlVoidedTransId.nodes('/root/r') AS T(c)
			OPTION ( OPTIMIZE FOR ( @xmlVoidedTransId = NULL ) )	
			
			WHILE (1 = 1)
			BEGIN
				DELETE	TOP (1000) b
				FROM	dbo.BetLucky3Result b WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #tmpVoidedTransId t
						ON b.TransId = t.TransId				
				
				IF @@rowcount < 1000
					BREAK
			END
		END
	
		IF @Action = 'CAL'
		BEGIN
			INSERT INTO #tmpBettrans (
				MatchId
				,TransId
				,CustId
				,Stake
				,betid
				,livehomescore
				,odds
				,hdp1
				,Currency
				,PlayerDiscount
				,Discount
				,aDiscount
				,sDiscount
				,aPositionTaking
				,mPositionTaking
				,sPositionTaking
				,FirstBall
				,SecondBall
				,ThirdBall
				,HitCount
				,WinlostDate
			)
			SELECT	matchid
					,transid
					,custid
					,stake
					,betid
					,livehomescore
					,odds
					,hdp1
					,currency
					,playerdiscount
					,discount
					,adiscount
					,sdiscount
					,apositiontaking
					,mpositiontaking
					,spositiontaking
					,RIGHT('0' + CAST(f.FirstBall AS VARCHAR),2) AS FirstBall -- add '0' in front of number 1->9
					,RIGHT('0' + CAST(s.SecondBall AS VARCHAR),2) AS SecondBall -- add '0' in front of number 1->9
					,RIGHT('0' + CAST(t.ThirdBall AS VARCHAR),2) AS ThirdBall -- add '0' in front of number 1->9
					,CASE
						WHEN t.ThirdBall > 0 THEN 3
						ELSE CASE
								WHEN s.SecondBall > 0 THEN 2
								ELSE CASE
										WHEN f.FirstBall > 0 THEN 1
										ELSE 0
									END
							END
					END AS HitCount	
					,b.winlostdate	
			FROM	dbo.bettrans b WITH(ROWLOCK)		
				CROSS APPLY (
					SELECT  REPLACE(REPLACE(','+ b.transdesc + ',',' ',''),',0',',') transdesc -- remove space between numbers, remove 0 in front of 1 --> 9
							,',' + CAST(@FirstBall AS VARCHAR) + ',' AS FirstBall
							,',' + CAST(@SecondBall AS VARCHAR) + ',' AS SecondBall
							,',' + CAST(@ThirdBall AS VARCHAR) + ',' AS ThirdBall
				) result 
				CROSS APPLY (
					SELECT CASE 
								WHEN CHARINDEX(result.FirstBall, result.transdesc) > 0 THEN @FirstBall
								WHEN CHARINDEX(result.SecondBall, result.transdesc) > 0 THEN @SecondBall
								WHEN CHARINDEX(result.ThirdBall, result.transdesc) > 0 THEN @ThirdBall
								ELSE 0
							END AS FirstBall
				) f
				CROSS APPLY (
					SELECT CASE 
								WHEN f.FirstBall = @FirstBall 
									THEN CASE
											WHEN CHARINDEX(result.SecondBall, result.transdesc) > 0 THEN @SecondBall
											WHEN CHARINDEX(result.ThirdBall, result.transdesc) > 0 THEN @ThirdBall
											ELSE 0
										END
								WHEN f.FirstBall = @SecondBall 
									THEN CASE
											WHEN CHARINDEX(result.ThirdBall, result.transdesc) > 0 THEN @ThirdBall
											ELSE 0
										END
								ELSE 0
							END AS SecondBall
				) s
				CROSS APPLY (
					SELECT CASE
								WHEN s.SecondBall = @SecondBall 
									THEN CASE
											WHEN CHARINDEX(result.ThirdBall, result.transdesc) > 0 THEN @ThirdBall
											ELSE 0
										END
								ELSE 0
							END AS ThirdBall
				)t
			WHERE	matchid = @MatchId
					AND bettype = 1600
					AND b.statusID NOT IN (101, 102) -- REJECT, VOID	
			
			INSERT INTO dbo.BetLucky3Result (
				MatchId
				,TransId
				,CustId
				,Bettype
				,Currency
				,Hdp1
				,Odds
				,StatusId
				,Hits
				,Prize
				,aPositionTaking
				,mPositionTaking
				,sPositionTaking
				,PlayerDiscount
				,Discount
				,aDiscount
				,sDiscount
				,TransDesc
				,WinlostDate
			)
			SELECT	t.MatchId
					,t.TransId
					,t.CustId
					,1601 AS Bettype
					,t.Currency
					,t.hdp1
					,t.odds
					,0 AS StatusId
					,(CASE
						WHEN r.Prize = 1 THEN i.cntFirstPrize
						WHEN r.Prize = 2 THEN i.cntSecondPrize
						WHEN r.Prize = 3 THEN i.cntThirdPrize
						ELSE i.cntLosing
					END) / r.NumberOfRow AS Hits
					,r.Prize
					,t.aPositionTaking
					,t.mPositionTaking
					,t.sPositionTaking
					,t.PlayerDiscount
					,t.Discount
					,t.aDiscount
					,t.sDiscount
					,CASE 
						WHEN r.Prize = 1 THEN t.FirstBall + ', ' + t.SecondBall + ', ' + t.ThirdBall -- need space between numbers
						WHEN r.Prize = 2 THEN CASE 
												WHEN r.Seq = 1 THEN t.FirstBall + ', ' + t.SecondBall
												WHEN r.Seq = 2 THEN t.SecondBall + ', ' + t.ThirdBall
												WHEN r.Seq = 3 THEN t.FirstBall + ', ' + t.ThirdBall
												END
						WHEN r.Prize = 3 THEN CASE
												WHEN r.Seq = 1 THEN t.FirstBall
												WHEN r.Seq = 2 THEN t.SecondBall
												WHEN r.Seq = 3 THEN t.ThirdBall
											END
						ELSE NULL
					END AS TransDesc
					,t.WinlostDate
			FROM	#tmpBettrans t
				INNER JOIN dbo.Lucky3RefCombination i WITH(NOLOCK)
					ON	t.livehomescore = i.BallCount
						AND t.HitCount = i.HitCount
				INNER JOIN dbo.Lucky3RefCombinationSet r WITH(NOLOCK)
					ON	i.BallCount = r.BallCount
						AND i.HitCount = r.HitCount
			
			IF EXISTS (SELECT TOP 1 1 FROM dbo.BetLucky3Result WITH(ROWLOCK) WHERE MatchId = @MatchId AND Prize = 1)
			BEGIN
				
				INSERT INTO dbo.BetLucky3Result (
					MatchId
					,TransId
					,CustId
					,Bettype
					,Currency
					,Hdp1
					,Odds
					,StatusId
					,Hits
					,Prize
					,PrizeAmount
					,aPositionTaking
					,mPositionTaking
					,sPositionTaking
					,PlayerDiscount
					,Discount
					,aDiscount
					,sDiscount
					,WinlostDate
				)
				SELECT	r.matchid
						,r.transid
						,r.custid
						,1602 -- Winning share
						,r.currency
						,r.hdp1
						,r.odds
						,0 AS StatusId
						,0 AS Hits
						,0 AS Prize
						,0 AS PrizeAmount
						,0 AS aPositionTaking
						,0 AS mPositionTaking
						,0 AS sPositionTaking
						,0 AS PlayerDiscount
						,0 AS Discount
						,0 AS aDiscount
						,0 AS sDiscount
						,r.WinlostDate
				FROM	dbo.BetLucky3Result r WITH(ROWLOCK)
				WHERE	r.matchid = @matchid
						AND r.Prize = 1
						
			END
		END			
	END
	ELSE IF @Mode = 'CAL'
	BEGIN
		CREATE TABLE #tmpSMAWinningShare (
			CustId				INT
			,WinningShareCom	DECIMAL(9,8)
			,WinningShareSuper	DECIMAL(9,8)
			,WinningShareMaster	DECIMAL(9,8)
			,WinningShareAgent	DECIMAL(9,8)
		)
		
		IF ISNULL(@strCustSetting,'') <> ''
		BEGIN
			DECLARE @xmlData XML = CAST(@strCustSetting AS XML)
			
			INSERT INTO #tmpSMAWinningShare(CustId, WinningShareCom, WinningShareSuper, WinningShareMaster, WinningShareAgent)
			SELECT	T.C.value('@id', 'int') AS CustId
					,ISNULL(T.C.value('@c','DECIMAL(9,8)'),0) as WinningShareCom
					,ISNULL(T.C.value('@s','DECIMAL(9,8)'),0) as WinningShareSuper
					,ISNULL(T.C.value('@m','DECIMAL(9,8)'),0) as WinningShareMaster
					,ISNULL(T.C.value('@a','DECIMAL(9,8)'),0) as WinningShareAgent
			FROM	@xmlData.nodes('/root/r') AS T(C)
			OPTION ( OPTIMIZE FOR ( @XmlData = NULL ) )
		END
		
		SELECT @NumberOfFirstPrize =  SUM(Odds * Hits)
		FROM	dbo.BetLucky3Result
		WHERE	MatchId = @MatchId
				AND Prize = 1
		
		UPDATE	r 
			SET	@StatusId = CASE 
								WHEN r.Prize = 0 AND bettype = 1601 THEN 113
								WHEN r.Prize > 0 THEN 112 								
								ELSE 111
							END
				,@PrizeAmount = CASE
									WHEN r.Prize = 1 THEN p.PrizeAmount * (1 - t.WinningShareCom)
									ELSE p.PrizeAmount
								END
				,StatusId = @StatusId
				,PrizeAmount = @PrizeAmount
				,Winlost = (p.Stake * @PrizeAmount)/ r.hdp1
				,aWinlost = CASE 
								WHEN @StatusId = 113 THEN p.Stake * r.aPositionTaking 
								WHEN @StatusId = 112 THEN p.Stake * -r.aPositionTaking								
								ELSE 0
							END
				,mWinlost = CASE 
								WHEN @StatusId = 113 THEN p.Stake * r.mPositionTaking 
								WHEN @StatusId = 112 THEN p.Stake * -r.mPositionTaking
								ELSE 0
							END
				,sWinlost = CASE 
								WHEN @StatusId = 113 THEN p.Stake * r.sPositionTaking 
								WHEN @StatusId = 112 THEN p.Stake * -r.sPositionTaking								
								ELSE 0
							END
				,PlayerComm = p.Stake * r.PlayerDiscount
				,Comm = p.Stake * ISNULL(p.Discount,0) * (1 - r.aPositionTaking)
				,aComm = p.Stake * ISNULL(p.aDiscount,0) * (1 - r.aPositionTaking - r.mPositionTaking)
				,sComm = p.Stake * ISNULL(p.sDiscount,0) * (1 - r.aPositionTaking - r.mPositionTaking - r.sPositionTaking)
				
				,sDiscount = ISNULL(p.sDiscount,0)
				,aDiscount = ISNULL(p.aDiscount,0)
				,Discount = ISNULL(p.Discount,0)
		FROM	dbo.BetLucky3Result r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN dbo.Lucky3PrizeSettingDetail l WITH(NOLOCK)
				ON	r.Currency = l.ExchangeId
					AND l.PrizeSettingId = @PrizeSettingId
			LEFT JOIN #tmpSMAWinningShare t
				ON	r.CustId = t.CustId
			CROSS APPLY (
				SELECT CASE 
							WHEN @NumberOfFirstPrize <= @FirstPrizeMaxCount THEN l.FirstPrize 
							ELSE l.MaxCap/@NumberOfFirstPrize
						END AS FirstPrizeAmount
			)f
			CROSS APPLY (
				SELECT	CASE 
							WHEN r.Prize = 3 THEN l.ThirdPrize
							WHEN r.Prize = 2 THEN l.SecondPrize
							WHEN r.Prize = 1 THEN f.FirstPrizeAmount
							ELSE 0
						END AS PrizeAmount
						,CASE 
							WHEN r.Bettype = 1602 THEN (r.Odds * f.FirstPrizeAmount)
							WHEN r.bettype = 1601 THEN (r.Odds * r.Hits * r.hdp1)							
							ELSE 0
						END AS Stake
						,CASE
							WHEN r.bettype = 1602 THEN t.WinningShareSuper
							ELSE r.sDiscount
						END AS sDiscount
						,CASE
							WHEN r.bettype = 1602 THEN t.WinningShareMaster
							ELSE r.aDiscount
						END AS aDiscount
						,CASE
							WHEN r.bettype = 1602 THEN t.WinningShareAgent
							ELSE r.Discount
						END AS Discount
			) p
		WHERE	r.MatchId = @MatchId
	END
END
GO