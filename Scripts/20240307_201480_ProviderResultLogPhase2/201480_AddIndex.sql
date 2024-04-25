/*<info serverAlias="DBTP-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240307@Aries
	Task: Enhance the Provider Result Logs Phase 2 [Redmine: #201480]
	DB: DBTP/bodb02
*/
USE bodb02
GO
CREATE NONCLUSTERED INDEX IX_SettlementResultDetailHistory_MatchIdResourceId ON dbo.SettlementResultDetailHistory (MatchId,ResourceId)
