/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/ 
/*	
	Created by: 20251121@Max
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251121@Max: Add more column & Migrate data for Hybrid Parlay [Redmine: #243653]
*/
USE bodb02
GO

DECLARE @Environment VARCHAR(20)
SET @Environment = CASE WHEN @@SERVERNAME = 'TESTDBTRANS' THEN 'LOCAL'
						WHEN @@SERVERNAME = 'SITDBTRANS' THEN 'SIT'
						WHEN @@SERVERNAME = 'DBTRANS' THEN 'UAT'
						ELSE ''
					END

UPDATE b SET b.Environment = @Environment
FROM dbo.BetBuilderHybridParlayLog b WITH (ROWLOCK, UPDLOCK)

