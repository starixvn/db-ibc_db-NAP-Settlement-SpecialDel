/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Create trigger [TransLog_After_Update] [Redmineid:#181595]

*/

--- run on SiteDB3  only

USE bodb02
GO

	CREATE OR ALTER TRIGGER [dbo].[TransLog_After_Update]
	   ON [dbo].[translog]
	   AFTER UPDATE
	AS 
	/*
		Created: Joe@
		DB: DB05.BODB02
		Task: 
		Revision:
			- 20210309@Kathy: Allow null for bettype,actual_stake, winlost, playercomm [Redmine:#138552]
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
			case when i.custid = 0 then d.custid else i.custid end,
			i.translogid, i.gameID, ISNULL(i.actual_stake,0), 0, 0, CURRENT_TIMESTAMP, 

			/*
			i.custid <> 0
				statusID 0 -> X : settled, void
				statusID X -> 0 : unsettle
			i.custid = 0
				statusID 0 -> X : settled, void
				statusID X -> 0 : unsettle
				statusID not change
			*/
			CASE
			WHEN i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
			WHEN d.custid = 0 AND i.custid > 0 THEN 055 -- recover bet
			WHEN i.statusid = 102 THEN 050 -- Void Bet
			WHEN d.statusid = 0 AND i.statusid > 0 THEN 030 -- Settled : running -> Won/Lose/Draw/Refund
			WHEN d.statusid = 102 AND i.statusid = 0 THEN 055 -- unvoid/recover : void -> running
			WHEN d.statusid > 0 THEN CASE i.statusid WHEN 0 THEN 032 ELSE 031 END -- resettle or unsettle
			ELSE 0 END,
        
			--[Action]--vvv
			'TransLog' +
			CASE
				WHEN i.custid = 0 THEN ' cancelled, ' + d.[status] + ' to ' + i.[status]
				WHEN d.statusid = 0 THEN
					CASE i.statusid
					WHEN 102 THEN ' voided'
					ELSE ' settled, ' + d.[status] + ' to ' + i.[status]
					END
				ELSE ' updated, ' + d.[status] + ' to ' + i.[status]
			END
			--[Action]--^^^ 
			, 
			CASE
			WHEN i.statusID > 0 AND d.statusID = 0 THEN  ISNULL(i.actual_stake,0) -- settled : add back balance (value transfer to handle in bettrans)
			WHEN i.statusID = 0 AND d.statusID > 0 THEN -ISNULL(i.actual_stake,0) -- set back to Running : deduct balance again
			WHEN i.statusID = d.statusID THEN -- status not change? try to see actual_stake/custid
				CASE
				WHEN i.statusID = 0 AND ISNULL(i.actual_stake,0) <> ISNULL(d.actual_stake,0) THEN ISNULL(d.actual_stake,0) - ISNULL(i.actual_stake,0) -- re-adjust value
				WHEN i.statusID = 0 AND i.custid = 0 AND i.custid <> d.custid THEN -ISNULL(i.actual_stake,0) --remove value, when change custid to 0
				WHEN i.statusID = 0 AND d.custid = 0 AND i.custid <> d.custid THEN  ISNULL(i.actual_stake,0) --add back value, when change custid back from 0
				ELSE 0 END
			ELSE 0
			END
		FROM
			inserted i INNER JOIN deleted d
			ON i.translogid = d.translogid
		WHERE
			d.custid <> d.recommend AND
			d.custid <> d.mrecommend AND
			d.custid <> d.srecommend
			-- Joe@20120705 : eliminate row which data is not change 
			AND (
				ISNULL(i.actual_stake,0) <> ISNULL(d.actual_stake,0)
				OR i.statusid <> d.statusid
				OR i.custid <> d.custid
			)
	END
	