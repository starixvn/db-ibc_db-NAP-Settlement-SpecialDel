/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230707@July
	Task: Drop Objects un-used [Redmine:#180625]  
	DB:  DBSIC-bodb02

	Note: Action DROP ONLY SITEDB3
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/

IF OBJECT_ID('DEL_LuckyDraw3rd_Log','U') IS NOT NULL 
	DROP TABLE DEL_LuckyDraw3rd_Log
GO
IF OBJECT_ID('DEL_LuckyDraw3rd','U') IS NOT NULL 
	DROP TABLE DEL_LuckyDraw3rd
GO

/*SPS***********************************************************************************************************/

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'DEL_Task_LuckyDraw3rd_Freebets_Insert%'
OR  name LIKE 'DEL_Task_LuckyDraw3rd_Freebets_Select%'
OR  name LIKE 'DEL_Task_LuckyDraw3rd_Freebets_Update%'
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


