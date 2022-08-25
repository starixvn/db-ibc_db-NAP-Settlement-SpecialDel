/*<info serverAlias="DBTXN-bodb02,DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBBAL-bodb02,DBTP-bodb02"></info>*/
USE [bodb02]
GO
/*
	Created: 20220819@Max
	DB: DBCTG-bodb02,DBSIG-bodb02,DBEXT-bodb02,DBACC-bodb02,DBBOF-bodb02,DBBAL-bodb02,DBTP-bodb02
	Task: Create indexes SequenceID [RedmineID: #158293]
*/
CREATE NONCLUSTERED INDEX IX_sequenceid ON bettrans (sequenceid) ON Bettrans_index3
GO
CREATE NONCLUSTERED INDEX IX_sequenceid ON translog (sequenceid) ON translog_index
GO
CREATE NONCLUSTERED INDEX IX_sequenceid ON bettransRnG (sequenceid) ON bettransRnG_index
GO
CREATE NONCLUSTERED INDEX IX_sequenceid ON bettransLC (sequenceid) ON bettransLC_index
GO
CREATE NONCLUSTERED INDEX IX_sequenceid ON bettransG (sequenceid) ON BettransG_index
GO
