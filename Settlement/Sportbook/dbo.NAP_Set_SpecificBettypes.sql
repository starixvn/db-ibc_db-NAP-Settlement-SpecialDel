/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SpecificBettypes
	@Type VARCHAR(10) 
	,@Action VARCHAR(20)
AS
/*  
	Created: 20170920@Kathy  
	Task: get specific bettypes 
	DB: DBPRO/BODB02  

	Revisions:  
		- 20170920@Kathy: get specific bettypes [Redmine:#83261]
		
	Param explanation:  
		@Type: Normal, BetDaq, BetFair
		@Action: ALL, REFUND, REFUND-FT
  
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	BetType
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId BETWEEN 1 AND 6
			AND 1 = CASE 
						WHEN @Type IN ('BetDaq', 'BetFair') AND BetType NOT IN (302, 304) THEN 1
						WHEN @Type = 'Normal' THEN 1
						ELSE 0
					END
			AND 1 = CASE
						WHEN @Action = 'REFUND-FT' AND 2 & DeterminedType > 0 THEN 1
						WHEN @Action = 'REFUND' AND 1 & DeterminedType > 0 THEN 1
						WHEN @Action = 'ALL' AND DeterminedType > 0 THEN 1
						ELSE 0
					END 
	ORDER BY BetType
						
	
END
GO