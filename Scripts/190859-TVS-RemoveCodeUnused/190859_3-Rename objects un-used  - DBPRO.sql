/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221207@July
	Task: Rename Objects un-used - [Redmine:#190859]  
	DB: DBPRO-bodb02
		   
*/
USE bodb02
GO

DECLARE @command VARCHAR(MAX)
DECLARE @tmpRenameObjectsName TABLE ( command VARCHAR(MAX), IsRename BIT)

INSERT INTO @tmpRenameObjectsName (command)
SELECT 'sp_rename ' + name + ', DEL_' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'NAP_EventSelect%'
OR  name LIKE 'Acc_MatchSelByID%'
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
