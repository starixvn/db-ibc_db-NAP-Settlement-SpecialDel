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
		@Action: REFUND, REFUND-FT
  
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT	BetType
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	IsDetermined = 1
			AND 1 = CASE 
						WHEN @Type IN ('BetDaq', 'BetFair') AND BetType NOT IN (302, 304) THEN 1
						WHEN @Type = 'Normal' THEN 1
						ELSE 0
					END
			AND 1 = CASE
						WHEN @Action = 'REFUND-FT' AND GroupId = 2 THEN 1
						WHEN @Action = 'REFUND' THEN 1
						ELSE 0
					END 
						
	
END
GO