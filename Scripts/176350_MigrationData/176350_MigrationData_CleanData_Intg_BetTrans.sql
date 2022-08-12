/*<info serverAlias="DBSIG-IntgTransDB" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220812@Victoria
    Task: Data Migration for SiteDB - Existing Licensee
    DB: DBSIG-IntgTransDB

	 Revisions:
		- 20220812@Victoria: TRUNCATE for table Intg_BetTrans - TW List [Redmineid:#176350]

*/

	USE IntgTransDB
	GO

	TRUNCATE TABLE [dbo].[Intg_BetTrans]