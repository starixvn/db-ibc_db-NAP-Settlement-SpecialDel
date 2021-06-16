/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LastTime_Select]
(	
	@MatchId INT
	,@Livehomescore SMALLINT = NULL	
	,@Liveawayscore SMALLINT = NULL
)
AS
/*	
	Created by: Max
	Date 20210616
	Task: [TVS] Wrong Score Enhancement 1 [Redmine: #140953]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20210616@Max: Create new SP [Redmine: #156349]
	
	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	SELECT MAX(ISNULL(b.checktime, b.transdate)) AS LastTime
	FROM dbo.bettrans b WITH (NOLOCK)
	WHERE b.matchid = @MatchId

END
GO