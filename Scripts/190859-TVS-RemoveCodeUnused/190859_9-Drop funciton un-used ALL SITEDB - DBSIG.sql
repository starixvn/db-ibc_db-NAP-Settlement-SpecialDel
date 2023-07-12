/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230706@July
	Task: [TVS] Drop 2 function un-used  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO

--Drop FUNCTION ALL SITEDB
DECLARE @FunctionName VARCHAR(MAX)
DECLARE @tmpFunctionName TABLE ( FNName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpFunctionName (FNName)
SELECT 'DROP FUNCTION ' + name
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
 AND (
    name LIKE 'f_TVS_CheckingIssueTypePHBettypes%'
OR  name LIKE 'f_TVS_CheckingSubIssueTypeIdExcludeBettypes%'
)
SELECT * FROM @tmpFunctionName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpFunctionName
	SET @FunctionName = FNName, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@FunctionName)

END



