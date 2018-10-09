/*<info serverAlias="DBMSG-bodb_Message" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_TemplateMessageItems_Insert]
	@TemplateId	INT	
	,@XMLData	XML
AS
/*	Created by:: Alan
	Date 20181008
	Task: #101083 - Support Message Template
	DB: DBMSG.bodb_Message
	
	Revisions: 
		- 20181008@Alan: Insert message template item into new table MessageTemplateCustomize
	
	Param's explanation:
		- @XMLData: N'<TemplateItems><Item InputType="Text" Name="2" OrderBy="1" JsonValue="{&quot;Name&quot;:&quot;2&quot;...}"/>/TemplateItems>'	
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #MessageItems(
		InputType	TINYINT,
		Name		NVARCHAR(50),
		OrderBy		TINYINT,
		JsonValue	NVARCHAR(MAX)
	)

	INSERT INTO #MessageItems
	SELECT Msg.Item.value('@InputType', 'TINYINT') AS InputType
		, Msg.Item.value('@Name', 'NVARCHAR(50)') AS Name
		, Msg.Item.value('@OrderBy', 'TINYINT') AS OrderBy
		, Msg.Item.value('@JsonValue', 'NVARCHAR(MAX)') AS JsonValue
	FROM @XMLData.nodes('/TemplateItems/Item') as Msg(Item) 

	INSERT dbo.MessageTemplateItems (TemplateId, InputType, Name, OrderBy, JsonValue)
	SELECT @TemplateId, temp.InputType, temp.Name, temp.OrderBy, temp.JsonValue
	FROM #MessageItems temp
	WHERE @TemplateId > 0

	DROP TABLE #MessageItems

	SET NOCOUNT OFF
END
GO
