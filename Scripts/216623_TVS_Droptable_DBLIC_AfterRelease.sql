/*<info serverAlias="DBLIC-bodb_Licensee,DBLIC_STANDBY-bodb_Licensee" executers="" isFunction="0"></info>*/
/*	
	Created: 20250206@July
    DB: DBLIC-bodb_Licensee,DBLIC_STANDBY-bodb_Licensee
    Revisions:
		- 20250206@July: Drop table un-used - [Redmine: #216623]
	
	Param's explanation:	
		
*/
USE bodb_Licensee
GO

IF OBJECT_ID (N'LicenseeResultAmendment', N'U') IS NOT NULL
	DROP TABLE dbo.LicenseeResultAmendment

IF OBJECT_ID (N'LicenseeResultAmendmentDetails', N'U') IS NOT NULL
	DROP TABLE dbo.LicenseeResultAmendmentDetails	

DECLARE @command VARCHAR(MAX)
DECLARE @tmpDropObjectsName TABLE ( command VARCHAR(MAX), IsDrop BIT)

INSERT INTO @tmpDropObjectsName (command)
SELECT 'DROP PROCEDURE ' + name
 FROM dbo.sysobjects
 WHERE (type = 'P')
 AND (
	name LIKE 'NAP_SpecialDelete_TicketListing_CleanUpDataSendOIC%'
OR	name LIKE 'NAP_SpecialDelete_TicketListing_SendOIC%'
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

