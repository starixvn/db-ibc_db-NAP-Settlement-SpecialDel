/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_SettingByProfile] (@Sporttype SMALLINT)
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20180728@Vicky
    Task: 
    DB: DBTXN/bodb02
    Revisions:
        - 20180728@Vicky: Incorporate eSports 2.0 [Redmine #95874]
        - 20190923@Tiara: BMAIO - Badminton All In One [Redmine #120324]
		- 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200701@Kathy: Incorporate New Bet Types of Basketball - Phase 2 [Redmine:#135846]
		- 20210122@Louisa: Cricket AIO [Redmine:#148870]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
   
    Parameters Explanation:        
    
    Example:
        SELECT * FROM dbo.[f_Set_SettingByProfile](43)
		SELECT * FROM dbo.[f_Set_SettingByProfile](09)-- Badminton
*/
RETURN
(
	SELECT Sporttype, IsMergedParlay
	FROM
	(
		SELECT CONVERT(SMALLINT, 43) AS Sporttype, CONVERT( BIT, 1) AS IsMergedParlay 
		UNION ALL SELECT 9, 1 --Badminton
		UNION ALL SELECT 5, 1 --Tennis
		UNION ALL SELECT 2, 1 --Basketball
		UNION ALL SELECT 50, 1 --Cricket
    ) AS tbl
    WHERE Sporttype = @Sporttype 
)

GO