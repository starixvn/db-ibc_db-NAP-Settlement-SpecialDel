/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Copy  structure of table BalanceTrigger [Redmineid:#181595]

*/

USE bodb02
GO

	IF NOT EXISTS (SELECT TOP 1  1 FROM sys.objects WHERE name = 'BalanceTrigger')
	BEGIN
		CREATE TABLE BalanceTrigger 
		( 	
			RowID			bigint identity(1,1) NOT FOR REPLICATION NOT NULL ,
			custid			int			NOT NULL,
			transid			bigint		NOT NULL,
			bettype			smallint	NOT NULL,
			actual_stake	money		NOT NULL,
			winlost			money		NOT NULL,
			playercomm		money		NOT NULL,
			BalanceChanged	money		NOT NULL,
			NewBalance		money ,
			ActionDate		datetime	NOT NULL,
			ActionID		tinyint ,
			Action			varchar(200) NOT NULL,
			BTBalance		money ,
			StatusId		tinyint ,
			MatchId			int ,
			SettlementType	tinyint ,
			awinlost		money ,
			mwinlost		money ,
			swinlost		money ,
			comm			money ,
			acomm			money ,
			scomm			money ,
			modds			smallmoney 
		)


		ALTER TABLE BalanceTrigger ADD  CONSTRAINT [PK_BalanceTrigger] PRIMARY KEY CLUSTERED 
		(
			RowID ASC
		)

		
		ALTER TABLE BalanceTrigger ADD CONSTRAINT [DF_BalanceTrigger_SettlementType] DEFAULT(0) FOR [SettlementType]
 
	END

GO