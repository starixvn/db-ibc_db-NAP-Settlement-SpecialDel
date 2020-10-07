/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER TRIGGER [dbo].[Bettrans_After_Update]
   ON [dbo].[bettrans]
   AFTER UPDATE
AS 
/*
	Created: Joe@
	DB: DBBAH.bodb02
	Task: 
	Revision:
		- 20200922@Kathy: Add column matchid, statusid, Settlement, smawinlost, smacomm [Redmine:#138552]
		- 20201007@Sol: Add new action id due to code changed - [Redmine:#142346]
*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
	INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
		ActionID, [Action],
		BalanceChanged,
		MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm)
	SELECT
		-- if inserted.custid = 0, this should be VOID + Hidden
		-- if deleted.custid = 0, this may be Bet Recover
		case when i.custid =0 then d.custid else i.custid end,
		i.transid, i.bettype, i.actual_stake, i.winlost, i.playercomm, CURRENT_TIMESTAMP, 

		CASE 
			WHEN (
				i.actual_stake <> d.actual_stake 
				OR i.winlost <> d.winlost 
				OR i.playercomm <> d.playercomm
				OR i.statusid <> d.statusid
				OR i.custid <> d.custid
			) THEN
				CASE
				WHEN i.statusid = 102 THEN 050 -- Void Bet

				WHEN i.bettype < 19001 AND d.statusid = 1 THEN CASE i.statusid WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
				WHEN i.bettype < 19001 AND d.statusid = 0 AND i.statusid > 0 THEN 030 -- Settled : running -> Won/Lose/Draw/Refund

				WHEN i.bettype < 19001 AND d.statusid = 102 AND i.statusid = 0 THEN 055 -- unvoid/recover : void -> running
				WHEN i.bettype < 19001 AND d.statusid > 0 THEN CASE i.statusid WHEN 0 THEN 032 ELSE 031 END -- resettle or unsettle

				WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
				WHEN i.bettype > 20000 THEN 120 -- update transfer

				--WHEN i.bettype < 19001 AND d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
				ELSE 0 END
			ELSE 001
		END,
		
		--CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
		--	+ CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
		--CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
		--[Action]--vvv
		CASE
			WHEN i.bettype < 19001 THEN 'Bet'
			WHEN i.bettype > 20000 THEN 'Transfer'
			ELSE d.[status]
		END +
		CASE
			WHEN i.custid = 0 THEN ' cancelled, ' + d.[status] + ' to ' + i.[status]
			WHEN i.bettype > 20000 THEN ' updated, ' + d.[status] + ' to ' + i.[status]
			WHEN d.statusid = 1 THEN
				CASE i.statusid
				WHEN 0 THEN ' accepted'
				WHEN 101 THEN ' rejected'
				ELSE ' updated, ' + d.[status] + ' to ' + i.[status]
				END
			WHEN d.statusid = 0 THEN
				CASE i.statusid
				WHEN 102 THEN ' voided'
				ELSE ' settled, ' + d.[status] + ' to ' + i.[status]
				END
			ELSE ' updated, ' + d.[status] + ' to ' + i.[status]
		END
		--[Action]--^^^	
 		, (i.winlost-i.actual_stake+i.playercomm) - (d.winlost-d.actual_stake+d.playercomm)
		,i.matchid
		,i.statusID
		,CASE 
			WHEN (i.statusID BETWEEN 111 AND 113 OR i.statusID = 103) 
				THEN CASE 
						WHEN d.SettlementTime IS NULL THEN 1 -- first settled
						WHEN i.SettlementTime <> d.SettlementTime 
							THEN CASE
									WHEN d.statusID = 0 THEN 2 -- change from running to settle 
									ELSE 3 
								END -- re-settled: change from settle to settle
						WHEN d.statusID BETWEEN 111 AND 113 THEN 4 -- settle to settle, no change winlost
						ELSE 0 
					END
			ELSE 0
		END -- SettlementType
		,i.swinlost
		,i.mwinlost
		,i.awinlost
		,i.scomm
		,i.acomm
		,i.comm
	FROM
		inserted i INNER JOIN deleted d
		ON i.transid = d.transid
	WHERE
		d.custid <> d.recommend AND
		d.custid <> d.mrecommend AND
		d.custid <> d.srecommend		
END

