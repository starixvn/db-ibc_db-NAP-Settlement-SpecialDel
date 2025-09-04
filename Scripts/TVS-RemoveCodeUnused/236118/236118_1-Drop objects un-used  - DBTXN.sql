/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230827@July
	Task: Drop Objects un-used  [Redmine:#236118]  
	DB: DBTXN-bodb02
	
*/
USE bodb02
GO

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

--DBCTG
IF EXISTS (SELECT * FROM sys.objects WHERE type = 'P' AND name LIKE 'TicketVoiding_TicketRequest_Void_Select%')
BEGIN
	INSERT INTO @tmpDropObjectsName (command)
	SELECT 'DROP PROCEDURE ' + name
	FROM dbo.sysobjects
	WHERE (type = 'P')
	AND name LIKE 'TicketVoiding_TicketRequest_Void_Select%'
END

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'TicketVoiding_TransInfo_1sHDP_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_1sOU_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_AB_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_ACC_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_ADVMode_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_ARC_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_DA_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_HDP_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_KO_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_NP_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_OU_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_RC_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_RO_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_RT_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_WC_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_WO_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_WOName_Select%'

OR  name LIKE 'TicketVoiding_TransInfo_Void_Select%'
OR  name LIKE 'TicketVoiding_TransInfo_VoidARC_Select%'

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


