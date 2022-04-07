/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_500] 
	@MatchId	INT
	,@Action	VARCHAR(20)
	,@CustIds	VARCHAR(MAX) = ''
AS
/*
		Created: Kathy
		Date: 20160112
		Task: Calculating charged commission
			NOTE: This is NOT execRep SP
		DB: DBTXN/bodb02
		
		Revisions:
			- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
			
		Parameter's Explanation:
			@Action: CAL, CAL-FT, REFUND-FT, REFUND, UNDO
			@CustIds: IMBC Cust List
								
*/ 
BEGIN
	SET NOCOUNT ON

	IF @Action IN ('CAL', 'CAL-FT', 'VOID')
	BEGIN
		--for case void & recover
		IF ISNULL(@CustIds, '') <> ''
		BEGIN
			DECLARE @CustIdList TABLE(CustId INT)
			INSERT INTO @CustIdList(CustId)
			SELECT CAST([value] AS INT)
			FROM STRING_SPLIT(@CustIds, ',')
		END

		CREATE TABLE #NetWinCust (FirstTransId		BIGINT PRIMARY KEY
									,NetWin			MONEY
									,CustId			INT
									,PlayerDiscount DECIMAL(9,8)
									,Discount		DECIMAL(9,8)
									,ADiscount		DECIMAL(9,8)
									,Creator		INT
									,WinlostDate	SMALLDATETIME
									,BetFrom		NVARCHAR(1)
									,BetCheck		NVARCHAR(50)
									,ActualRate		FLOAT
									,Recommend		INT
									,MRecommend		INT
									,Currency		TINYINT
									,SDiscount		DECIMAL(9,8)
									,SRecommend		INT
									,Username		NVARCHAR(50)
									,CurrencyName	NVARCHAR(50)
									,VirtualRate	FLOAT
								)
									
		INSERT INTO #NetWinCust (FirstTransId, NetWin, CustId)
		SELECT	MIN(transid), SUM(winlost - actual_stake), custid
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	matchid = @matchid
				AND bettype = 501
				AND (ISNULL(@CustIds, '') = '' OR (ISNULL(@CustIds, '') <> '' AND EXISTS (SELECT 1 FROM @CustIdList s WHERE b.CustId = s.CustId)))
				 AND statusID NOT IN (0, 1, 101, 102) -- REJECT, VOID
				AND playerdiscount < 0
		GROUP BY custid
		
		UPDATE	n
			SET PlayerDiscount = b.playerdiscount
				,Discount = b.discount
				,ADiscount = b.adiscount
				,Creator = b.creator
				,WinlostDate = b.winlostdate
				,BetFrom = b.betfrom
				,BetCheck = b.betcheck
				,ActualRate = b.actualrate
				,Recommend = b.recommend
				,MRecommend = b.mrecommend
				,Currency = b.currency
				,SDiscount = b.sdiscount
				,SRecommend = b.srecommend
				,Username = b.Username
				,CurrencyName = b.CurrencyName
				,VirtualRate = b.virtualrate					
		FROM #NetWinCust n
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON n.FirstTransId = b.transid
		
		IF EXISTS (SELECT TOP 1 1 FROM #NetWinCust)
		BEGIN
			MERGE	dbo.bettrans AS b
			USING	(SELECT * FROM #NetWinCust) AS n
				ON	b.matchid = @MatchId
					AND b.bettype = 500
					AND b.custid = n.CustId
			WHEN MATCHED AND b.winlost <> n.NetWin THEN UPDATE SET	[status] = CASE WHEN n.NetWin > 0 THEN 'LOSE' ELSE 'VOID' END
																	,winlost = CASE WHEN n.NetWin > 0 THEN n.NetWin ELSE 0 END
																	,playerdiscount = n.PlayerDiscount
																	,discount = n.Discount
																	,adiscount = n.ADiscount
																	,sdiscount = n.SDiscount
																	,playercomm = CASE WHEN n.NetWin > 0 THEN n.PlayerDiscount * n.NetWin ELSE 0 END
																	,comm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.Discount) * n.NetWin ELSE 0 END
																	,acomm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.ADiscount) * n.NetWin ELSE 0 END
																	,scomm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.SDiscount) * n.NetWin ELSE 0 END														
																	,actual_stake = CASE WHEN n.NetWin > 0 THEN n.NetWin ELSE 0 END
																	,statusID = CASE WHEN n.NetWin > 0 THEN 113 ELSE 102 END
																	,statuswinlost = CASE WHEN n.NetWin > 0 THEN NULL ELSE 6 END
			WHEN NOT MATCHED BY TARGET AND n.NetWin > 0 THEN INSERT (	
													custid
													,transdate
													,oddsid
													,hdp1
													,hdp2
													,odds
													,stake
													,[STATUS]
													,winlost
													,awinlost
													,mwinlost
													,playercomm
													,comm
													,acomm
													,apositiontaking
													,mpositiontaking
													,tpositiontaking
													,playerdiscount
													,discount
													,adiscount
													,livehomescore
													,liveawayscore
													,liveindicator
													,betteam
													,creator
													,refno
													,comstatus
													,winlostdate
													,betfrom
													,betcheck
													,checktime
													,oddsspread
													,actualrate
													,matchid
													,recommend
													,mrecommend
													,ruben
													,betid
													,statuswinlost
													,modds
													,bettype
													,betdaqid						
													,actual_stake
													,currency
													,ip
													,transdesc
													,sdiscount
													,scomm
													,spositiontaking
													,swinlost
													,srecommend
													,Username
													,CurrencyName
													,virtualrate
													,oddstype
													,statusID
													,currency2
													,balance
													,SecAcceptFlag
													,transid2
													,RecommDate
												)
										VALUES (custid
												,GETDATE() --AS transdate
												,0 --AS oddsid
												,0 --AS hdp1
												,0 --AS hdp2
												,0 --AS odds
												,0 --AS stake
												,'LOSE' --AS [STATUS]
												,n.NetWin --AS winlost
												,0 --AS awinlost
												,0 --AS mwinlost
												,n.PlayerDiscount * n.NetWin --AS playercomm
												,(n.PlayerDiscount - n.Discount) * n.NetWin --AS comm
												,(n.PlayerDiscount - n.ADiscount) * n.NetWin --AS acomm
												,0 --AS apositiontaking
												,0 --AS mpositiontaking
												,0 --AS tpositiontaking
												,n.PlayerDiscount
												,n.Discount
												,n.ADiscount
												,0 --AS livehomescore
												,0 --AS liveawayscore
												,0 --AS liveindicator
												,NULL --AS betteam
												,n.Creator
												,100000000000 --AS refno
												,NULL --AS comstatus
												,n.WinlostDate
												,n.BetFrom
												,n.BetCheck
												,NULL --AS checktime
												,NULL --AS oddsspread
												,n.ActualRate
												,@Matchid
												,n.Recommend
												,n.MRecommend
												,1 --AS ruben
												,NULL --AS betid
												,NULL --AS statuswinlost
												,-1 --AS modds
												,500 --AS bettype
												,NULL --AS betdaqid
												,n.NetWin --AS actual_stake
												,n.Currency
												,'' --AS ip
												,'' --AS transdesc
												,n.SDiscount
												,(n.PlayerDiscount - n.SDiscount) * n.NetWin --AS scomm
												,0 --AS spositiontaking
												,0 --AS swinlost
												,n.SRecommend
												,n.Username
												,n.CurrencyName
												,n.VirtualRate
												,NULL --AS oddstype
												,113 --AS statusID
												,NULL --AS currency2
												,NULL --AS balance
												,NULL --AS SecAcceptFlag
												,NULL --AS transid2
												,NULL --AS RecommDate
												)
			;								
		END
		ELSE IF ISNULL(@CustIds, '') <> ''
		BEGIN
			--for case all of tickets [501] has been voided. So we no need to re-calculate charge comm
			UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
			SET	[status] = 'VOID'
				,winlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,actual_stake = 0
				,statusID = 102
				,statuswinlost = 6
			WHERE matchid = @MatchId
				AND bettype = 500
				AND custid IN (SELECT CustId FROM @CustIdList)
				AND statusID NOT IN (101, 102) -- REJECT, VOID
				
		END
		
		DROP TABLE #NetWinCust
	END
	ELSE IF @Action IN ('REFUND', 'REFUND-FT', 'UNDO')
	BEGIN
		UPDATE	dbo.bettrans WITH(ROWLOCK, UPDLOCK)
			SET	[status] = 'VOID'
				,winlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,actual_stake = 0
				,statusID = 102
				,statuswinlost = 6
		WHERE	matchid = @MatchId
				AND bettype = 500
				AND statusID NOT IN (101, 102) -- REJECT, VOID
				
	END
END
GO