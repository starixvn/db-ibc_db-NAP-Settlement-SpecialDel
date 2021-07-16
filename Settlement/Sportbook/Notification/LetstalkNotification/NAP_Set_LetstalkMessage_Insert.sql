/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Insert
(
	@MessageGroupId	TINYINT,
	@MessageType	VARCHAR(100),
	@MatchId		INT				= NULL, 
	@ActionName		VARCHAR(512)	= NULL,		
	@MessageContent	VARCHAR(MAX)	= NULL,
	@UserID			INT				= 0,
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

	Param explanation:
		@MessageGroupId 
					1: Instant Settlement
		@MessageType
					Warning
		@ActionId: Settlement ActionId
					101: Cal Inst HT
					102: Cal Inst FT
*/
BEGIN
	SET NOCOUNT ON;

	IF (@MessageGroupId = 1) ---erorr message from Instant Settlement
	BEGIN
		EXEC NAP_Set_LetstalkMessage_Inst_Insert
			@MessageGroupId	 = @MessageGroupId	
			,@MessageType	 = @MessageType	
			,@MatchId		 = @MatchId		
			,@ActionName	 = @ActionName		
			,@MessageContent = @MessageContent	
			,@UserID		 = @UserID			
			,@ErrCode		 = @ErrCode OUTPUT
			,@ErrMsg		 = @ErrMsg  OUTPUT

	END

	ELSE
	RETURN		


END
GO
