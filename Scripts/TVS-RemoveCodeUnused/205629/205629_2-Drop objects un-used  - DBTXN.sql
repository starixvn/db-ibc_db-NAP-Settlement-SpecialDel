/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20240530@July
	Task: Drop Objects un-used  [Redmine:#205629]  
	DB: DBTXN-bodb02
	
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
	name LIKE 'DEL_NAP_SpecialDelete_VoidBetId_CheckAbnormalBet%'
 OR name LIKE 'DEL_Acc_SpecialDel_CheckMatchIDwithRefno%'

 OR name LIKE 'DEL_NAP_SpecialDelete_VoidBetId_CheckVoidBetPermission%'
 OR name LIKE 'DEL_NAP_BettransSpecialDelBetID_Sel%'
 OR	name LIKE 'DEL_Acc_Set_LiveCasino_SpecialDelete_xtest%'
 OR name LIKE 'DEL_NAP_BettransSelSpecialDel' OR name LIKE 'DEL_NAP_BettransSelSpecialDel_UAT%' OR name LIKE 'DEL_NAP_BettransSelSpecialDel_xpre%' or name like 'NAP_BettransSelSpecialDel_xtest%'
 OR	name LIKE 'DEL_Acc_SpecialDelete_CheckPermission%'
 OR	name LIKE 'DEL_NAP_SpecialDelete_VoidSingleBet_CheckVoidBetPermission%'
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
/*FUNCTIONS***********************************************************************************************************/
INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP FUNCTION ' + name
FROM sys.objects
WHERE type IN ('FN', 'IF', 'TF')
 AND (
    name LIKE 'DEL_f_TVS_GroupFilterBettypesConfig%'
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
