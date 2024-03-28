/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap,Dot_Admin" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_Message_Select]
	@MessageId INT
	/*	
	Created by: Charles
	Task : Get message info from messageId
	DB: DBMSG/bodb_Message

	Revisions:
		- 20201204@Charles: Create new SP [Redmine: #145719]

	Param's Explanation:
	*/

AS
SET NOCOUNT ON
BEGIN
	SELECT Content_ch AS ContentChineseTraditional
			, Content_it AS ContentItalian
			, Content_cs AS ContentChineseSimplified
			, Content_jp AS ContentJapanese
			, Content_th AS ContentThai
			, Content_en AS ContentEnglish
			, Content_ko AS ContentKorean
			, Content_es AS ContentSpanish
			, Content_zhcn AS ContentNewChineseSimplified
			, Creator AS CreatorId
			, CreatorName
			, MessageId
	FROM dbo.Msg WITH(NOLOCK)
	WHERE MessageId = @MessageId
END
