/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
CREATE PROCEDURE NAP_Set_LetstalkMessage_Insert
(
	@MessageGroupId	TINYINT,
	@MessageTypeId  TINYINT,
	@MatchId		INT, 
	@ActionId		INT				= 0,	
	@MessageContent	VARCHAR(MAX),
	@UserID			INT, 		
	@IP				VARCHAR(15)		= '',	
	@ErrCode		INT 			= 0	 OUTPUT,	
	@ErrMsg			NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Insert Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Insert Letstalk message [Redmine:#157540]

	Param explanation:
		@MessageGroupId 
					1: Instant Settlement
		@MessageTypeId
					1: Warning
					2: Error
		@ActionId: Settlement ActionId
					101: Cal Inst HT
					102: Cal Inst FT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @ActionName		NVARCHAR(512) = ''

	SELECT @ActionName =  l.ActionNameEN 
	FROM dblog.bodb_customerlog.dbo.LogAction l WITH(NOLOCK)
	WHERE l.ActionID = @ActionId

	BEGIN TRY
		INSERT INTO [dbo].[Settlement_LetstalkMessage]
		(	
			 MessageGroupId
			,MessageTypeId		
			,MatchId		
			,ActionId		
			,ActionName		
			,MessageContent	
			,StatusId		
			,CreateDate		
			,CreateBy		
			,LastModifyDate	
			,LastModifyBy		
			,IP
		) 
		SELECT	
			@MessageGroupId
			,@MessageTypeId
			,@MatchId
			,@ActionId
			,ISNULL(@ActionName,'')
			,@MessageContent
			,0
			,GETDATE()
			,@UserID
			,GETDATE()
			,@UserID
			,@IP

	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			, @ErrMsg = ISNULL(ERROR_MESSAGE(), '')
	    RETURN
    END CATCH   

END
GO
