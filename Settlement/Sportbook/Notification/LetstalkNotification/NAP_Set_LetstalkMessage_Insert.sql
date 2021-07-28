/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Insert
(
	@MessageGroupId	TINYINT,
	@MessageType	VARCHAR(100),
	@MatchId		INT, 
	@ActionName		VARCHAR(512),		
	@MessageContent	VARCHAR(MAX),
	@UserID			INT,
	@ErrCode		INT 			= 0	 OUTPUT,	
	@ErrMsg			NVARCHAR(200) 	= '' OUTPUT
)
AS
/*
	Created by: Louisa
	Date: 20210706
	Task: Letstalk message [Redmine:#157540]
	DB: DBTXN/bodb02

	Revisions:
		20210706@Louisa: Insert Letstalk message [Redmine:#157540]
		20210727@Louisa: Letstalk message: Confirmed HT/FT, Completed with early running tickets [Redmine:#158331]	

	Param explanation:
		@MessageGroupId 
					1: Instant Settlement
					2: Settlement
		@MessageType
					Warning
					Error
					Reminder
		@ActionName: HT Auto Instant
					 FT Auto Instant
					 HT Score confirmed
					 FT Score confirmed
					 Completed match with 'Running' tickets		
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
				,0
				,GETDATE()
				,@UserID
				,GETDATE()
			WHERE NOT EXISTS (
						SELECT TOP 1 1 
						FROM Settlement_LetstalkMessage l
						WHERE l.MatchId = @MatchId
							AND l.MessageGroupId =  @MessageGroupId
							AND l.ActionName =  @ActionName
							AND l.MessageGroupId <> 1
									)

		END TRY
		BEGIN CATCH
			SELECT @ErrCode = @@ERROR
				, @ErrMsg = ISNULL(ERROR_MESSAGE(), '')
			RETURN
		END CATCH 

END
GO