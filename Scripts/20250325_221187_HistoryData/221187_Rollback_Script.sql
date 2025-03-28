/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250324@Aries
	Task: Enhance data history when updating events and results  [Redmine:#221187]
	DB: DBTP/bodb02
*/

USE bodb02
GO
DISABLE TRIGGER [dbo].[Match3rd_Upd] ON [Match3rd];
DISABLE TRIGGER [dbo].[VSOutright_Upd] ON [VSOutright];
DISABLE TRIGGER [dbo].[VSRaceInfo_Upd] ON [VSRaceInfo];