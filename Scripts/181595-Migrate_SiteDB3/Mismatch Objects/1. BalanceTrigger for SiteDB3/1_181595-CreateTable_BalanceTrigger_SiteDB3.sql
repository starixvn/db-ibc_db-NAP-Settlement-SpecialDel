/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/  

/*
	Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 - add mismatch objects [Redmineid:#181595]
   
    Revisions:
		- 20220130@Louisa: Copy  structure of table BalanceTrigger [Redmineid:#181595]

*/

--- run on SiteDB3  only

USE bodb02
GO

	CREATE TABLE dbo.BalanceTrigger
	(
		RowID bigint IDENTITY(1,1) NOT NULL,
		custid int NOT NULL,
		transid bigint NOT NULL,
		bettype smallint NOT NULL,
		actual_stake money NOT NULL,
		winlost money NOT NULL,
		playercomm money NOT NULL,
		BalanceChanged money NOT NULL,
		NewBalance money NULL,
		ActionDate datetime NOT NULL,
		ActionID tinyint NULL,
		Action varchar(200) NOT NULL,
		BTBalance money NULL,
		StatusId tinyint NULL,
		MatchId int NULL,
		SettlementType tinyint NULL,
		awinlost money NULL,
		mwinlost money NULL,
		swinlost money NULL,
		comm money NULL,
		acomm money NULL,
		scomm money NULL,
		modds smallmoney NULL,
		CONSTRAINT PK_BalanceTrigger PRIMARY KEY CLUSTERED 
		(
		RowID ASC
		)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = ON) ON BALANCE
	) ON BALANCE
	GO

	ALTER TABLE dbo.BalanceTrigger ADD  CONSTRAINT DF_BalanceTrigger_SettlementType  DEFAULT ((0)) FOR SettlementType
	GO

	CREATE NONCLUSTERED INDEX inx_BalanceTrigger_custid ON dbo.BalanceTrigger
	(
		custid ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON BALANCE
	GO

	CREATE NONCLUSTERED INDEX IX_BalanceTrigger_ActionDate ON dbo.BalanceTrigger
	(
		ActionDate ASC
	)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = ON) ON BALANCE
	GO
