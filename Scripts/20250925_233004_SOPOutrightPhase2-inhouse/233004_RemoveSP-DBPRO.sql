/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20250925@Hughie
	Task: Apply SOP for Outright phase 2 [Redmine: #233004]
	DB: DBPRO/bodb02

*/
USE bodb02
GO

DROP PROCEDURE [dbo].[Repl_GetResultDetailOutright]
GO
DROP PROCEDURE [dbo].[DR_Repl_PutResultDetailOutright_Dist]
GO