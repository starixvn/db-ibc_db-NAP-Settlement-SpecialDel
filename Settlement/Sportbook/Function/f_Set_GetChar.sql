USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER FUNCTION [dbo].[f_Set_GetChar] (@data VARCHAR(50)
	,@pos	INT -- minute to store
)
RETURNS TABLE 
AS
/*
	Created: 20161101@Kathy
	Task: Fast market
	DB: DBPROD.BODB02/DBTXN.BODB02
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
	SELECT	CASE 
				WHEN pos <=0 OR pos > DATALENGTH(data) THEN '0'
				ELSE SUBSTRING(data, pos, 1)
			END	AS char		
	FROM	ctePos										
)
