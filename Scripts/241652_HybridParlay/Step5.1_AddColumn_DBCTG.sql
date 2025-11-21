/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/ 
/*	
	Created by: 20251121@Max
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251121@Max: Add more column & Migrate data for Hybrid Parlay [Redmine: #243653]
*/
USE bodb02
GO

ALTER TABLE dbo.BetBuilderHybridParlayLog ADD Environment VARCHAR(20) NULL
GO 

