/*<info serverAlias="DBOIC-bodb_OIC" executers="" isFunction="0"></info>*/
/*
    Created: 20250122@July
	Task: Integrate - Change DB for sending data to OIC - Sync data from DBLIC to DBOIC - [Redmine: #216623]
	DB: DBOIC-bodb_OIC
*/

USE bodb_OIC
GO

SET IDENTITY_INSERT [dbo].[LicenseeResultAmendment] ON;

INSERT INTO [dbo].[LicenseeResultAmendment] (ResultID,SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate)
SELECT ResultID,SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate
FROM [DBLIC].[bodb_Licensee].[dbo].[LicenseeResultAmendment]

SET IDENTITY_INSERT [dbo].[LicenseeResultAmendment] OFF;
GO

INSERT INTO [LicenseeResultAmendmentDetails] (ResultID, TransID, CustID, Recommend)
SELECT ResultID, TransID, CustID, Recommend
FROM [DBLIC].[bodb_Licensee].[dbo].[LicenseeResultAmendmentDetails]