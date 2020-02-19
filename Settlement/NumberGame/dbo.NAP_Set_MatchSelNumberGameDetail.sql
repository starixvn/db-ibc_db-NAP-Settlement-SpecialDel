/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchSelNumberGameDetail]
	@matchid int	
AS
/*
	Created: 20121203@Dan
	Task: Get detail info of a number game match
	DB: DBPRO.bodb02  
	Original: 
  
	Revisions:   
		- 20150226@Kathy: Don't show match in match14 [Redmine:#29990]
		- 20200218@Sol: : Incorporate Number Game - Color Ball - Move to DBPRO [Redmine:#128203]

	Param explanation:  
	
*/  
BEGIN
	SET NOCOUNT ON  

	SELECT   	
		m.matchid,
		m.matchcode,  	 
		m.kickofftime,	
		b.seq,
		CAST(b.number AS VARCHAR(20)) AS number,
		b.Color
	FROM  
	   (
			SELECT matchid, matchcode, kickofftime
			FROM MATCH (NOLOCK)  
			WHERE	matchid=@matchid
	   )AS m 
		LEFT OUTER JOIN (
							SELECT matchid, seq, number, Color FROM bingoball(NOLOCK)
					) AS B ON B.matchid = m.matchid
	ORDER BY b.seq

END
GO