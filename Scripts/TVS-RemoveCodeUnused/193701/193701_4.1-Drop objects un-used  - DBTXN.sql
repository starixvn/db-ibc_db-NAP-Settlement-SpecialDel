/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230921@July
	Task: Drop Objects un-used  [Redmine:#190859]  
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
	name LIKE 'DEL_TicketVoiding_Request_AutoVoidQueue_Insert%'
OR  name LIKE 'DEL_NAP_RollbackCricketList%'

OR  name LIKE 'DEL_NAP_BettransSelSpecialDel_EarlyKO%'
OR  name LIKE 'DEL_NAP_BettransDelSpecialDel_EarlyKO%'

OR  name LIKE 'DEL_NAP_BettransSelSpecialDel_MixParlay%'
OR  name LIKE 'DEL_NAP_SpecialDelete_VoidParlayBet_Update%'
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


