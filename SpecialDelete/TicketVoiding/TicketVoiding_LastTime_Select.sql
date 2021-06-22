/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_LastTime_Select]
(	
	@MatchId INT
	,@FilterFromTransTime DATETIME = NULL
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
	DECLARE @LastTime  DATETIME

	SELECT @LastTime = (
					SELECT MAX(ISNULL(b.checktime, b.transdate))
					FROM dbo.bettrans b WITH (NOLOCK)
					WHERE b.matchid = @MatchId
						AND ISNULL(b.checktime, b.transdate) > @FilterFromTransTime
				)

	SELECT ISNULL(@LastTime, @FilterFromTransTime) AS LastTime

END
GO