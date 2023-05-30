/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_GetAction] ()
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
	Created date: 20220301@Louia
	DB: DBTXN/bodb02
	TASK: Allow insert command into Single_Calculate_Queue by group Action [Redmine:#168497]
	

	Revision
		- 20220228@Louisa: Inittial
		- 20220404@Kathy: Allow to Settle Determined FT Ticket When Calculate HT [Redmine:#170551]
		- 20230404@Kathy: Merge single and parlay [Redmine:#175202]
	
*/
RETURN
	(
			  SELECT CAST ('CAL' AS VARCHAR(20)	) AS Action,  CAST( 'MNL' AS VARCHAR(5) ) AS GroupAction 
	UNION ALL SELECT 'CAL-HT'		, 'MNL' ----Main
	UNION ALL SELECT 'CAL-FT'		, 'MNL'
	UNION ALL SELECT 'UNDO'			, 'MNL'
	UNION ALL SELECT 'UNDO-FT'			, 'MNL'
	UNION ALL SELECT 'CAL-INST-HT'		, 'MNL'
	UNION ALL SELECT 'CAL-INST-FT'		, 'MNL'
	UNION ALL SELECT 'UNDO-INST-HT'		, 'MNL'
	UNION ALL SELECT 'UNDO-INST-FT'		, 'MNL'
	UNION ALL SELECT 'REFUND'		, 'MNL'
	UNION ALL SELECT 'REFUND-HT'	, 'MNL'
	UNION ALL SELECT 'REFUND-FT'	, 'MNL'
	UNION ALL SELECT 'SDT-FT'		, 'MNL'

	UNION ALL SELECT 'CAL-EARLY'	,'EAR' ---Early
	UNION ALL SELECT 'UNDO-EARLY'	,'EAR'
	UNION ALL SELECT 'REFUND-EARLY'	,'EAR'

	UNION ALL SELECT 'CAL-FM'		,'FM' ----Fasmarket, TimeMachine

	)
GO