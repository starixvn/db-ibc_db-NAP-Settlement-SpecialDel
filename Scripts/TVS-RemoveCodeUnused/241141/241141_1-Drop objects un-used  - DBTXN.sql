/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20251120@July
	Task: Drop Objects un-used  [Redmine:#241141]  
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
*/
USE bodb02
GO

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'NAP_SpecialDelete_VoidByCurrency_Select%'
OR  name LIKE 'NAP_SpecialDelete_VoidByCurrency_Update%'
)

SELECT command FROM @tmpDropObjectsName
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpDropObjectsName
	SET @command = command, IsDrop = 1
	WHERE IsDrop IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC sys.sp_executesql @command

END


