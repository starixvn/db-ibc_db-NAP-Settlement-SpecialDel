/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="wsv_nap" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Insert
(
	@MessageGroupId	TINYINT,
	@MessageType	VARCHAR(100),
	@MatchId		INT, 
	@StatusId		TINYINT =  0,
	@ActionName		VARCHAR(512),		
	@MessageContent	VARCHAR(MAX),
	@MessageDetail  VARCHAR(MAX),
	@UserID			INT,
	@ErrCode		INT 			= 0	 OUTPUT,	
	@ErrMsg			NVARCHAR(200) 	= '' OUTPUT,
	@MessageId		INT 			= NULL OUTPUT
)
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBCTG-bodb02,DBSIG-bodb02

	Revisions:
		- 20210706@Louisa: Insert Letstalk message [Redmine:#157540]
		- 20240605@Louisa:Notify if not yet refund [Redmine:#204909] 

	Param explanation:
		@MessageGroupId 
					1: Instant Settlement 
					2: Comfirm Refund
		@MessageTypeId
					Warning
					Error
		@ActionId: Settlement ActionId
					101: Cal Inst HT
					102: Cal Inst FT
					81018, 81032: Comfirm Refund
		@StatusId: 255 - for notify confirmed refund over XX minutes but do not take action Refund
					1 - for another notify
*/
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		INSERT INTO [dbo].[Settlement_LetstalkMessage]
		(	
			MessageGroupId		
			,MessageType
			,MatchId		
			,ActionName		
			,MessageContent
			,MessageDetail
			,StatusId
			,CreatedDate		
			,CreatedBy		
			,LastModifiedDate
		) 
		SELECT	
			@MessageGroupId
			,@MessageType
			,@MatchId
			,@ActionName
			,@MessageContent
			, CASE WHEN @MessageGroupId = 1 THEN 'Inst Settlement'
					ELSE ''
			  END
			,@StatusId
			,GETDATE()
			,@UserID
			,GETDATE()

		SELECT @MessageId = SCOPE_IDENTITY()

	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			, @ErrMsg = ISNULL(ERROR_MESSAGE(), '')
	    RETURN
    END CATCH   

END
GO
