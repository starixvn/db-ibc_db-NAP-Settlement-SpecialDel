USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[f_Set_SetChar] (@data VARCHAR(50)
	,@pos	INT -- minute to store
	,@Char	CHAR(1)
)
RETURNS TABLE 
AS
/*
	Created: 20161101@Kathy
	Task: Fast market
	DB: DBPRO.BODB02
	Original:
	
	Revisions:

	Param's Explanation:
		
*/
RETURN 
(
	WITH ctePos
	AS
	(
		SELECT	@pos + CASE WHEN @pos >= 45 THEN -44 ELSE 1 END AS pos -- Offset Minute Index
				,ISNULL(@data,'') AS data
	)
	SELECT CAST (CASE WHEN pos > 0 THEN CASE 
										WHEN pos <= DATALENGTH(data) THEN LEFT(data,pos-1) + @Char + SUBSTRING(data,pos+1,50)
										ELSE data + REPLACE(SPACE(pos - DATALENGTH(data)-1),' ','0') + @Char
									END
				ELSE data
			END AS VARCHAR(50)) AS data
	FROM ctePos
										
)
