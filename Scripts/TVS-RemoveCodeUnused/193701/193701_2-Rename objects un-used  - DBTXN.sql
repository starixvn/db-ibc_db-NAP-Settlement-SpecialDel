/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230921@July
	Task: Rename Objects un-used  [Redmine:#193701]  
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
	name LIKE 'TicketVoiding_Request_AutoVoidQueue_Insert%'
OR  name LIKE 'NAP_RollbackCricketList%'

OR  name LIKE 'NAP_BettransSelSpecialDel_EarlyKO%'
OR  name LIKE 'NAP_BettransDelSpecialDel_EarlyKO%'

OR  name LIKE 'NAP_BettransSelSpecialDel_MixParlay%'
OR  name LIKE 'NAP_SpecialDelete_VoidParlayBet_Update%'

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
