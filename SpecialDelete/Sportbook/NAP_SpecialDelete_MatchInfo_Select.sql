/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_MatchInfo_Select] 
	@matchID INT = 0,
	@transid BIGINT = 0,
	@IsMatch3rd BIT = 0,	
	@Language VARCHAR(2) = 'E'
AS
/*
	Created: 20180305@Helen
	Task : View match info
	DB: DBPRO/bodb02
	Original:
	Revisions: 
		- 20180305@Helen: Initialize - [Redmine: 90153]
	
*/
BEGIN

	SET NOCOUNT ON
	DECLARE @bettype INT

	IF @matchid=0
		SELECT @matchid = matchid, @bettype = bettype 
		FROM DBTXN.bodb02.dbo.bettrans WITH(NOLOCK) 
		WHERE transid = @transid
	IF @bettype = 10
		SELECT
			match.orid as matchid,
			MATCH.teamid AS homeid,
			0 AS awayid,
			MATCH.matchcode,
			MATCH.eventdate,
			MATCH.leagueid,
			GETDATE() AS DATETIME,
			CONVERT(BIT,0) AS IsNeutral,
			CONVERT(NVARCHAR(50),MATCH.kickofftime) as showtime
		FROM dbo.Outright AS MATCH WITH (NOLOCK)
		WHERE MATCH.orid = @matchID
	ELSE
	BEGIN
		IF @IsMatch3rd = 1
		BEGIN
			SELECT 
					match.Match3rdId AS matchid,
					match.homeid,
					match.awayid,
					NULL AS matchcode, 
					match.eventdate, 
					match.League3rdId leagueid,
					NULL AS IsNeutral,
					NULL AS showtime,
					NULL AS kickofftime,
					match.sporttype
				FROM dbo.Match3rd AS match WITH (NOLOCK) 
				WHERE match.Match3rdId = @matchID
		END
		ELSE
		BEGIN
			SELECT 
					match.matchid,
					match.homeid,
					match.awayid,
					match.matchcode, 
					match.eventdate, 
					match.leagueid,
					isnull(match.isNeutral, CONVERT(BIT,0)) as IsNeutral,
					showtime,
					match.kickofftime,
					match.sporttype
				FROM dbo.match AS match WITH (NOLOCK) 
				WHERE match.matchid = @matchID
		END		
	END		

END
GO
GRANT EXECUTE ON [dbo].[NAP_SpecialDelete_MatchInfo_Select] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_SpecialDelete_MatchInfo_Select] TO [vnteam] AS [dbo]