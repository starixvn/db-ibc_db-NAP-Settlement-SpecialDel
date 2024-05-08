/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/

/*
	Created by: 20240508@Louisa
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240508@Louisa: Grant Permission [Redmine:#202309]
  
*/


USE [ActivityDB]
GO

	CREATE USER [wsv_nap] FOR LOGIN [wsv_nap]  WITH DEFAULT_SCHEMA=[dbo]

	GRANT SELECT ON [dbo].[LuckyDrawPoolPrize] TO [wsv_nap]

	GRANT SELECT ON [dbo].[LuckyDrawSetting] TO [wsv_nap]