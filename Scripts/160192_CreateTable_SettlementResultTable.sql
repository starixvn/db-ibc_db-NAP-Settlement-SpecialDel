/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
/*
    Created by: 20200824@Louisa
    Task: Definition for Table stored result
    DB: DBPRO-bodb02 

	 Revisions:
		- 20210819@Louisa: Show Provider Results for remain sports [Redmine:#160192]
		
	Param's explanation:
		ResultTable
					0 - match
					1 - ResultDetail
					2 - ResultDetailOS
					3 - ResultDetailES
		ExternalResultTable
					 1 - ProviderExternalResultDetail
					 2 - ProviderExternalResultDetailOS
					 3 - ProviderExternalResultDetailES
	 
*/

USE bodb02
GO

	CREATE TABLE dbo.SettlementResultTable ( 
				  Sporttype				SMALLINT
				, ResultTable			TINYINT
				, ExternalResultTable	TINYINT
				, IsSettleByProfile		BIT
				, IsAppliedSOP			BIT
				, IsMergedParlay		BIT
		)

GO

BEGIN
	INSERT INTO dbo.SettlementResultTable
				  SELECT 1	, 1 , 3 , 0 , 0 , 0
		UNION ALL SELECT 2  , 1	, 1 , 1 , 1 , 1
		UNION ALL SELECT 3  , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 4  , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 6  , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 8  , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 18 , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 19 , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 24 , 0	, 1 , 0 , 0 , 0
		UNION ALL SELECT 25 , 0	, 1 , 0 , 0 , 0

		UNION ALL SELECT 43 , 3 , 3 , 1 , 1 , 1


		UNION ALL SELECT 5	, 1	, 2 , 1 , 1 , 1
		UNION ALL SELECT 7	, 0	, 2 , 0 , 0
		UNION ALL SELECT 9	, 2	, 2 , 1 , 1 , 1
		UNION ALL SELECT 10	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 11	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 12	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 13	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 14	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 15	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 16	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 17	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 20	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 21	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 22	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 23	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 26	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 27	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 28	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 29	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 30	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 31	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 32	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 33	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 34	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 35	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 36	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 37	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 38	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 39	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 40	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 41	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 42	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 44	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 45	, 2	, 2 , 1 , 0 , 1
		UNION ALL SELECT 46	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 47	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 48	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 49	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 50	, 2	, 2 , 1 , 1 , 1
		UNION ALL SELECT 51	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 52	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 53	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 54	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 55	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 56	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 57	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 58	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 59	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 60	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 61	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 62	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 63	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 64	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 65	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 66	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 68	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 69	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 98	, 0	, 2 , 0 , 0 , 0
		UNION ALL SELECT 99	, 0	, 2 , 0 , 0 , 0
END

GO