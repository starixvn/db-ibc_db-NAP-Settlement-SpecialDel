/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Create trigger [Transfer_After_Update] [Redmineid:#181595]

*/

USE bodb02
GO

	CREATE OR ALTER TRIGGER [dbo].[Transfer_After_Update]
	   ON [dbo].[Transfer]
	   AFTER UPDATE
	AS 
	/*
		Created: 20221110@Max
		DB: DBSIG-bodb02
		Task: [LAP] Detail transaction_Display Different Balance Amount of Deposit & Withdrawal [Redmine: #180295]
		Revision:
			- 20221110@Max: clone trigger from db05 to sitedb [Redmine:#180295]
			- 20230309@Aries: Enhance trigger on table transfer of SiteDB [Redmine:#184782]
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
					WHEN i.bettype > 20000 AND i.custid = 0 THEN 130 -- cancel transfer (custid set to zero)
					WHEN i.bettype > 20000 THEN 120 -- update transfer
					ELSE 0 END
				ELSE 001
			END,
        
			--[Action]--vvv
			CASE
				WHEN i.bettype > 20000 THEN 'Transfer'
				ELSE ''
			END +
			CASE
				WHEN i.custid = 0      THEN ' cancelled, ' + CAST(d.[StatusId] AS varchar(50)) + ' to ' + CAST(i.[StatusId] AS varchar(50))
				WHEN i.bettype > 20000 THEN ' updated, '   + CAST(d.[StatusId] AS varchar(50)) + ' to ' + CAST(i.[StatusId] AS varchar(50))
				ELSE ' Updated, ' + CAST(d.[StatusId] AS varchar(50)) + ' to ' + CAST(i.[StatusId] AS varchar(50))
			END
			--[Action]--^^^ 
			, (isnull(i.winlost,0) - ISNULL(i.actual_stake, 0) + ISNULL(i.playercomm,0))
				- (ISNULL(d.winlost,0) - ISNULL(d.actual_stake, 0) + ISNULL(d.playercomm,0))
			,0 --i.matchid
			,isnull(i.statusID,0)
			,0 -- SettlementType
			,isnull(i.swinlost,0) as swinlost
			,isnull(i.mwinlost,0) as mwinlost
			,isnull(i.awinlost,0) as awinlost
			,isnull(i.scomm,0) as scomm
			,isnull(i.acomm,0) as acomm
			,isnull(i.comm,0) as comm
			,0 --i.modds
		FROM
			inserted i INNER JOIN deleted d
			ON i.transid = d.transid
		WHERE
			d.custid <> d.recommend AND
			d.custid <> d.mrecommend AND
			d.custid <> d.srecommend AND 
			i.Bettype NOT IN (19999, 20000)     
	END