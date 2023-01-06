/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
(
	@RequestId				INT= 0
	,@SiteDBGroupID			SMALLINT = NULL
	,@BroadcastSessionId	VARCHAR(100) = NULL
	,@VoidData				XML = NULL
	,@UserId				INT = 0
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20201202@Charles: Insert data for new VoidData column [Redmine:#143666]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @VoidingHistory_tmp AS TABLE (VoidingHistoryId INT, RequestId INT)

	IF NOT EXISTS (SELECT TOP(1) 1 FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) 
					WHERE v.RequestId = @RequestId AND v.SiteDBGroupID = @SiteDBGroupID AND v.BroadcastSessionId = @BroadcastSessionId
				)
	BEGIN
		INSERT INTO dbo.TicketVoiding_VoidingHistory (
						RequestId
						,UserId
						,StatusId
						,VoidData
						,BroadcastSessionId
						,SiteDBGroupID
				)
			OUTPUT inserted.VoidingHistoryId, inserted.RequestId INTO @VoidingHistory_tmp (VoidingHistoryId, RequestId)
		SELECT @RequestId, @UserId, 1, @VoidData, @BroadcastSessionId, @SiteDBGroupID
	END

	SELECT VoidingHistoryId, RequestId
	FROM @VoidingHistory_tmp

END
GO

