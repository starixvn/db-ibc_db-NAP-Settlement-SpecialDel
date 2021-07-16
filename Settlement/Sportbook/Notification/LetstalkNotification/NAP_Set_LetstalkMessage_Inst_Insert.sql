/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Set_LetstalkMessage_Inst_Insert
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
					Error
		@ActionId: Settlement ActionId
					101: Cal Inst HT
					102: Cal Inst FT
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @CheckTime DATETIME
	SET @CheckTime =   DATEADD (HOUR, -2, GETDATE())

	BEGIN TRY
		IF @MatchId IS NOT NULL
		BEGIN
			
			IF @ActionName IS NULL OR @MessageContent IS NULL
			BEGIN
				SELECT @ErrCode = 1001054
					   ,@ErrMsg	= 'SQL parameters are missing'
				RETURN
			END

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
				,'Inst Settlement'
				,0
				,GETDATE()
				,@UserID
				,GETDATE()
		END

		ELSE
		BEGIN
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
				,sm.Matchid
				,CASE WHEN sm.Action = 'INST-HT' THEN 'HT Auto Instant'
					  WHEN sm.Action = 'INST-FT' THEN 'FT Auto Instant'
				 ELSE '' END
				,sm.Message
				,'Inst Settlement-Settled_Message'
				,0
				,sm.Starttime
				,sm.AdminId
				,sm.Starttime
			FROM dbo.Settled_Message sm WITH(NOLOCK)
			WHERE sm.Action IN ( 'INST-HT','INST-FT')
				AND sm.AdminId = 0 --- Auto Settle INST
				AND sm.Starttime >= @CheckTime
				AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.Settlement_LetstalkMessage s WHERE s.MatchId = sm.Matchid AND s.CreatedDate = sm.Starttime)
		END

	END TRY

	BEGIN CATCH
		SELECT @ErrCode = @@ERROR
			, @ErrMsg = ISNULL(ERROR_MESSAGE(), '')
	    RETURN
    END CATCH   

END
GO
