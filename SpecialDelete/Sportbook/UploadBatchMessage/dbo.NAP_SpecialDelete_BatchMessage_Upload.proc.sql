/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap,Dot_Admin" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_BatchMessage_Upload]
	@XMLMessage			XML
	, @CreatorId		INT		
	, @ErrorCode		INT = 0 OUTPUT
	, @ErrorMsg			VARCHAR(200) = '' OUTPUT
AS
/*	Created:20160317@bobby.nguyen
	Task: #54218 - Upload bacth message enhancement
	DB: DBMSG.bodb_Message
	
	Revisions: 
		- 20160317@Bobby: Init Upload bacth message
	
	Param's explanation:
		- @BatchMessage: XML.format(N'<Messages><Item MessageId="123" TargetId="345" TargetName="XZX" BetTransId="123,321,456,..." /></Messages>')
*/

BEGIN

	SET NOCOUNT ON
	
	DECLARE @PostTime 		DATETIME
	
	CREATE TABLE #msgTarget (
		MessageId 		INT
		,TargetId 		INT
		,TargetName 	NVARCHAR(30)
		,BetTransId 	VARCHAR(MAX)
	)
	
	SELECT @PostTime 	= CURRENT_TIMESTAMP
		, @ErrorCode	= 0
		, @ErrorMsg	 	= ''
	
	BEGIN TRY
		INSERT INTO #msgTarget
		SELECT Msg.Item.value('@MessageId', 'int') AS MessageId
			, Msg.Item.value('@TargetId', 'int') AS MessageId
			, Msg.Item.value('@TargetName', 'nvarchar(30)') AS MessageId
			, Msg.Item.value('@BetTransId', 'varchar(MAX)') AS MessageId
		FROM @XMLMessage.nodes('/Messages/Item') as Msg(Item) 
		
		-- insert batch message
		INSERT dbo.MsgTarget(MessageId, TargetId, TargetName, isRead, BetTransId ,PostTime) --messagetype: for old version
		SELECT DISTINCT mt.MessageId
			, mt.TargetId
			, mt.TargetName
			, 0 AS isRead
			, mt.BetTransId
			, @PostTime AS PostTime
			
		FROM #msgTarget mt
			INNER JOIN dbo.Msg msg WITH(NOLOCK)
			ON mt.MessageId 	= msg.MessageId
		WHERE mt.MessageId 		> 0
			AND	mt.TargetId 	> 0
			AND mt.BetTransId 	<> ''
			AND msg.Creator		= @CreatorId
	END TRY
	BEGIN CATCH 
		SELECT @ErrorCode	= ERROR_NUMBER()
			, @ErrorMsg	 	= ERROR_MESSAGE()
	END CATCH
	
	RETURN
	
END
