/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidingHistory_Insert]
(
	 @RequestIds			VARCHAR(MAX) = NULL
	,@SiteDBGroupID			SMALLINT = NULL
	,@BroadcastSessionId	VARCHAR(100) = NULL
	,@VoidData				XML = NULL
	,@UserId				INT = 0
)
AS
/*	Created by: 20181212@Kathy
	Task: view voided ticket [Redmine:#90155]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20201202@Charles: Insert data for new VoidData column [Redmine:#143666]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @DecidedBy NVARCHAR(400) = ''

	DECLARE @VoidingHistory_tmp AS TABLE (VoidingHistoryId INT, RequestId INT)
	DECLARE @RequestId_tmp AS TABLE (RequestId INT)	

	INSERT INTO @RequestId_tmp (RequestId)
	SELECT value FROM STRING_SPLIT (@RequestIds, ',')

	--Add attribute for void instant abnormal account, reduced over
	SET @DecidedBy = (SELECT TOP(1) r.DecidedBy
					FROM @RequestId_tmp t
						INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = t.RequestId
					WHERE r.IssueTypeId IN (13,19) AND r.ActionId = 4)

	IF @DecidedBy <> '' AND @VoidData NOT LIKE '%@DecidedBy%'
	BEGIN
		SET @VoidData.modify('             
					insert attribute DecidedBy {sql:variable("@DecidedBy") }             
					into   (/VoidData)[1] '
				); 
	END

	IF NOT EXISTS ( SELECT TOP(1) 1 
					FROM dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) 
						INNER JOIN @RequestId_tmp r ON v.RequestId = r.RequestId
					WHERE v.SiteDBGroupID = @SiteDBGroupID AND v.BroadcastSessionId = @BroadcastSessionId
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
		SELECT RequestId, @UserId, 1, @VoidData, @BroadcastSessionId, @SiteDBGroupID
		FROM @RequestId_tmp
	END

	SELECT VoidingHistoryId, RequestId
	FROM @VoidingHistory_tmp

END
GO

