/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTransaction_Insert]
	@TransIds		VARCHAR(MAX)					
	,@MessageId		INT
	,@ReasonId		INT 
	,@MatchId		INT = NULL
AS
/*	Created by: Kathy
	Date 20181212
	Task: voided transaction [Redmine:#106655]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpTransId TABLE (TransId BIGINT)

	INSERT INTO @tmpTransId(TransId)
	SELECT	val
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	INSERT INTO dbo.TicketVoiding_VoidedTransaction (TransId, MessageId, ReasonId, MatchId)
	SELECT TransId, @MessageId, @ReasonId, @MatchId
	FROM	@tmpTransId

END
GO
