/*<info serverAlias="DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

DECLARE @statusId			TINYINT
		,@winlost			MONEY
		,@settlementTime	DATETIME

DECLARE @tmpSource TABLE (TransId BIGINT PRIMARY KEY, WinlostDate SMALLDATETIME
		, totalStake MONEY, Winlost MONEY, aWinlost MONEY, mWinlost MONEY, sWinlost MONEY
		, playerComm MONEY, comm MONEY, aComm MONEY, sComm MONEY
		, ruben TINYINT
		, IsMarked BIT DEFAULT (0)
	)

DECLARE @tmpTransInfo TABLE (transId BIGINT, custid INT, balancechanged MONEY )

INSERT INTO @tmpSource (TransId, WinlostDate, totalStake
		,Winlost, aWinlost, mWinlost, sWinlost
		,playerComm, comm, aComm, sComm
		,ruben)
	SELECT b.transid, MAX(pr.winlostdate), SUM(pr.stake)
		,SUM(pr.winlost), SUM(pr.awinlost), SUM(pr.mwinlost),  SUM(pr.swinlost) 
		,SUM(pr.playercomm), SUM(pr.comm), SUM(pr.acomm), SUM(pr.scomm) 			
		,CASE WHEN SUM(CASE pr.statusID WHEN 0 THEN pr.stake ELSE 0 END) > 0 THEN 0 ELSE 1 END -- in case got sub running, then ruben=0, otherwise set ruben=1
	FROM dbo.BetParlayResult pr WITH(NOLOCK)
		INNER JOIN bettrans b WITH(NOLOCK)
			ON	pr.refno = b.refno
	WHERE pr.refno IN (13516713052078080,13513470083334153,13517197309640707,13515029961768960,13511177912975366,13514163988987914,13511309446348817)
		AND b.transid IN (216178846611800095,216180951145775239,216215521337540681,216226623828000858,216240479392497669,216267408837443604,216275156958445592)
	GROUP BY pr.refno, b.transid

SET @settlementTime = GETDATE();

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
		,SettlementTime = CASE 
							WHEN s.IsMarked = 1 THEN b.SettlementTime
							WHEN @statusId <> 0 AND (b.winlost <> @winlost OR statusID <> @statusId) THEN @settlementTime 
							ELSE SettlementTime 
						END
		,statusID = CASE WHEN s.IsMarked = 1 THEN b.statusID ELSE @statusId END
		,[status] = CASE 
						WHEN s.IsMarked = 1 THEN b.status 
						WHEN @statusId = 0 THEN 'running' 
						WHEN @statusId = 111 THEN 'DRAW' -- winlost = stake, member DRAW
						WHEN @statusId = 112 THEN 'WON' -- winlost > stake, member WIN
						WHEN @statusId = 113 THEN 'LOSE' -- winlost < stake, member LOSE
						ELSE b.[status] -- uncontrollale situation, hope it's not happen in real life
					END
		,betdaqid = CASE WHEN s.IsMarked = 1 THEN b.betdaqid ELSE s.totalStake END						
		,ruben = CASE WHEN s.IsMarked = 1 THEN b.ruben ELSE s.ruben END
		,winlost =  CASE WHEN s.IsMarked = 1 THEN b.winlost ELSE @winlost END
		,awinlost = CASE WHEN s.IsMarked = 1 THEN b.awinlost ELSE s.awinlost * s.ruben END
		,mwinlost = CASE WHEN s.IsMarked = 1 THEN b.mwinlost ELSE s.mwinlost * s.ruben END
		,swinlost = CASE WHEN s.IsMarked = 1 THEN b.swinlost ELSE s.swinlost * s.ruben END
		,playercomm = CASE WHEN s.IsMarked = 1 THEN b.playercomm ELSE s.playercomm * s.ruben END
		,comm = CASE WHEN s.IsMarked = 1 THEN b.comm ELSE s.comm * s.ruben END
		,acomm = CASE WHEN s.IsMarked = 1 THEN b.acomm ELSE s.acomm * s.ruben END
		,scomm = CASE WHEN s.IsMarked = 1 THEN b.scomm ELSE s.scomm * s.ruben END
		,statuswinlost = CASE 
							WHEN @statusId = 112 THEN 2							
							WHEN @statusId = 111 THEN 0 							
							WHEN @statusId = 113 THEN 4								
							WHEN @statusId = 0 THEN NULL
						END 
		,RepUpdateTime = SYSDATETIME()
	OUTPUT inserted.transid, inserted.custid
		 ,(inserted.winlost - deleted.winlost) + (inserted.playercomm - deleted.playercomm)
		
	INTO @tmpTransInfo (transId, custid
		,balancechanged
	)
	FROM @tmpSource s
		INNER JOIN dbo.bettrans b
			ON b.transid = s.transid

	INSERT INTO dbo.BalCreditSportsPending(custid, balance)
	SELECT	custid, SUM(balancechanged)
	FROM	@tmpTransInfo
	GROUP BY custid
	HAVING SUM(balancechanged) > 0

	INSERT INTO dbo.BalDebitSportsPending(custid, balance)
	SELECT	custid, ABS(SUM(balancechanged))
	FROM	@tmpTransInfo
	GROUP BY custid
	HAVING SUM(balancechanged) < 0