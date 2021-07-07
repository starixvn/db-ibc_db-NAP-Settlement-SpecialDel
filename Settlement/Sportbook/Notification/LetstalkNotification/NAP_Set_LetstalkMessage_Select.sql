/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE NAP_Set_LetstalkMessage_Select
	@MessageGroupId TINYINT = 0
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Insert Letstalk message [Redmine:#157540]

	Param explanation:
		@MessageGroupId
					0: All new message
					1: Instant Settlement
*/
BEGIN
	SET NOCOUNT ON;

	SELECT	lm.MessageId
			,CASE lm.MessageGroupId 
				WHEN 1 THEN 'Instant Settlement'
				ELSE ''
			 END AS MessageGroupName
			,lm.ActionId
			,lm.ActionName
			,lm.MatchId
			,m.LeagueId
			,m.HomeId
			,m.AwayId
			,m.kickofftime
			,lm.MessageContent
			,lm.CreateDate
	FROM [dbo].[Settlement_LetstalkMessage] lm WITH(NOLOCK)
		INNER JOIN dbo.Match m WITH(NOLOCK) 
			ON lm.MatchId = m.matchid
	WHERE l.StatusId = 0
		AND ( @MessageGroupId = 0 OR lm.MessageGroupId = @MessageGroupId)
END
GO



