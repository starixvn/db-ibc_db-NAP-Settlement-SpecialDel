/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Create trigger [Transfer_After_Insert] [Redmineid:#181595]

*/

--- run on SiteDB3  only

USE bodb02
GO

	CREATE OR ALTER TRIGGER [dbo].[Transfer_After_Insert]
	ON [dbo].[Transfer]
	FOR INSERT
	AS
	/*
		Created: 20221110@Max
		DB: DBSIG-bodb02
		Task: [LAP] Detail transaction_Display Different Balance Amount of Deposit & Withdrawal [Redmine: #180295]
		Revision:
			- 20221110@Max: clone trigger from db05 to sitedb [Redmine:#180295]
	*/

	BEGIN

			INSERT INTO BalanceTrigger (
				custid, transid, bettype, 
				actual_stake, winlost, playercomm,
				BalanceChanged,
				ActionDate, ActionID, [Action],
				BTBalance,
				MatchId, StatusId, SettlementType,
				swinlost, mwinlost, awinlost,
				scomm, acomm, comm, modds)
			SELECT
				i.custid, transid, bettype, isnull(actual_stake,0), isnull(winlost,0), playercomm,
				CASE bettype 
				WHEN 19999 THEN 0
				WHEN 20000 THEN 0
				ELSE isnull(winlost,0) - ISNULL(actual_stake, 0) + ISNULL(playercomm,0) END,
				current_timestamp,
				CASE
				WHEN bettype > 20000 THEN 110 -- transfer insert
				WHEN bettype = 19999 THEN 100 -- SUM insert
				WHEN bettype = 20000 THEN 255 -- Balance insert
				ELSE 0 END,

				CASE
					--WHEN bettype = 19999 THEN 'SUM ' + CONVERT(varchar(10), i.winlostdate, 120)
					--WHEN bettype = 20000 THEN 'BAL ' + CONVERT(varchar(10), i.winlostdate, 120)
					WHEN bettype > 20000 THEN 'Transfer'
				END + ' inserted' + ' (' + CAST(refno AS varchar(50)) + ')'
				,

				-- Joe@2021-11-23
				-- will see later if have value for Balance in this Transfer table
				-- may start to record the number rather than NULL                      
				--CASE
				--WHEN bettype < 19001 THEN ISNULL(i.Balance,0) - isnull(actual_stake,0) + isnull(winlost,0) + playercomm
				--ELSE NULL END
				NULL
				AS BTBalance,


				0 --i.matchid
				,i.statusID
				,0 -- SettlementType
				,i.swinlost, i.mwinlost, i.awinlost
				,i.scomm, i.acomm, i.comm, 0 --i.modds
			FROM
				inserted i with (nolock)
				--INNER JOIN DBTRANS.bodb02.dbo.v_BalanceTable v ON i.custid = v.custid
			WHERE
				i.custid <> recommend AND
				i.custid <> mrecommend AND
				i.custid <> srecommend
				AND i.Bettype NOT IN (19999, 20000)
			ORDER BY
				i.transid

	END