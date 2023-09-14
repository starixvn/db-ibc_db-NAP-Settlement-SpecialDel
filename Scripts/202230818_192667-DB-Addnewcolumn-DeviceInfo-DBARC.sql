/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
    Created: 20230818@July
	Task: [TVS] Alpha - Bet List - Add Device info (Desktop/Mobile) [Redmine: #192667]
	DB: DBARC-bodb_Archive 

*/

USE bodb_Archive
GO
--#1: Add new column DeviceType TINYINT, Nullable = Yes
ALTER TABLE dbo.bettrans_bk		ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransLC_bk	ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransRnG_bk	ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransG		ADD DeviceType TINYINT;
ALTER TABLE dbo.translog_bk		ADD DeviceType TINYINT;

GO

--#2: Add new column ExtraInfo VARCHAR(1000), Nullable = Yes
ALTER TABLE dbo.bettransLC_bk	ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransRnG_bk	ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransG		ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.translog_bk		ADD ExtraInfo VARCHAR(1000);
