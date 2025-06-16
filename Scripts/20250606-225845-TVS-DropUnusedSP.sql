/*<info serverAlias="DBACC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250606@Lani
	Task: Drop unused SP - Void By Bet Id [Redmine:#225845]  
	DB: DBACC-bodb02
		   
*/
USE bodb02

DECLARE @Command VARCHAR(MAX)
DECLARE @TmpDropObjectsName TABLE (Command VARCHAR(MAX), IsDrop BIT)
INSERT INTO @TmpDropObjectsName (Command)
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
	SET @Command = Command, IsDrop = 1
	WHERE IsDrop IS NULL
	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@Command)
END