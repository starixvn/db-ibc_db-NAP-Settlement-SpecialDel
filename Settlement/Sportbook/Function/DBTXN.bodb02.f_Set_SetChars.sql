/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_SetChars] (          
	@data			VARCHAR(50)          
	,@strPosChar	VARCHAR(1000) 
)          
RETURNS VARCHAR(50)              
AS          
/*            
	Created: 20170111@Kathy            
	Task: Fast market            
	DB: DBPRO.BODB02            
	Original:            
	         
	Revisions:            
		- 20180227@Kathy: Integrate Fast Market Phase 2 [Redmine:#90632]
		- 20200928@Kathy: Implement New Bettype 228 Time Machine Over/Under [Redmine:#142001]
		- 20201123@Kathy: Add option maxrecursion [Redmine:#143573]
		- 20200610@Helen: fix issue happen on AWS [Redmine:#156734]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
	        
	Param's Explanation:    
		@strPosChar: Pos|Char
      
*/          
BEGIN      
	DECLARE @result VARCHAR(50) = ''      

	;WITH cteResult  
	AS (        
		SELECT	number AS rn  
				,SUBSTRING(@data, number + 1, 1) val  
		FROM	master.dbo.spt_values  
		WHERE	number < DATALENGTH(@data)  
				AND type = 'p'     
	)            
	SELECT	@result = @result + CASE WHEN t.pos IS NOT NULL THEN t.betoption ELSE c.val END  
	FROM	cteResult c        
		LEFT JOIN (       
			SELECT	CAST(SUBSTRING([value], 1,CHARINDEX('|',[value]) - 1) AS TINYINT) AS pos    
					,CAST(SUBSTRING([value],CHARINDEX('|',[value])+1,LEN([value])) AS VARCHAR(10)) AS betoption 
			FROM	STRING_SPLIT(@strPosChar, ',')      
		) t      
		ON	c.rn = t.pos      
	ORDER BY c.rn

	RETURN @result  
END  
GO