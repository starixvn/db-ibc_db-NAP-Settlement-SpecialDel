/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250414@July
	Task: Drop Objects un-used  [Redmine:#217771]  
	DB: DBTXN-bodb02
	
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
 --TransInfo
	name LIKE 'DEL_TicketVoiding_TransInfo_1sHDP_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_1sOU_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_ADVMode_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_DA_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_HDP_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_OU_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_RC_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_WC_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_WO_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_WOName_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_KO_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_NP_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_RO_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_ACC_Select%'

---TransInfo_Void
OR  name LIKE 'DEL_TicketVoiding_TransInfo_Void_Select%'
OR  name LIKE 'DEL_TicketVoiding_TransInfo_VoidARC_Select%'
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


