/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Drop SP un-used - Special Delete & TVS  [Redmine:#190859]  
	DB: DBPRO-bodb02
		   
*/
USE bodb02
GO

DECLARE @SPName VARCHAR(MAX)
DECLARE @tmpSPName TABLE ( SPName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpSPName (SPName)
SELECT 'DROP PROCEDURE ' +name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
 name LIKE'NAP_EventSelect%'
OR name LIKE'Acc_MatchSelByID%'
)
SELECT * FROM @tmpSPName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpSPName
	SET @SPName = SPName, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@SPName)

END
