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