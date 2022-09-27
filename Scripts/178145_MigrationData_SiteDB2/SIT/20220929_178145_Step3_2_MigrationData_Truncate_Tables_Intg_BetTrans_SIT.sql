/*<info serverAlias="DBSIG-IntgTransDB" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220927@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-IntgTransDB

	 Revisions:
		- 20220927@Victoria: TRUNCATE for table Intg_BetTrans - TW List [Redmineid:#178145]

*/

	USE IntgTransDB
	GO

	TRUNCATE TABLE [dbo].[Intg_BetTrans]