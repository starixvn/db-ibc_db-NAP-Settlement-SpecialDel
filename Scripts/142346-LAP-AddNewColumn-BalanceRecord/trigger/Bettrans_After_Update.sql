USE [bodb02]
GO
/****** Object:  Trigger [dbo].[Bettrans_After_Update]    Script Date: 11/19/2020 12:17:20 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

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
		- 20201119@Kathy: Add column modds [Redmine:#142346]
		- 20201119@Sol: modified action text - [Redmine:#142346]
*/

BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for trigger here
	INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
		ActionID, [Action],
		BalanceChanged,
		MatchId, StatusId, SettlementType, swinlost, mwinlost, awinlost, scomm, acomm, comm, modds)
	SELECT
		-- if inserted.custid = 0, this should be VOID + Hidden
		-- if deleted.custid = 0, this may be Bet Recover
		case when i.custid =0 then d.custid else i.custid end,
		i.transid, i.bettype, i.actual_stake, isnull(i.winlost,0) as winlost, isnull(i.playercomm,0) as playercomm, CURRENT_TIMESTAMP, 

		CASE 
			WHEN (
				i.actual_stake <> d.actual_stake 
				OR isnull(i.winlost,0) <> isnull(d.winlost,0) 
				OR isnull(i.playercomm,0) <> isnull(d.playercomm,0)
				OR isnull(i.statusid,0) <> isnull(d.statusid,0)
				OR i.custid <> d.custid
			) THEN
				CASE
				WHEN isnull(i.statusid,0) = 102 THEN 050 -- Void Bet

				WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 1 THEN CASE isnull(i.statusid,0) WHEN 101 THEN 020 WHEN 0 THEN 021 ELSE 0 END -- waiting -> Reject : running : something else
				WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 0 AND isnull(i.statusid,0) > 0 THEN 030 -- Settled : running -> Won/Lose/Draw/Refund

				WHEN i.bettype < 19001 AND isnull(d.statusid,0) = 102 AND isnull(i.statusid,0) = 0 THEN 055 -- unvoid/recover : void -> running
				WHEN i.bettype < 19001 AND isnull(d.statusid,0) > 0 THEN CASE isnull(i.statusid,0) WHEN 0 THEN 032 ELSE 031 END -- resettle or unsettle

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
			ELSE isnull(d.[status],'running')
		END +
		CASE
			WHEN i.custid = 0 THEN ' cancelled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
			WHEN i.bettype > 20000 THEN ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
			WHEN isnull(d.statusid,0) = 1 THEN
				CASE isnull(i.statusid,0)
				WHEN 0 THEN ' accepted'
				WHEN 101 THEN ' rejected'
				ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END
			WHEN isnull(d.statusid,0) = 0 THEN
				CASE 
					WHEN isnull(i.statusid,0) = 102 THEN ' voided'
					WHEN (isnull(i.statusid,0) BETWEEN 111 AND 113) OR isnull(i.statusid,0) = 103 THEN ' settled, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
					ELSE ' updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
				END
			ELSE ' Updated, ' + isnull(d.[status],'running') + ' to ' + isnull(i.[status],'running')
		END
		--[Action]--^^^	
 		, isnull( (i.winlost-i.actual_stake+i.playercomm) - (d.winlost-d.actual_stake+d.playercomm),0)
		,i.matchid
		,isnull(i.statusID,0)
		,CASE 
			WHEN (isnull(i.statusID,0) BETWEEN 111 AND 113 OR isnull(i.statusID,0) = 103) 
				THEN CASE 
						WHEN d.SettlementTime IS NULL THEN 1 -- first settled
						WHEN i.SettlementTime <> d.SettlementTime 
							THEN CASE
									WHEN isnull(d.statusID,0) = 0 THEN 2 -- change from running to settle 
									ELSE 3 
								END -- re-settled: change from settle to settle
						WHEN isnull(d.statusID,0) BETWEEN 111 AND 113 THEN 4 -- settle to settle, no change winlost
						ELSE 0 
					END
			ELSE 0
		END -- SettlementType
		,isnull(i.swinlost,0) as swinlost
		,isnull(i.mwinlost,0) as mwinlost
		,isnull(i.awinlost,0) as awinlost
		,isnull(i.scomm,0) as scomm
		,isnull(i.acomm,0) as acomm
		,isnull(i.comm,0) as acomm
		,i.modds
	FROM
		inserted i INNER JOIN deleted d
		ON i.transid = d.transid
	WHERE
		d.custid <> d.recommend AND
		d.custid <> d.mrecommend AND
		d.custid <> d.srecommend		
END



    
