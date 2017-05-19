USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Set_MatchSelNumberGameDetail]    Script Date: 02/26/2015 10:23:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelNumberGameDetail]
	@matchid int	
AS
/*
Created: 20121203@Dan
Task: Get detail info of a number game match
DB: DB053.bodb02  
Original: 
  
Revisions:   
	- 20150226@Kathy: Don't show match in match14 [Redmine:#29990]


Param explanation:  
	
*/  
  
SET NOCOUNT ON  

SELECT   	
	m.matchid,
	m.matchcode,  	 
	m.kickofftime,	
	b.seq,
	CAST(b.number AS VARCHAR(20)) AS number
FROM  
   (SELECT matchid, matchcode, kickofftime
	FROM MATCH (NOLOCK)  
    WHERE	matchid=@matchid
	--UNION ALL  
	--SELECT matchid, matchcode, kickofftime
	--FROM match14 (NOLOCK)  
	--WHERE matchid=@matchid
   )AS m 
	LEFT OUTER JOIN (SELECT matchid, seq, number FROM bingoball(NOLOCK)
				--UNION ALL
				--SELECT matchid, seq, number FROM bingoball14(NOLOCK)
				) AS B ON B.matchid = m.matchid
ORDER BY b.seq
  
  

GO
GRANT EXECUTE ON [dbo].[NAP_Set_MatchSelNumberGameDetail] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Set_MatchSelNumberGameDetail] TO [vnteam] AS [dbo]