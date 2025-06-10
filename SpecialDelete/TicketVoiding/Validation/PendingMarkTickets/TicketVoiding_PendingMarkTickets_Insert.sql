/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_PendingMarkTickets_Insert]
(	
	 @TransIds				VARCHAR(MAX)
	,@MatchId				DATETIME = NULL
	,@SiteDBGroupID			SMALLINT = 1
)
AS
/*	
	Created by: 20250610@July
	Task: [TVS] Enhance TVS in case 1 or many siteDBs down - Add/Edit request [Redmine: #228047]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20250610@July: Create new SP [Redmine: #228047]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tmpListTransIds TABLE (TransId BIGINT)

	INSERT INTO @tmpListTransIds (TransId)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO dbo.TicketVoiding_PendingMarkTickets (TransId, MatchId, StatusId, SiteDBGroupID)
	SELECT TransId
		  ,@MatchId
		  ,1 -- StatusId = 1 for Running
		  ,@SiteDBGroupID
	FROM @tmpListTransIds

END
GO