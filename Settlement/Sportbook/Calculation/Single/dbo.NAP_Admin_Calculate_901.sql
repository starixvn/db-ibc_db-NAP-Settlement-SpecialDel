/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_901]
	@matchid INT,	
	@action	VARCHAR(30)= '',
	@mode	VARCHAR(30)= '',
	@isRefundHT			BIT = 0
 AS
	/*
		Created: Johnson
		Date: 20150529
		Task: Settlement for Bettrade(Refund's tickets will be Recalculated & Uncalculated cases)
		DB: DBTXN/BODB02
		
		Revisions:
			- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
			- 20161108@Kathy: Settlement for new server [Redmine:#66849]
			- 20170404@Bobby: 73404 - Integrate CashOut bettypes
			- 20170411@Bobby: 74819 - Correct Bettrade condition for auto bettypes
			- 20170614@Kathy: Remove table BetTradeSellingCancelled on server DBLicAPI, SITDBLicAPI [Redmine:#77991]
			- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
			- 20181129@Kathy: Allow to cal/undo sub tickets on DB04x [Redmine:#105327]
			- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
			- 20190620@Kathy: Remove auto betradar bettypes [Redmine:#109584]
			- 20200825@Kathy: Migrate DB06 to cluster [Redmine:#140045]
			- 20220405@Louisa: Add New server alias ( new local test 2019) [Redmine:#171615]
			
		Parameter's Explantion:
	*/
BEGIN
	SET NOCOUNT ON

	DECLARE @statusID INT
			,@winlost MONEY
			,@ServerAlias VARCHAR(50) = ''
	
	DECLARE @tmpBettype TABLE(bettype INT)
	CREATE TABLE #tmp (transid BIGINT)
	
	--get list bettype with each action & mode
	--recover refund tickets to previous status
	IF @action = 'CAL'
	BEGIN
		IF @mode IN ('CAL','CAL-FT')
		BEGIN
			INSERT INTO @tmpBettype(bettype)
						SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4 
				UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 16 UNION ALL SELECT 17
				UNION ALL SELECT 18 UNION ALL SELECT 157 UNION ALL SELECT 177 
				UNION ALL SELECT 178 UNION ALL SELECT 183 UNION ALL SELECT 184 UNION ALL SELECT 22
			
			--for match 3x30 dont touch 2H bettypes refunded				
			DELETE @tmpBettype
			WHERE bettype IN (16,177,178,183,184)
				AND @isRefundHT = 1
		END
		IF @Mode IN ('CAL-HT', 'CAL')
		BEGIN
			INSERT INTO @tmpBettype(bettype)
			SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 12 UNION ALL SELECT 15
			UNION ALL SELECT 30 UNION ALL SELECT 126 UNION ALL SELECT 22
		END
	END
	IF @action = 'CAL-FGLG'
	BEGIN
		IF @Mode = 'CAL-HT'
		BEGIN
			INSERT INTO @tmpBettype(bettype)
				SELECT 127
		END
		IF @mode = 'CAL-FT'
			BEGIN
				INSERT INTO @tmpBettype(bettype)
					SELECT 14
			END
	END	
	
	--this case for un-calculating refund tickets to previous status
	IF @mode = 'UNDO'
	BEGIN
		INSERT INTO @tmpBettype(bettype)
		
			SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
			UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 
			UNION SELECT 12 UNION SELECT 14 UNION SELECT 15 UNION SELECT 16 
			UNION SELECT 17 UNION SELECT 18	UNION SELECT 22 
			UNION SELECT 30 UNION SELECT 126 UNION SELECT 127
			UNION SELECT 157 UNION SELECT 177 UNION SELECT 178 
			UNION SELECT 183 UNION SELECT 184 
			
	END
	
	--get main tickets which have been sold to bettrade
	INSERT INTO #tmp(transid)
	SELECT b.transid
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.bettype IN (SELECT bettype FROM @tmpBettype)
		AND b.matchid = @matchid
		AND b.statusid NOT IN (101,102)		
		AND b.betdaqid = 0--indicate tickets belong to bettrade
		AND b.ExtraInfo IS NULL
	
	IF @@ROWCOUNT = 0 RETURN
	
	--BEGIN recover refund tickets 
	SELECT transid, refno, bettype, statusid, status, actual_stake, winlost, awinlost, discount, odds
	INTO #bettrans
	FROM bettrans WITH(NOLOCK)
	WHERE matchid = @matchid
		AND bettype IN (901,902,903)
		AND refno IN (SELECT transid FROM #tmp)
		AND statusid = 103--refund's tickets
	
	UPDATE b1
	SET b1.winlost = b2.actual_stake,
		b1.awinlost = -(b2.actual_stake - b1.actual_stake),
		@statusID = CASE WHEN b1.actual_stake > b2.actual_stake THEN 113 
						WHEN b1.actual_stake = b2.actual_stake THEN 111
						ELSE 112 END,
		b1.statusID = @statusID,						
		b1.status = CASE WHEN @statusID = 113 THEN 'LOSE' 
						WHEN @statusID = 111 THEN 'DRAW'
						ELSE 'WON' END		
	FROM #bettrans b1 
		INNER JOIN #bettrans b2 ON b1.refno= b2.refno 											
	WHERE b1.bettype = 901
		AND b2.bettype = 902	
	
	UPDATE b1
	SET b1.winlost = b2.actual_stake,
		b1.awinlost = -(b2.actual_stake - b1.actual_stake),
		@statusID = CASE WHEN b1.actual_stake > b2.actual_stake THEN 113 
						WHEN b1.actual_stake = b2.actual_stake THEN 111
						ELSE 112 END,
		b1.statusID = @statusID,						
		b1.status = CASE WHEN @statusID = 113 THEN 'LOSE' 
						WHEN @statusID = 111 THEN 'DRAW'
						ELSE 'WON' END		
	FROM #bettrans b1 
		INNER JOIN #bettrans b2 ON b1.refno= b2.refno 											
	WHERE b1.bettype = 902
		AND b2.bettype = 901
	
	
	UPDATE	b903
	SET		@winlost = b901.winlost * b903.odds,
			@statusID = CASE 
							WHEN @winlost = b903.actual_stake THEN 111
							WHEN @winlost > b903.actual_stake THEN 112
							ELSE 113
						END,
			statusId = @statusID,
			status = CASE 
							WHEN @statusID = 111 THEN 'DRAW'
							WHEN @statusID = 112 THEN 'WON'
							ELSE 'LOSE'
					END,
			winlost = @winlost,
			awinlost = b901.winlost* b903.discount
	FROM	#bettrans b903 
		INNER JOIN #bettrans b901 
			ON	b903.refno= b901.refno 											
	WHERE	b903.bettype = 903
			AND b901.bettype = 901		
	
	UPDATE b
	SET b.status = b1.status,
		b.statusid = b1.statusid,
		b.winlost = b1.winlost,
		b.awinlost = b1.awinlost
	FROM bettrans b WITH(UPDLOCK,ROWLOCK)
		INNER JOIN #bettrans b1 ON b.transid = b1.transid
	--end
		
	--Insert bettrade tickets to send API
	IF @@SERVERNAME IN ('DBTRANS', 'DB230','DB206', 'TESTDBTRANS', 'SITDBTRANS')
	BEGIN
		DECLARE @Session NVARCHAR(50) = CONVERT(NVARCHAR(50),NEWID())
		
		INSERT INTO [dbo].[BettradeAPI]
           ([transid] 
			,[matchid]        
           ,[session]
           ,[action]
           ,[buybackNo]
           ,[payout])
        SELECT TicketID,			
			matchid,
			@Session,
			@action+':'+@mode as action,			
			BuyBackNo,
			PayOut
        FROM dbo.BettradeSelling b WITH(NOLOCK)
		WHERE ticketID IN (SELECT DISTINCT refno FROM #bettrans)
			AND status IN ('Accept','Confirm')
	END
	
	EXEC dbo.NAP_Set_ServerInfo @ServerAlias = @ServerAlias OUTPUT

	--recover BetTradeSelling & BetTradeSellingCancelled on DBTXN	
	IF @@SERVERNAME IN ('DB230' -- local dev
		,'DB206' -- local test
		,'TESTDBTRANS' --new local test 2019
		,'SITDBTRANS' -- SIT
		,'DBTRANS','DBTP','DB061', 'DB062' -- prod
	) OR @ServerAlias = 'DBACC'
	BEGIN		
		UPDATE dbo.BetTradeSellingCancelled WITH(UPDLOCK,ROWLOCK)
		SET BTBuyback = -BTBuyback,
			Remark = 'SB recover ticket',
			AfterBalance = 0,
			Cancelled = 0,
			ChangeDate = GETDATE()
		WHERE TicketID IN (SELECT transid FROM #tmp)
			AND Cancelled = 1
	END	
	
	DROP TABLE #bettrans		
	DROP TABLE #tmp							
END		
GO
 