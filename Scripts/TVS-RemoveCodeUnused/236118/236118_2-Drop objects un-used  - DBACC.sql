/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250827@July
	Task: Drop Objects un-used  [Redmine:#236118]  
	DB: DBACC-bodb02
	
*/
USE bodb02
GO
/*SPS***********************************************************************************************************/
DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'NAP_CustomerSelInfoByUsername%'
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
