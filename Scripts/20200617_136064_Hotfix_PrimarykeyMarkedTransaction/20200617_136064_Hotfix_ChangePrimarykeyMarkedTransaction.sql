/*
    Created: 20200617@Max
	Task: Hotfix - SD Duplicate insert into MarkedTransaction by Mark Sub Parlay - [Redmine: #136064]
	DB: bodb02 - DBTRANS & Replicated Server for DBTrans_Bet
*/

USE bodb02
GO

ALTER TABLE [dbo].[MarkedTransaction] DROP CONSTRAINT [PK_MarkedTransaction_TransId]

ALTER TABLE [dbo].[MarkedTransaction] ADD CONSTRAINT [PK_MarkedTransaction_TransId_MatchId] PRIMARY KEY ([TransId],[MatchId])
