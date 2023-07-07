/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230707@July
	Task: Drop SP un-used - Special Delete & TVS  [Redmine:#180625]  
	DB:  DBSIC-bodb02
*/
USE bodb02
GO

/*	Note: Action DROP ONLY SITEDB3 */
-------------------------------------------------------------
IF OBJECT_ID('LuckyDraw3rd_Log','U') IS NOT NULL 
	DROP TABLE LuckyDraw3rd_Log
GO
IF OBJECT_ID('LuckyDraw3rd','U') IS NOT NULL 
	DROP TABLE LuckyDraw3rd
GO
-------------------------------------------------------------

DECLARE @SPName VARCHAR(MAX)
DECLARE @tmpSPName TABLE ( SPName VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpSPName (SPName)
SELECT 'DROP PROCEDURE ' +name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE'Task_LuckyDraw3rd_Freebets_Insert%'
OR  name LIKE'Task_LuckyDraw3rd_Freebets_Select%'
OR  name LIKE'Task_LuckyDraw3rd_Freebets_Update%'
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
