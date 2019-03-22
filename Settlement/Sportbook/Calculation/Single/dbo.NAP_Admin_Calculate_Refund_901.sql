/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Refund_901]
	@matchid INT,	
	@ResourceIDs VARCHAR(MAX)=NULL,
	@IsSettleAbandonedMatchIBC BIT = 0,
	@action	VARCHAR(30)= 'REFUND',
	@mode	VARCHAR(30)= 'REFUND',
	@LGOnly BIT = 0--refund last goal
	
AS
	/*
		Created: Johnson
		Date: 2015-06-02
		DB: DBTXN/bodb02
		Task: Refund for bettrade tickets
		
		Revisions:
			- 20160808@Kathy: BetTrade - changes for new commercial terms - add bettype 904 [Redmine:#61905]
			- 20161108@Kathy: Settlement for new server [Redmine:#66849]
			- 20170404@Bobby: 73404 - Integrate CashOut bettypes
			- 20170614@Kathy: Remove table BetTradeSellingCancelled on server DBLicAPI, SITDBLicAPI [Redmine:#77991]
			- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
			- 20181129@Kathy: Allow to cal/undo sub tickets on DB04x [Redmine:#105327]
			- 20190315@Kathy: Add 2 new servers DB061, DB062 [Redmine:#110276]
			
		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @tmpBettype TABLE(bettype INT)
 
	DECLARE @bettype_22 VARCHAR(20), @bettype_160 VARCHAR(20)
    SET @bettype_22 = '22'
    SET @bettype_160 = '160'
    
	IF OBJECT_ID('tempdb..#tmp') IS NOT NULL
	begin
			drop table #tmp
	end

	CREATE TABLE #tmp (transid BIGINT, BTbuyback money)
	
	CREATE TABLE #tmpRef(refno BIGINT)
		
	IF @action = 'REFUND'
	BEGIN
		--Refund from manual settlement
		IF @mode IN ('REFUND-FT','REFUND') AND @ResourceIDs IS NULL
		BEGIN
			INSERT INTO @tmpBettype(bettype)
					SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 
				UNION SELECT 5 UNION SELECT 6 UNION SELECT 16 UNION SELECT 17
				UNION SELECT 18 UNION SELECT 157 UNION SELECT 177 
				UNION SELECT 178 UNION SELECT 183 UNION SELECT 184 
		END
		IF @mode IN ('REFUND-HT','REFUND') AND @ResourceIDs IS NULL
		BEGIN
			INSERT INTO @tmpBettype(bettype)
					SELECT 7 UNION SELECT 8 UNION SELECT 12 UNION SELECT 15
				UNION SELECT 30 UNION SELECT 126
				UNION SELECT 16 UNION SELECT 177 UNION SELECT 178 UNION SELECT 183 UNION SELECT 184 --refund for match 3x30 
		END
		--Refund from auto settlement
		IF @mode = 'REFUND' AND @ResourceIDs IS NOT NULL
		BEGIN
			INSERT INTO @tmpBettype(bettype)
				SELECT 160 UNION SELECT 180
				UNION ALL SELECT 22
				
				
		END
	END
	--Refund FGLG
	IF @action = 'REFUND-FGLG'
	BEGIN
		IF @mode IN ('REFUND','REFUND-HT')
		BEGIN
			INSERT INTO @tmpBettype(bettype)
				SELECT 127
		END
		IF @mode IN ('REFUND','REFUND-FT')
		BEGIN
			INSERT INTO @tmpBettype(bettype)
				SELECT 14
				
		END		
	END
	
	--get main tickets which have been sold to bettrade
	INSERT INTO #tmp(transid)
	SELECT transid
	FROM bettrans WITH(NOLOCK)
	WHERE bettype IN (SELECT bettype FROM @tmpBettype)
		AND matchid = @matchid
		AND statusid NOT IN (101,102)
		AND betdaqid = 0--indicate tickets belong to bettrade
		AND ExtraInfo IS NULL
		AND 1 = CASE 
					WHEN @ResourceIDs IS NOT NULL AND Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(BetID AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDs)>0 THEN 1 
					WHEN @ResourceIDs IS NOT NULL AND Bettype IN (160,180) AND CHARINDEX(SUBSTRING(CAST(BetID AS VARCHAR(20)),2,5),@ResourceIDs)>0 THEN 1 
					WHEN @ResourceIDs IS NULL AND bettype NOT IN (160,180,22) THEN 1
					ELSE 0 
				END
		AND 1 = CASE WHEN @IsSettleAbandonedMatchIBC = 1 
						AND statusID IN (112, 113) THEN 0
				ELSE 1 END
		
		AND 1= CASE WHEN bettype IN (14,127) 
						AND right(betteam, 1) = CASE WHEN @LGOnly = 1 THEN '2' ELSE right(betteam, 1) END 
					THEN 1 
					WHEN bettype NOT IN (14,127) THEN 1
					ELSE 0 
				END

				
	IF @@ROWCOUNT = 0 RETURN
	
	UPDATE t
	SET BTbuyback = b.awinlost
	FROM #tmp t
		INNER JOIN bettrans b WITH(NOLOCK) ON t.transid = b.refno
	WHERE b.matchid = @matchid 
		AND b.bettype = 901
		
	--BEGIN: Refund sub-tickets on bettrans
	UPDATE bettrans WITH(UPDLOCK,ROWLOCK)
	SET winlost = actual_stake,
		awinlost = 0,
		status = 'Refund',
		statusid = 103,
		ruben = 1
	OUTPUT DELETED.refno INTO #tmpRef
	WHERE matchid = @matchid 
		AND bettype IN (901,902,903)
		AND refno IN (SELECT transid FROM #tmp)
		AND statusID <> 103
	--END
	
	--Insert bettrade tickets to send API
	IF @@SERVERNAME IN ('DBTRANS','DB230','DB206', 'SITDBTRANS')
	BEGIN
		DECLARE @Session NVARCHAR(50) = CONVERT(NVARCHAR(50),NEWID())
		
		INSERT INTO [dbo].[BettradeAPI]
           ([transid]    
           ,[Matchid]		       
           ,[Session]
           ,[action]
           ,[buybackNo]
           ,[Payout])
        SELECT TicketID,
			Matchid,
			@Session,
			@action+':'+@mode as action,			
			BuyBackNo,
			PayOut
        FROM bettradeSelling b WITH(NOLOCK)
		WHERE ticketID IN (SELECT refno FROM #tmpRef)
			AND status IN ('Accept','Confirm')
	END
	
	--BEGIN: Cancel BetTradeSelling/BetTradeSellingCancelled ON DBTXN
	IF @@SERVERNAME IN ('DBTRANS','DB06','DBTP','DB230','DB232','DB206','DB234', 'SITDBTRANS', 'SITDB06', 'DB061', 'DB062')
	BEGIN		
		UPDATE b
		SET Remark = 'SB refund ticket',
			b.BTBuyback = t.BTBuyback,
			BTComission = 0,
			AfterBalance = 0,
			Owner = 'SB',
			Cancelled = 1,
			ChangeDate = GETDATE()
		FROM BetTradeSellingCancelled b WITH(UPDLOCK,ROWLOCK)
			INNER JOIN #tmp t ON b.TicketID = t.transID
		WHERE ticketID IN (SELECT refno FROM #tmpRef)
		
		--insert records into BetTradeSellingCancelled if not exist these tickets	
		INSERT INTO BetTradeSellingCancelled(
			TradeID
			,TicketID
			,Remark
			,BTBuyBack
			,BTComission
			,AfterBalance
			,Owner
			,Cancelled
			,ChangeDate
			,CreateDate
		)
		SELECT bt.TradeID
			,t.transid
			,'SB refund ticket'
			,t.BTBuyback
			,0
			,0
			,'SB'
			,1
			,GETDATE()
			,GETDATE()
		FROM #tmp t 
			INNER JOIN BetTradeSelling bt WITH(NOLOCK) ON t.transid = bt.ticketID
			LEFT JOIN BetTradeSellingCancelled b WITH(NOLOCK) ON t.transid = b.TicketID
		WHERE b.TicketID IS NULL
			AND bt.Status IN ('Accept','Confirm')
	END
	--END
	
	DROP TABLE #tmp
	DROP TABLE #tmpRef
				
END
GO
