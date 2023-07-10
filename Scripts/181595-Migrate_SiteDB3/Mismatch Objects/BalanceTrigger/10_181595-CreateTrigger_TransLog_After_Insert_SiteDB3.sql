/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Create trigger [TransLog_After_Insert] [Redmineid:#181595]

*/

USE bodb02
GO

	CREATE OR ALTER TRIGGER [dbo].[TransLog_After_Insert]
	ON [dbo].[translog]
	FOR INSERT
	AS
	/*
		Created: Joe@
		DB: DB05.BODB02
		Task: 
		Revision:
			- 20190611@Patrick: CN88 integration
			- 20210309@Kathy: Allow null for bettype,actual_stake, winlost, playercomm [Redmine:#138552]
			- 20220912@Helen: clone trigger from db05 to sitedb for scaleout project [176932]
	*/
	BEGIN
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

		IF @__IsCN88 = 0
		BEGIN
			--PRINT GETDATE()
			INSERT INTO BalanceTrigger (
				custid, transid, bettype, 
				actual_stake, winlost, playercomm,
				BalanceChanged,
				ActionDate, ActionID, [Action],
				BTBalance)
			SELECT
				i.custid, translogid, gameID, ISNULL(actual_stake,0), 0, 0,
				CASE statusID
				WHEN 0 THEN -ISNULL(actual_stake,0)
				ELSE 0 END,
				current_timestamp,
				011, -- TransLog insert
				--'Insert ' + CASE WHEN bettype < 19001 then 'Bet' ELSE 'Transfer' END + ', status ' + [status]
				-- my suggested pattern (Joe)
				'TransLog inserted as ' + [status],
				NULL Balance
				--v.Balance
			FROM
				inserted i
				--INNER JOIN DBTRANS.bodb02.dbo.v_BalanceTable v ON i.custid = v.custid
			WHERE
				i.custid <> recommend AND
				i.custid <> mrecommend AND
				i.custid <> srecommend
				--AND custid = 2211693
				--AND currency IN (3, 5, 20)
			ORDER BY
				i.translogid
		END
		ELSE
		BEGIN
			INSERT INTO BalanceTrigger (
				custid, transid, bettype, 
				actual_stake, winlost, playercomm,
				BalanceChanged,
				ActionDate, ActionID, [Action],
				BTBalance)
			SELECT
				i.custid, translogid, gameID, ISNULL(actual_stake,0), 0, 0,
				CASE statusID
				WHEN 0 THEN -ISNULL(actual_stake,0)
				ELSE 0 END,
				current_timestamp,
				011, -- TransLog insert
				--'Insert ' + CASE WHEN bettype < 19001 then 'Bet' ELSE 'Transfer' END + ', status ' + [status]
				-- my suggested pattern (Joe)
				'TransLog inserted as ' + [status],
				--0 Balance
				NULL AS Balance
			FROM
				inserted i
				--INNER JOIN DBTRANS.bodb02.dbo.v_BalanceTable v ON i.custid = v.custid
			WHERE
				i.custid <> recommend AND
				i.custid <> mrecommend AND
				i.custid <> srecommend
				--AND custid = 2211693
				--AND currency IN (3, 5, 20)
			ORDER BY
				i.translogid
		END
	END