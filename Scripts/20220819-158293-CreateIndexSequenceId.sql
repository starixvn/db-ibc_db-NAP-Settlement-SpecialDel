/*<info serverAlias="DBTP-bodb02"></info>*/
USE [bodb02]
GO
/*
	Created: 20220819@Max
	DB: DBTP-bodb02
	Task: Create indexes SequenceID for Detect Bet [RedmineID: #158293]
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
