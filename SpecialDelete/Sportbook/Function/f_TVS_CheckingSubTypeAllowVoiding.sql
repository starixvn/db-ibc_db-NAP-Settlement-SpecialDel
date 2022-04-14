/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_CheckingSubTypeAllowVoiding] ()
RETURNS TABLE
AS
/*
    Created: 20220412@July
    Task: [TVS] Support AB Exclusion by sub issue type
	 DB: DBTXN/bodb02
    Revisions:
		- 20220412@July: [TVS] Support AB Exclusion by sub issue type [Redmine: #170771]
		
    Parameters Explanation:    
		
*/

RETURN (
	SELECT	CONVERT(TINYINT, 1) AS SubTypeId
		   ,CONVERT(VARCHAR(100), 'Abnormal') AS SubTypeName  
		   ,CONVERT(TINYINT, 27) AS SubTypeId_AbnormalBet
		   ,CONVERT(TINYINT, 41) AS SubTypeId_ABRealMember
	UNION ALL SELECT 2,'Group Betting',28,42
	UNION ALL SELECT 3,'Hedging',29,43
	UNION ALL SELECT 4,'Arbitrage',30,44
	UNION ALL SELECT 5,'Arbitrage',31,45
	UNION ALL SELECT 6,'AB Bet',32,46
	UNION ALL SELECT 7,'Robot Betting',36,47
	UNION ALL SELECT 8,'Irrigation Bet',37,48
	UNION ALL SELECT 9,'System Formula Bet',38,49
)
GO