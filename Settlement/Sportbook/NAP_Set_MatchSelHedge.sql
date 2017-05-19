/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
USE [bodb02]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [NAP_Set_MatchSelHedge] @matchid INT
AS
/* Created: 20140114@Kathy
 Task: Select hedging matches correlative real matches    
 DB: DBPRO.bodb02    
 Original SP: [Acc_Set_MatchSelHedge]
     
 Revisions:    
    - 20161219@bobby: #67952 - Check the match whether or not having Over/Under bettypes 
	- 20170210@bobby: #71292 - Check sporttype for hedge match
	
 Param's Explanation:     
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @leagueid INT
		, @homeid INT
		, @awayid INT
		, @eventdate DATETIME

	SELECT @leagueid = leagueid
		, @homeid = homeid
		, @awayid = awayid
		, @eventdate = eventdate
	FROM match WITH (NOLOCK)
	WHERE matchid = @matchid

	SELECT m.matchid
		, m.matchcode
		, CASE WHEN ISNULL(sdt.IsDeterminedHedgeMatch, 0 ) = 1 AND m.sporttype = 1 THEN 1 ELSE 0 END AS IsDeterminedHedgeMatch
	FROM dbo.match m WITH (NOLOCK)
		OUTER APPLY (
			SELECT TOP 1 CAST(1 AS BIT) AS IsDeterminedHedgeMatch
			FROM DBTXN.bodb02.dbo.bettrans WITH(NOLOCK)
			WHERE matchid = m.matchid
				AND bettype IN (3)
				AND ruben = 0
		) AS sdt
	WHERE leagueid = @leagueid
		AND homeid = @homeid
		AND awayid = @awayid
		AND eventdate = @eventdate
		AND matchid <> @matchid
		AND matchcode LIKE '%hedge%'
	ORDER BY matchcode
END
GO

GRANT EXECUTE
	ON [NAP_Set_MatchSelHedge]
	TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION
	ON [NAP_Set_MatchSelHedge]
	TO [vnteam] AS [dbo]
GO


