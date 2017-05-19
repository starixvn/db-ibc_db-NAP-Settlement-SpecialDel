
ALTER PROCEDURE [dbo].[Dot_Msg_SetUsrMessage]
	@MessageId int,
	@TargetId int,
	@TargetName nvarchar(50) = '',
	@isRead bit = 0,
	@BetTransId varchar(max) = '',
	@PostTime DATETIME = NULL ,
	@Creator INT =0
AS
/*	Task: Add/Update target message 
	DB: DB07.bodb_Message
	
	Revisions: 
		20120723@Scott(DB07): Set PostTime from Dot_Msg_SetMessage retuen value
		20120920@Jamie: Add @Creator for write log in future 
		20160408@Bobby: #54218 - Extend bettransid to varchar(max)
*/

BEGIN
	IF EXISTS (SELECT MessageId FROM dbo.Msg with (nolock) WHERE MessageId = @MessageId)
	BEGIN
		IF EXISTS (SELECT MessageId FROM dbo.MsgTarget with (nolock) WHERE MessageId = @MessageId AND TargetId = @TargetId)
			BEGIN
				-- update
				UPDATE dbo.MsgTarget WITH (rowlock,updlock)
				SET	TargetName = @TargetName, BetTransId = @BetTransId, isDeleted = 0
				WHERE MessageId = @MessageId 
					AND TargetId = @TargetId
			END
		ELSE
			BEGIN
				-- insert
				INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead, BetTransId ,PostTime) --messagetype: for old version
				VALUES (@MessageId, @TargetId, @TargetName, @isRead, @BetTransId ,@PostTime)
			END
	END
END




GO
GRANT EXECUTE ON [dbo].[Dot_Msg_SetUsrMessage] TO [bodbAdminNet]
GO
GRANT EXECUTE ON [dbo].[Dot_Msg_SetUsrMessage] TO [Dot_Admin]
GO
GRANT VIEW DEFINITION ON [dbo].[Dot_Msg_SetUsrMessage] TO [vnteam]