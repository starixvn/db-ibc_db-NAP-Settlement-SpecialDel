/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_914] 
	@MatchId		INT 
	,@Action		VARCHAR(20)
	,@CustIds		VARCHAR(MAX) = ''
	,@Sporttype		SMALLINT = NULL
AS
/*
	Created: 20170313@Bobby.Nguyen	
	Task: #73235 - Implement Cash-Out winlost sharing transaction
	DB: DBTXN/bodb02
	
	Revisions:
		- 20200205@Helen: Support CashOut for Non-live Market [Redmine:#127807]
		- 20210809@Kathy: Settle by custid [Redmine:159486]
		
	Parameter's Explanation:
		@Action: CAL, CAL-HT, CAL-FT, REFUND-HT, REFUND-FT, REFUND, UNDO
		@CustIds: CashOut's members custid
								
*/ 
BEGIN
	SET NOCOUNT ON

	DECLARE @ServerAlias VARCHAR(50) = ''

	DECLARE @tmpBalanceChanged TABLE (CustId INT, Balance MONEY)

	EXEC dbo.NAP_Set_ServerInfo 
		@ServerAlias = @ServerAlias OUTPUT	

	IF @Action <> 'UNDO'
	BEGIN
		CREATE TABLE #CashOutWLSharing (
			FirstBoughtId		BIGINT
			,matchid			INT
			,custid				INT
			,transid2			BIGINT
			,winlost			MONEY
			,actual_stake		MONEY
			
			,[status]			NVARCHAR(10)
			,statusId			TINYINT
			,Creator			INT
			,UserName			NVARCHAR(50)
			,recommend			INT
			,mrecommend			INT
			,srecommend			INT
			,currency			TINYINT
			,CurrencyName		NVARCHAR(50)
			,actualrate			FLOAT
			,winlostdate		SMALLDATETIME	
			,liveindicator		BIT	
		)
		
		CREATE TABLE #CustIdList (CustId INT)

		IF(@Action IN ('VOID', 'RECOVER')
			AND ISNULL(@CustIds, '') <> ''
		)
		BEGIN
			INSERT INTO #CustIdList(CustId)
			SELECT CAST(val AS INT) AS CustId
			FROM dbo.f_SplitString(@CustIds, ',')
			OPTION (MAXRECURSION 0)
		
		END
		
		INSERT INTO #CashOutWLSharing(matchid, custid,liveindicator, FirstBoughtId, transid2, winlost)
		SELECT @matchid AS matchid 
			,b.custid
			,b.liveindicator
			,MIN(b.transid) AS FirstBoughtId
			,MIN(b.transid2) AS transid2
			,SUM((b.winlost - b.actual_stake + cob.winlost - cob.actual_stake) * b.oddsspread) AS winlost
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN dbo.bettrans cob WITH(NOLOCK) 
				ON cob.matchid = b.matchid 
				AND cob.custid = b.custid
				AND cob.refno = b.refno 
				AND cob.bettype NOT BETWEEN 912 AND 914 --normal bettype tickets
			
		WHERE b.matchid = @matchid
			AND 1 = CASE 				
						WHEN @action IN ('VOID', 'RECOVER') THEN 
							CASE WHEN EXISTS(SELECT TOP 1 1 FROM #CustIdList WHERE custid = b.custid) THEN 1 ELSE 0 END
						ELSE 1
					END			
			AND b.bettype = 912
			AND cob.statusID <> 0 --NOT running ticket
		
		GROUP BY b.custid, b.liveindicator
				
		
		IF(@@ROWCOUNT = 0) RETURN
		
		--UPDATE detail info
		UPDATE bt 
			SET 
				winlost = CASE WHEN bt.winlost < 0 THEN ABS(bt.winlost) ELSE 0 END
				,actual_stake = CASE WHEN bt.winlost > 0 THEN bt.winlost ELSE 0 END
				,[status] = CASE 
								WHEN bt.Winlost < 0 THEN 'WON'
								WHEN bt.Winlost = 0 THEN 'DRAW'
								WHEN bt.Winlost > 0 THEN 'LOSE'
								ELSE [b].[status]
							END
				,statusID = CASE
								WHEN bt.Winlost < 0 THEN 112
								WHEN bt.Winlost = 0 THEN 111
								WHEN bt.Winlost > 0 THEN 113
								ELSE b.statusID
							END
				,Creator = bt.custid
				,UserName = b.Username
				,recommend = b.recommend
				,mrecommend = b.mrecommend
				,srecommend = b.srecommend
				,currency = b.currency
				,CurrencyName = b.CurrencyName
				,actualrate = b.actualrate
				,winlostdate = b.winlostdate
		FROM	#CashOutWLSharing bt
			INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	bt.FirstBoughtId = b.transid
		
		--INSERT/UPDATE WinlossSharing record
		MERGE dbo.bettrans AS b
		USING #CashOutWLSharing AS bt
			ON	b.matchid = bt.MatchId
				AND b.custid = bt.CustId
				AND b.bettype = 914
				AND b.liveindicator = bt.liveindicator
				
		WHEN MATCHED THEN UPDATE 
								SET [status] = bt.[status]
									,statusID = bt.statusID
									,winlost = bt.winlost
									,actual_stake = bt.actual_stake
				
		WHEN NOT MATCHED BY TARGET THEN INSERT (
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
										VALUES (
												bt.custid --custid
												,GETDATE() --transdate
												,0--oddsid
												,0 --hdp1
												,0 --hdp2
												,0 --odds
												,0 --stake
												,bt.[status]--[STATUS]
												,bt.winlost
												,0 --awinlost
												,0 --mwinlost
												,0 --playercomm
												,0 --comm
												,0 --acomm
												,0 --apositiontaking
												,0 --mpositiontaking
												,0 --tpositiontaking
												,0 --playerdiscount
												,0 --discount
												,0 --adiscount
												,0 --livehomescore
												,0 --liveawayscore
												,bt.liveindicator --liveindicator
												,NULL --betteam
												,bt.creator
												,100000000000 --refno
												,0 --comstatus
												,bt.winlostdate
												,'d' --betfrom
												,NULL --betcheck
												,NULL --checktime
												,0 --oddsspread
												,bt.actualrate
												,bt.matchid
												,bt.recommend
												,bt.mrecommend
												,1 --ruben
												,0 --betid
												,NULL --statuswinlost
												,1 --modds
												,914 --bettype
												,1 --betdaqid						
												,bt.actual_stake
												,bt.currency
												,'127.0.0.1' --ip
												,NULL --transdesc
												,0 --sdiscount
												,0 --scomm
												,0 --spositiontaking
												,0 --swinlost
												,bt.srecommend
												,bt.Username
												,bt.CurrencyName
												,bt.actualrate
												,1 --oddstype
												,bt.statusID
												,NULL --currency2
												,0 --balance
												,0 --SecAcceptFlag
												,bt.transid2
												,NULL --RecommDate
											)
			OUTPUT inserted.custid
				,(inserted.winlost - inserted.actual_stake + inserted.playercomm)
					- (ISNULL(deleted.winlost,0) - ISNULL(deleted.actual_stake,0) + ISNULL(deleted.playercomm,0))
			INTO @tmpBalanceChanged (CustId, Balance);

		IF @ServerAlias = 'DBTXN' AND @Action ='CAL' AND @Sporttype = 1
		BEGIN
			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@tmpBalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) > 0
		
			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@tmpBalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) < 0
		END
	END
	ELSE
	BEGIN
		UPDATE b WITH (ROWLOCK, UPDLOCK)
			SET winlost = 0
				,actual_stake = 0
				,statusID = 111
				,[status] = 'DRAW'
		FROM	dbo.bettrans b
		WHERE	b.matchid = @MatchId
				AND b.bettype = 914
	END
	
END
GO
