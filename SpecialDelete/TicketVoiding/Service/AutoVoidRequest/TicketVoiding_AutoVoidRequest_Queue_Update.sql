/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoidRequest_Queue_Update]
(
	@QueueId INT
	,@StatusId INT = NULL
	,@ErrMsg VARCHAR(1000) = NULL
	,@IsUpdateStartTime BIT = 0
)
AS
/*	
	Created by: Max
	Date 20220727
	Task: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	UPDATE q SET 
		q.StatusId = ISNULL(@StatusId, q.StatusId)
		,q.CreatedDate = CASE WHEN @IsUpdateStartTime = 1 THEN GETDATE() ELSE q.CreatedDate END
		,q.ModifiedDate = GETDATE()
		,q.ErrMsg = @ErrMsg		
	FROM dbo.TicketVoiding_AutoVoidQueue q WITH (ROWLOCK, UPDLOCK)
	WHERE q.QueueId = @QueueId	

END		
GO


