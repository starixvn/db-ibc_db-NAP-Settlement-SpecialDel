/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Create trigger [bettransLC_After_Update] [Redmineid:#181595]

*/

USE bodb02
GO

	CREATE OR ALTER TRIGGER [dbo].[bettransLC_After_Update]
	   ON [dbo].[bettransLC]
	   AFTER UPDATE
	AS 
	/*
		Created: Joe@
		DB: DBBAH.bodb02
		Task: 
		Revision:
			- 20210309@Kathy: Allow null for bettype,actual_stake, winlost, playercomm [Redmine:#138552]
			- 20220629@Helen: BalanceRecord -> wrong capture balance change and new balance when resettle tickets AE-Sexy product [Redmine:#173971]
			- 20220912@Helen: clone trigger from db05 to sitedb for scaleout project [176932]

	*/
	BEGIN
		-- SET NOCOUNT ON added to prevent extra result sets from
		-- interfering with SELECT statements.
		SET NOCOUNT ON;

		-- Insert statements for trigger here
		INSERT INTO dbo.BalanceTrigger (custid, transid, bettype, actual_stake, winlost, playercomm, ActionDate, 
			ActionID, [Action],
			BalanceChanged)
		SELECT
			-- if inserted.custid = 0, this should be VOID + Hidden
			-- if deleted.custid = 0, this may be Bet Recover
			case when i.custid =0 then d.custid else i.custid end,
			i.transid, i.gameID, ISNULL(i.actual_stake,0), ISNULL(i.winlost,0), ISNULL(i.playercomm,0), CURRENT_TIMESTAMP, 

			CASE
			WHEN i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
			WHEN i.IsSum = 1 AND d.IsSum = 0 THEN 33 -- Record SUM
			WHEN i.statusid = 102 THEN 050 -- Void Bet
			WHEN d.statusid = 0 AND i.statusid > 0 THEN 030 -- Settled : running -> Won/Lose/Draw/Refund
			WHEN d.statusid = 102 AND i.statusid = 0 THEN 055 -- unvoid/recover : void -> running
			WHEN d.statusid > 0 THEN CASE i.statusid WHEN 0 THEN 032 ELSE 031 END -- resettle or unsettle
			ELSE 0 END,
        
			--CASE WHEN i.custid =0 THEN 'Delete ' ELSE 'Update ' END
			--  + CASE WHEN i.bettype < 19001 then 'Bet' ELSE 'Transfer' END + 
			--CASE WHEN i.custid <> 0 THEN ', from '+ d.[status] + ' to ' + i.[status] ELSE '' END
			--[Action]--vvv
			'LC' +
			ISNULL(CASE
				WHEN i.IsSum = d.IsSum THEN ' (IsSUM : ' + CAST(d.IsSUM AS varchar(50)) + ')'
				ELSE ' (IsSUM : ' + CAST(d.IsSUM AS varchar(50)) + ' to ' + CAST(i.IsSUM AS varchar(50)) + ') ' + CAST(ISNULL(i.RefNo,0) AS VARCHAR(50))
			END +
			CASE
				WHEN i.custid = 0 THEN ' cancelled, ' + d.[status] + ' to ' + i.[status]
				WHEN d.statusid = 0 THEN
					CASE i.statusid
					WHEN 102 THEN ' voided'
					ELSE ' settled, ' + d.[status] + ' to ' + i.[status]
					END
				WHEN i.statusID = d.statusID THEN ' updated'
				ELSE ' updated, ' + d.[status] + ' to ' + i.[status]
			END,' NULL ')
			--[Action]--^^^ 
			, 
			CASE  WHEN (ISNULL(i.winlost,0)- ISNULL(i.actual_stake,0) + ISNULL(i.playercomm,0)) <> (ISNULL(d.winlost,0) - ISNULL(d.actual_stake,0) + ISNULL(d.playercomm,0)) 
				THEN (ISNULL(i.winlost,0)- ISNULL(i.actual_stake,0) + ISNULL(i.playercomm,0)) - (ISNULL(d.winlost,0) - ISNULL(d.actual_stake,0) + ISNULL(d.playercomm,0)) 
			ELSE 0 END
		FROM
			inserted i INNER JOIN deleted d
			ON i.transid = d.transid
		WHERE
			d.custid <> d.recommend AND
			d.custid <> d.mrecommend AND
			d.custid <> d.srecommend
			-- Joe@20120705 : eliminate row which data is not change 
			AND (
				ISNULL(i.actual_stake,0) <> ISNULL(d.actual_stake,0) OR ISNULL(i.winlost,0) <> ISNULL(d.winlost,0) OR ISNULL(i.playercomm,0) <> ISNULL(d.playercomm,0)
				OR i.statusid <> d.statusid
				OR i.custid <> d.custid
				OR i.IsSum <> d.IsSum
			)
        
	END
	