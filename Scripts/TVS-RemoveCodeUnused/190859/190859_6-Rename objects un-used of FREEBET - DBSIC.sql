/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230707@July
	Task: Rename Objects un-used [Redmine:#180625]  
	DB:  DBSIC-bodb02

	Note: Action DROP ONLY SITEDB3
*/
USE bodb02
GO

/*TABLES***********************************************************************************************************/

IF OBJECT_ID('LuckyDraw3rd_Log','U') IS NOT NULL 
	EXEC sp_rename 'dbo.LuckyDraw3rd_Log','DEL_LuckyDraw3rd_Log';
GO
IF OBJECT_ID('LuckyDraw3rd','U') IS NOT NULL 
	EXEC sp_rename 'dbo.LuckyDraw3rd','DEL_LuckyDraw3rd';
GO

/*SPS***********************************************************************************************************/

DECLARE @command VARCHAR(MAX)
DECLARE @tmpRenameObjectsName TABLE ( command VARCHAR(MAX), IsRename BIT)

INSERT INTO @tmpRenameObjectsName (command)
SELECT 'sp_rename ' + name + ', DEL_' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'Task_LuckyDraw3rd_Freebets_Insert%'
OR  name LIKE 'Task_LuckyDraw3rd_Freebets_Select%'
OR  name LIKE 'Task_LuckyDraw3rd_Freebets_Update%'
)
WHILE (1=1)
BEGIN
	UPDATE TOP (1) @tmpRenameObjectsName
	SET @command = command, IsRename = 1
	WHERE IsRename IS NULL

	IF @@ROWCOUNT = 0 BREAK;
	
	EXEC (@command)

END
SELECT * FROM @tmpRenameObjectsName
