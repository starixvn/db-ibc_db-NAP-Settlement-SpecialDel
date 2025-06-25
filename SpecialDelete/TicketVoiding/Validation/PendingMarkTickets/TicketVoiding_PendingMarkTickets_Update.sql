/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_PendingMarkTickets_Update]
(	
	 @RequestId		        INT	 = NULL
	,@StatusId		        SMALLINT = NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@SiteDBGroupID			SMALLINT = 0
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
	SELECT value AS TransId
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	UPDATE dbo.TicketVoiding_PendingMarkTickets WITH (ROWLOCK, UPDLOCK)
	SET RequestId = @RequestId
	   ,StatusId = @StatusId
	WHERE TransId IN (SELECT TransId FROM @tmpListTransIds)
	  AND SiteDBGroupID = @SiteDBGroupID
	  AND StatusId IN (1) -- Only Running
END
GO