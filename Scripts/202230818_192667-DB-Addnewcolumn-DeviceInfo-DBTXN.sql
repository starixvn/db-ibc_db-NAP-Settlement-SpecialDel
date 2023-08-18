/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230818@July
	Task: [TVS] Alpha - Bet List - Add Device info (Desktop/Mobile) [Redmine: #192667]
	DB: DBTXN-bodb02

	Note: Sitedb1,2,3 & central DBTRANS & all replicated servers
*/

USE bodb02
GO
--#1: Add new column DeviceType TINYINT, Nullable = Yes
ALTER TABLE dbo.bettrans	ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransLC	ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransRnG ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransG	ADD DeviceType TINYINT;
ALTER TABLE dbo.translog	ADD DeviceType TINYINT;

ALTER TABLE dbo.bettrans14	  ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransLC14  ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransRnG14 ADD DeviceType TINYINT;
ALTER TABLE dbo.bettransG14	  ADD DeviceType TINYINT;
ALTER TABLE dbo.translog14	  ADD DeviceType TINYINT;

GO

--#2: Add new column ExtraInfo VARCHAR(1000), Nullable = Yes
ALTER TABLE dbo.bettransLC	ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransRnG ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransG	ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.translog	ADD ExtraInfo VARCHAR(1000);

ALTER TABLE dbo.bettransLC14  ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransRnG14 ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.bettransG14	  ADD ExtraInfo VARCHAR(1000);
ALTER TABLE dbo.translog14	  ADD ExtraInfo VARCHAR(1000);

