/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_MajorRound] (@Sporttype SMALLINT)
RETURNS TABLE
WITH SCHEMABINDING
AS

/*
    Created: 20180728@Vicky
    Task: 
    DB: DBTXN/bodb02; DBPRO/bodb02
    Revisions:
        - 20180728@Vicky: ESPort [Redmine #95874]
        - 20190923@Tiara: BMAIO - Badminton All In One [Redmine #120324]
        
   
    Parameters Explanation:        
    
    Example:
        SELECT * FROM dbo.[f_Set_MajorRound](43)
        SELECT * FROM dbo.[f_Set_MajorRound](09)
    
*/
RETURN
(
	SELECT Sporttype, RoundID, RoundName, ResourceID, GroupType, isFinal, OrdNo
	FROM
	(
		SELECT CONVERT(SMALLINT, 43) AS Sporttype
				, CONVERT(VARCHAR(3), '801') AS RoundID
				, CONVERT(VARCHAR(5), 'M1') AS RoundName
				, CONVERT(VARCHAR(20), 'M1') AS ResourceID
				, CONVERT(VARCHAR(2), 'HT') AS GroupType
				, CONVERT(BIT, 0) AS isFinal
				, CONVERT(SMALLINT, 1) AS OrdNo
	    UNION ALL SELECT 43, '802', 'M2', 'M2', 'HT', 0, 2
	    UNION ALL SELECT 43, '803', 'M3', 'M3', 'HT', 0, 3
	    UNION ALL SELECT 43, '804', 'M4', 'M4', 'FT', 0, 4
	    UNION ALL SELECT 43, '805', 'M5', 'M5', 'FT', 0, 5
	    UNION ALL SELECT 43, '806', 'M6', 'M6', 'FT', 0, 6
	    UNION ALL SELECT 43, '807', 'M7', 'M7', 'FT', 0, 7
	    UNION ALL SELECT 43, '808', 'M8', 'M8', 'FT', 0, 8
	    UNION ALL SELECT 43, '809', 'M9', 'M9', 'FT', 0, 9
	    UNION ALL SELECT 43, '00' , 'FT', '00', 'FT', 1, 99
	    UNION ALL SELECT 9, '801', '1G', '0101', 'HT', 0, 1
	    UNION ALL SELECT 9, '802', '2G', '0102', 'HT', 0, 2
	    UNION ALL SELECT 9, '803', '3G', '0103', 'HT', 0, 3
	    UNION ALL SELECT 9, '804', '4G', '0104', 'HT', 0, 4
	    UNION ALL SELECT 9, '805', '5G', '0105', 'HT', 0, 5
	    UNION ALL SELECT 9, '00' , 'FT', '00', 'FT', 1, 99
    ) AS tbl
    WHERE Sporttype = @Sporttype 
)
GO