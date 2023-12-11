/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Select
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Letstalk message [Redmine:#157540]
		20232811@Aries: Alert KST when match completed but auto settle for FM still off [Redmine:#197532]

	Param explanation:


*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CheckTime DATETIME

	SET @CheckTime =   DATEADD (HOUR, -2, GETDATE())

	SELECT	lm.MessageId
			,lm.MessageGroupId
			,lm.MessageType
			,lm.ActionName
			,lm.MatchId
			,m.LeagueId
			,m.HomeId
			,m.AwayId
			,m.kickofftime
			,lm.MessageContent
			,ISNULL(l.isTest,0) AS IsTest
			,lm.CreatedDate
	FROM [dbo].[Settlement_LetstalkMessage] lm WITH(NOLOCK)
		INNER JOIN dbo.match m WITH(NOLOCK) ON lm.MatchId = m.matchid
		INNER JOIN dbo.League l WITH(NOLOCK) ON l.leagueid = m.leagueid
	WHERE lm.StatusId = 0
		AND lm.CreatedDate >= @CheckTime
	ORDER BY lm.MessageId
END
GO



