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
        - 20200210@Sol: Settlement with Ticket Exclusion for Other Sports - Tennis - [Redmine:#129316]
		- 20200528@Kathy: add resourceid of basketball [Redmine:#134843]
		- 20200805@July:  add resourceid of soccer [Redmine:#138475]
		- 20200908@Louisa: add FT and HT for Soccer [Redmine:#139979]
		- 20210121@Kathy: Cricket AIO [Redmine:#148870]
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
		- 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
   
    Parameters Explanation:        
    
    Example:
        SELECT * FROM dbo.[f_Set_MajorRound](43)
        SELECT * FROM dbo.[f_Set_MajorRound](09)
    
*/
RETURN
(
	SELECT Sporttype, RoundID, RoundName, ResourceID, GroupType, isFinal, OrdNo, AllowDirectly
	FROM
	(
		SELECT CONVERT(SMALLINT, 43)		 AS Sporttype
				, CONVERT(VARCHAR(3), '801') AS RoundID
				, CONVERT(VARCHAR(5), 'M1')  AS RoundName
				, CONVERT(VARCHAR(20), 'M1') AS ResourceID
				, CONVERT(VARCHAR(2), 'HT')  AS GroupType
				, CONVERT(BIT, 0)			 AS isFinal
				, CONVERT(SMALLINT, 1)		 AS OrdNo
				, CONVERT(BIT, 0)			 AS AllowDirectly
	    UNION ALL SELECT 43, '802', 'M2', 'M2', 'HT', 0, 2,  0
	    UNION ALL SELECT 43, '803', 'M3', 'M3', 'HT', 0, 3,  0
	    UNION ALL SELECT 43, '804', 'M4', 'M4', 'FT', 0, 4,  0
	    UNION ALL SELECT 43, '805', 'M5', 'M5', 'FT', 0, 5,  0
	    UNION ALL SELECT 43, '806', 'M6', 'M6', 'FT', 0, 6,  0
	    UNION ALL SELECT 43, '807', 'M7', 'M7', 'FT', 0, 7,  0
	    UNION ALL SELECT 43, '808', 'M8', 'M8', 'FT', 0, 8,  0
	    UNION ALL SELECT 43, '809', 'M9', 'M9', 'FT', 0, 9,  0
	    UNION ALL SELECT 43, '00' , 'FT', '00', 'FT', 1, 99, 1
	    UNION ALL SELECT 9, '801', '1G', '0101', 'SP', 0, 1, 0 --Grouptype = Special
	    UNION ALL SELECT 9, '802', '2G', '0102', 'SP', 0, 2, 0
	    UNION ALL SELECT 9, '803', '3G', '0103', 'SP', 0, 3, 0
	    UNION ALL SELECT 9, '804', '4G', '0104', 'SP', 0, 4, 0
	    UNION ALL SELECT 9, '805', '5G', '0105', 'SP', 0, 5, 0
	    UNION ALL SELECT 9, '00' , 'FT', '00', 'FT', 1, 99,	 1 
		UNION ALL SELECT 5, '801', '1S', '01', 'SP', 0, 1,	 0 --Grouptype = Special
	    UNION ALL SELECT 5, '802', '2S', '02', 'SP', 0, 2,	 0
	    UNION ALL SELECT 5, '803', '3S', '03', 'SP', 0, 3,	 0
	    UNION ALL SELECT 5, '804', '4S', '04', 'SP', 0, 4,	 0
	    UNION ALL SELECT 5, '805', '5S', '05', 'SP', 0, 5,	 0
	    UNION ALL SELECT 5, '00' , 'FT', '00', 'FT', 1, 99,	 1

		UNION ALL SELECT 2, '801' , 'Q1', 'Q1', 'SP', 0, 1,	 0
		UNION ALL SELECT 2, '802' , 'Q2', 'Q2', 'SP', 0, 2,	 0
		UNION ALL SELECT 2, '01' , 'HT', '01', 'HT', 0, 3,	 1
		UNION ALL SELECT 2, '803' , 'Q3', 'Q3', 'SP', 0, 4,	 0
		UNION ALL SELECT 2, '804' , 'Q4', 'Q4', 'SP', 0, 5,	 0		
		UNION ALL SELECT 2, '00' , 'OT', 'OT', 'FT', 0, 6,	 0
		UNION ALL SELECT 2, '00' , 'FT', '00', 'FT', 1, 99,  1

		UNION ALL SELECT 1, '01' , 'HT', '01', 'HT', 0, 1,	 0
		UNION ALL SELECT 1, '09' , 'HT', '09', 'HT', 0, 2,	 0
		UNION ALL SELECT 1, '08' , 'FT', '08', 'FT', 0, 3,	 0
		UNION ALL SELECT 1, '00' , 'FT', '00', 'FT', 1, 99,	 0

		UNION ALL SELECT 50, '01' , 'H1', 'H1', 'SP', 0, 1,	 0
		UNION ALL SELECT 50, '01' , 'A1', 'A1', 'SP', 0, 2,	 0
		UNION ALL SELECT 50, '02' , 'H2', 'H2', 'SP', 0, 3,	 0
		UNION ALL SELECT 50, '02' , 'A2', 'A2', 'SP', 0, 4,	 0
		UNION ALL SELECT 50, '00' , 'FT', '00', 'FT', 1, 99, 0

		UNION ALL SELECT 45, '801', '1S', '0101', 'SP', 0, 1, 0
		UNION ALL SELECT 45, '802', '2S', '0102', 'SP', 0, 2, 0
		UNION ALL SELECT 45, '803', '3S', '0103', 'SP', 0, 3, 0
		UNION ALL SELECT 45, '00' , 'FT', '00', 'FT', 1, 99,  1

		--Sporttype, RoundID, RoundName, ResourceID, GroupType, isFinal, OrdNo, AllowDirectly
		UNION ALL SELECT 6, '801', '1S', '0101', 'SP', 0, 1,  0
		UNION ALL SELECT 6, '802', '2S', '0102', 'SP', 0, 2,  0
		UNION ALL SELECT 6, '803', '3S', '0103', 'SP', 0, 3,  0
		UNION ALL SELECT 6, '804', '4S', '0104', 'SP', 0, 4,  0
		UNION ALL SELECT 6, '805', '5S', '0105', 'SP', 0, 5,  0
		UNION ALL SELECT 6, '00' , 'FT', '00',	 'FT', 1, 99, 1

		UNION ALL SELECT 30, '801', '1S', '0101', 'SP', 0, 1,  0
		UNION ALL SELECT 30, '802', '2S', '0102', 'SP', 0, 2,  0
		UNION ALL SELECT 30, '803', '3S', '0103', 'SP', 0, 3,  0
		UNION ALL SELECT 30, '804', '4S', '0104', 'SP', 0, 4,  0
		UNION ALL SELECT 30, '805', '5S', '0105', 'SP', 0, 5,  0
		UNION ALL SELECT 30, '00' , 'FT', '00',	 'FT', 1, 99, 1

		UNION ALL SELECT 48, '801', '1S', '0101', 'SP', 0, 1,  0
		UNION ALL SELECT 48, '802', '2S', '0102', 'SP', 0, 2,  0
		UNION ALL SELECT 48, '803', '3S', '0103', 'SP', 0, 3,  0
		UNION ALL SELECT 48, '804', '4S', '0104', 'SP', 0, 4,  0
		UNION ALL SELECT 48, '805', '5S', '0105', 'SP', 0, 5,  0
		UNION ALL SELECT 48, '00' , 'FT', '00',	 'FT', 1, 99, 1

		
    ) AS tbl
    WHERE Sporttype = @Sporttype 
)
GO