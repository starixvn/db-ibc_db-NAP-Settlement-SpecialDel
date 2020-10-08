/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER TRIGGER [dbo].[Bettrans_After_Insert]
ON [dbo].[bettrans]
FOR INSERT
AS
/*
	Created: Joe@
	DB: DBBAH.BODB02
	Task: 
	Revision:
		- 20190611@Patrick: CN88 integration
		- 20200925@Joe : change to utilize bettrans.balance for reference instead of reading data from DBTrans (for BalanceTable balance)
		- 20200922@Kathy: Add column MatchId, StatusId, SettlementType, sma winlost, sma commission [Redmine:#138552]
*/

BEGIN

/* 
--20200925@Joe : as we using bettrans.balance, no need to consider delay of Replication
	DECLARE @DelaySeconds INT
	SELECT @DelaySeconds = VValue
		FROM dbo.SystemSettings WITH (NOLOCK)
		WHERE VName = N'BetReplication_Delay'
*/
/*
--20200925@Joe :  as we using bettrans.balance instead of read data from DBTrans, ignore case of CN88
	--if this record belong to CN88 member then skip get data from v_BalanceTable.
	DECLARE @__IsCN88 BIT
	IF EXISTS (SELECT TOP 1 1 FROM inserted d 
				WHERE EXISTS (
					SELECT TOP 1 1 FROM dbo.CS_CustSuper c WITH(NOLOCK) 
					WHERE d.srecommend =  c.CustId))
	BEGIN
		SET @__IsCN88 = 1
	END
	ELSE
	BEGIN
		SET @__IsCN88 = 0
	END
*/

--	IF @DelaySeconds < 60 AND @__IsCN88 = 0
		--PRINT GETDATE()
		INSERT INTO BalanceTrigger (
			custid, transid, bettype, 
			actual_stake, winlost, playercomm,
			BalanceChanged,
			ActionDate, ActionID, [Action],
			BTBalance,
			MatchId, StatusId, SettlementType,
			swinlost, mwinlost, awinlost,
			scomm, acomm, comm)
		SELECT
			i.custid, transid, bettype, isnull(actual_stake,0), isnull(winlost,0), playercomm,
			CASE bettype 
			WHEN 19999 THEN 0
			WHEN 20000 THEN 0
			ELSE isnull(winlost-actual_stake+playercomm,0) END,
			current_timestamp,
			CASE
			WHEN bettype < 19001 THEN 010 -- bet insert
			WHEN bettype > 20000 THEN 110 -- transfer insert
			WHEN bettype = 19999 THEN 100 -- SUM insert
			WHEN bettype = 20000 THEN 255 -- Balance insert
			ELSE 0 END,
			--'Insert ' + CASE WHEN bettype < 19001 then 'Bet' ELSE 'Transfer' END + ', status ' + [status]
			-- my suggested pattern (Joe)
			CASE
			WHEN bettype < 19001 THEN 'Bet'
			WHEN bettype > 20000 THEN 'Transfer'
			ELSE [status] + ' ' + CONVERT(varchar(10), i.winlostdate, 120)
			END + ' inserted' +
			CASE
			WHEN statusID > 1 AND refno NOT IN (100000000000,260000000000,0) THEN ' as ' + [status] + ' (' + CAST(refno AS varchar(50)) + ')'
			WHEN bettype < 19001 THEN ' as ' + [status]
			WHEN bettype > 20000 THEN ' as ' + [status] + ' (' + CAST(refno AS varchar(50)) + ')'
			ELSE '' END,
			--0 Balance
			CASE
			WHEN bettype < 19001 THEN ISNULL(i.Balance,0) - isnull(actual_stake,0) + isnull(winlost,0) + playercomm
			ELSE NULL END
			AS BTBalance,
			i.matchid
			,i.statusID
			,0 -- SettlementType
			,i.swinlost, i.mwinlost, i.awinlost
			,i.scomm, i.acomm, i.comm
		FROM
			inserted i with (nolock)
			--INNER JOIN DBTRANS.bodb02.dbo.v_BalanceTable v ON i.custid = v.custid
		WHERE
			i.custid <> recommend AND
			i.custid <> mrecommend AND
			i.custid <> srecommend
			--AND custid = 2211693
			--AND currency IN (3, 5, 20)
		ORDER BY
			i.transid

	/*
		INSERT INTO dbo.RowInsert_Bettrans (custid, transid, matchid, bettype, winlostdate, InsertTime, winlost, actual_stake, playercomm, statusID)
		SELECT custid, transid, matchid, bettype, winlostdate, SYSDATETIME(), winlost, actual_stake, playercomm, statusID
		FROM inserted
		WHERE 
			custid <> recommend AND
			custid <> mrecommend AND
			custid <> srecommend AND
			bettype IN (19999,20000)
	*/	

END
