/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231205@Louisa
	Task:  Result Amendment [Redmine:#196401]
	DB: DBTXN-bodb02

	Revision:
		- 20231205@Louisa: Create Index on table single queue, parlay queue [Redmine:#196401]

*/


USE bodb02
GO
	
	---SITEDB1, SITEDB2   
	IF NOT EXISTS (SELECT TOP 1 1 FROM sys.tables as t
						INNER JOIN sys.columns as c
							ON  t.object_id = c.object_id
						INNER JOIN sys.index_columns as ic 
							ON c.column_id = ic.column_id AND c.object_id = ic.object_id
						INNER JOIN sys.indexes as i
							ON ic.index_id = i.index_id AND ic.object_id = i.object_id
					WHERE t.name = 'single_Calculate_Queue' 
						 AND c.name = 'matchid'
						 AND is_included_column = 0
						 AND key_ordinal = 1
					 )
	BEGIN
		CREATE NONCLUSTERED INDEX IX_Single_Calculate_Queue_MatchId ON dbo.Single_Calculate_Queue ( MatchId ASC )
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
		ON Event_table
	END

	---SITEDB1, SITEDB2, SITEDB3, DBTRANS
	IF NOT EXISTS (SELECT TOP 1 1 FROM sys.tables as t
						INNER JOIN sys.columns as c
							ON  t.object_id = c.object_id
						INNER JOIN sys.index_columns as ic 
							ON c.column_id = ic.column_id AND c.object_id = ic.object_id
						INNER JOIN sys.indexes as i
							ON ic.index_id = i.index_id AND ic.object_id = i.object_id
					WHERE t.name = 'Parlay_Calculate_Queue' 
						 AND c.name = 'matchid'
						 AND is_included_column = 0
						 AND key_ordinal = 1
					 )
	BEGIN
		CREATE NONCLUSTERED INDEX IX_Parlay_Calculate_Queue_MatchId ON dbo.Parlay_Calculate_Queue ( MatchId ASC )
		WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = ON, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
		ON Event_table
		
	END
	
