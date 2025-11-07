/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" isFunction="0"></info>*/

/*
	20251107@Louisa: Enhance performance [Redmine:#243785]

*/
USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_Parlay_Calculate_Queue_IsCalculating] ON [dbo].[Parlay_Calculate_Queue]
(
	IsCalculating ASC
)
GO

