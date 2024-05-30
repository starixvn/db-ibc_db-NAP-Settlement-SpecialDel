/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240530@July
	Task: Rename Objects un-used  [Redmine:#205629]  
	DB: DBTXN-bodb02
	
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
	name LIKE 'NAP_SpecialDelete_VoidBetId_CheckAbnormalBet%'
OR  name LIKE 'Acc_SpecialDel_CheckMatchIDwithRefno%'

OR  name LIKE 'NAP_SpecialDelete_VoidBetId_CheckVoidBetPermission%'
OR  name LIKE 'NAP_BettransSpecialDelBetID_Sel%'
OR	name LIKE 'Acc_Set_LiveCasino_SpecialDelete_xtest%'
OR  name LIKE 'NAP_BettransSelSpecialDel' OR name LIKE 'NAP_BettransSelSpecialDel_UAT%' OR name LIKE 'NAP_BettransSelSpecialDel_xpre%' or name like 'NAP_BettransSelSpecialDel_xtest%'
OR	name LIKE 'Acc_SpecialDelete_CheckPermission%'
OR	name LIKE 'NAP_SpecialDelete_VoidSingleBet_CheckVoidBetPermission%'
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


/*FUNCTIONS***********************************************************************************************************/

INSERT INTO @tmpRenameObjectsName (command)
SELECT 'sp_rename ' + name + ', DEL_' + name
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
 AND (
    name LIKE 'f_TVS_GroupFilterBettypesConfig%'
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
