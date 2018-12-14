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
        
   
    Parameters Explanation:        
    
    Example:
        SELECT * FROM dbo.[f_Set_SettingByProfile](43)
    
*/
RETURN
(
	SELECT Sporttype
	FROM
	(
		SELECT CONVERT(SMALLINT, 43) AS Sporttype
    ) AS tbl
    WHERE Sporttype = @Sporttype 
)
GO