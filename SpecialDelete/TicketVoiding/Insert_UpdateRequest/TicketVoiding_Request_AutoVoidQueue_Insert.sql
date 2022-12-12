/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_AutoVoidQueue_Insert]
(
	@RequestId				INT
   ,@IssueTypeId			TINYINT	= NULL
   ,@MatchId				INT
   ,@ActionID				TINYINT = NULL
   ,@FilterBy				TINYINT = NULL
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Insert auto void queue [Redmine: #175412]
		- 20220922@Max: Fix Issue insert queue - [Redmine: #175412 ]
		- 20220923@July: Fix case auto void wininng insert all server for slow settle site [Redmine: #175412]
		- 20221201@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
		+ @IssueTypeId : 11 - Abnormal Bet, 15 - AB(real member), 13 - Abnormal account
*/
BEGIN
	SET NOCOUNT ON

	IF @IssueTypeId = 13 
	BEGIN
		INSERT INTO dbo.TicketVoiding_AutoVoidQueue(RequestId, MatchId, [Action], StatusId, UserId, IP)
		SELECT @RequestId, 0, 'VoidInstant', 0, 10278938, '125.227.140.97'
	END
	ELSE IF @IssueTypeId IN (11,15)
	BEGIN
		-- Insert queue for auto void
		IF @ActionId IN (4,6,7,8) OR (@ActionID = 1 AND @FilterBy IS NULL)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidQueue(RequestId, MatchId, [Action], StatusId, UserId, IP)
			SELECT @RequestId
					, @MatchId
					, CASE WHEN @ActionId = 1 THEN 'AddRequest' 
						   WHEN @ActionId = 4 THEN 'VoidInstant'
						   WHEN @ActionId = 6 THEN 'VoidInstant5m'
						   WHEN @ActionId = 7 THEN 'VoidInstant10m' 
						   WHEN @ActionId = 8 THEN 'VoidInstantNopolicy'
						ELSE '' END 
			      , 0, 10278938, '125.227.140.97'
		END
	END

END
GO