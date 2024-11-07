/*<info serverAlias="DBOIC-bodb_OIC" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240408@July
	Task: Drop Objects un-used  [Redmine:#187408]  
	DB: DBOIC-bodb_OIC
	
*/
USE bodb_OIC
GO

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'NAP_SpecialDelete_VoidByCurrency_SelectLicensees%'
)

SELECT * FROM @tmpDropObjectsName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpDropObjectsName
	SET @command = command, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@command)

END


