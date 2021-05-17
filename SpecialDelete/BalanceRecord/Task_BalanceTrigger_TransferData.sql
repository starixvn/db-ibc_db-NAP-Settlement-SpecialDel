/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_BalanceTrigger_TransferData]
	@Size INT = 500
AS
/*
	Created: Joe@
	DB: DBBAH.bodb02
	Task: 
	Revision:
		- 20200922@Kathy: Add column matchid, statusid, SettlementType, smawinlost, smacomm [Redmine:#138552]
		- 20201122@Kathy: Add column modds [Redmine:#138552]
		- 20210512@Kathy: Insert data to new table when ticket is settled [Redmine:#154732]
*/
BEGIN
	SET NOCOUNT ON
	SET DEADLOCK_PRIORITY -10	-- make it lowest priority

	Declare @RowID bigint, @cRowID bigint

	SELECT @cRowID = MIN(RowID), @RowID = MAX(RowID) FROM dbo.BalanceTrigger WITH (NOLOCK)

	IF (@RowID - @cRowID) > (@Size - 1) SET @RowID = (@cRowID + @Size - 1)

	Declare @ActionID tinyint -- to get value for condition check balance from DBTrans
	Declare @DelaySecond int  -- compute current delay value
	SELECT @DelaySecond = DATEDIFF(second, ActionDate, CURRENT_TIMESTAMP) 
	FROM dbo.BalanceTrigger WITH (ROWLOCK) 
	WHERE RowID = @cRowID

	BEGIN TRANSACTION

	WHILE @cRowID <= @RowID
	BEGIN
		-- Note : data will insert to BalanceTrigger_ProcessData 
		--        by AFTER DELETE trigger in Table BalanceTrigger

		IF @DelaySecond > 60
		BEGIN
			INSERT INTO dbo.BalanceTrigger_ProcessData
				(RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance,
				MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
			SELECT
				 RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance,
				 MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds
			FROM dbo.BalanceTrigger WITH (ROWLOCK)
			WHERE RowID = @cRowID
		END
		ELSE
		BEGIN
			SELECT @ActionID = ActionID
			FROM dbo.BalanceTrigger WITH (NOLOCK)
			WHERE RowID = @cRowID

			IF @ActionID = 10
				INSERT INTO dbo.BalanceTrigger_ProcessData
					(RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance,
					MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
				SELECT
					 RowID, D.custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, 
					 CASE WHEN ISNULL(c.Credit,0) = 0 THEN [Action]
					 ELSE [Action] + ' Credit:' + CONVERT(varchar(30), ISNULL(c.Credit,0), 2)
					 END,
					 ISNULL(BTBalance,0) - ISNULL(c.Credit,0),
					 D.MatchId, D.StatusId, D.SettlementType,
					 d.swinlost, D.mwinlost, D.awinlost, D.scomm, D.acomm, D.comm, d.modds
				FROM dbo.BalanceTrigger D WITH (ROWLOCK)
					INNER JOIN dbo.CustInfo c WITH (NOLOCK) ON D.custid = c.custid
				WHERE RowID = @cRowID
			ELSE IF @ActionID IN (11,12)
				INSERT INTO dbo.BalanceTrigger_ProcessData
					(RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance,
					MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
				SELECT
					 RowID, D.custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action],
					 v.Balance AS BTBalance,
					 D.MatchId, D.StatusId, D.SettlementType, D.swinlost, D.mwinlost, D.awinlost, D.scomm, D.acomm, D.comm, d.modds
				FROM dbo.BalanceTrigger D WITH (ROWLOCK)
					INNER JOIN DBTRANS.bodb02.dbo.v_BalanceTable v ON D.custid = v.custid
				WHERE RowID = @cRowID
			ELSE
				INSERT INTO dbo.BalanceTrigger_ProcessData
					(RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance,
					 MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
				SELECT
					 RowID, custid, transid, bettype, actual_stake, winlost, playercomm, BalanceChanged, NewBalance, ActionDate, ActionID, [Action], BTBalance, 
					 MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds
				FROM dbo.BalanceTrigger WITH (ROWLOCK)
				WHERE RowID = @cRowID
		END

		INSERT INTO dbo.SettlementHistory (TransId, MatchId, SettlementType, Winlost, StatusId, BalanceChanged)
		SELECT	TransId, MatchId, SettlementType, Winlost, StatusId, b.BalanceChanged
		FROM	dbo.BalanceTrigger b WITH (ROWLOCK)
		WHERE	b.RowID = @cRowID
				AND b.ActionID <> 10 -- bet insert
				AND b.SettlementType <> 1

		DELETE FROM dbo.BalanceTrigger WITH (ROWLOCK)
		WHERE RowID = @cRowID

		SET @cRowID = @cRowID + 1
	END

	COMMIT TRANSACTION

	-- Update BetReplication_Delay value
	-- for condition the query inside trigger Bettrans_After_Insert on [bettrans] table
	DECLARE @MaxTransID BIGINT, @DelaySeconds INT
	SELECT TOP (1) @MaxTransID = transid FROM dbo.bettrans WITH (NOLOCK) ORDER BY transid DESC
	SELECT @DelaySeconds = DATEDIFF(second, transdate, CURRENT_TIMESTAMP) FROM dbo.bettrans WITH (NOLOCK) WHERE transid = @MaxTransID
	UPDATE dbo.SystemSettings WITH (UPDLOCK, ROWLOCK) 
		SET VValue = @DelaySeconds 
		WHERE VName = N'BetReplication_Delay'
END
GO
