/*<info serverAlias="DBMSG-bodb_Message" executers="wsv_nap,Dot_Admin" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_Message_Insert]
	@MessageId int = NULL,
	@Content_en	nvarchar(4000) = NULL,
	@Content_ch	nvarchar(4000) = NULL,
	@Content_cs	nvarchar(4000) = NULL,
	@Content_jp	nvarchar(4000) = NULL,
	@Content_it	nvarchar(4000) = NULL,
	@Content_th	nvarchar(4000) = NULL,
	@Content_ko nvarchar(4000) = NULL,
	@Content_es nvarchar(4000) = NULL,
	@Content_vn nvarchar(4000) = NULL,
	@Content_id nvarchar(4000) = NULL,
	@content_el nvarchar(4000) = NULL,
	@content_mx nvarchar(4000) = NULL,
	@Content_zhcn nvarchar(4000) = NULL,
	@MsgType int = 3,
	@IsSticky bit = 0,
	@Creator int = 0,
	@CreatorName nvarchar(50),
	@IsTest bit = 0,
	@MatchId int = 0,
	@IsBatch bit = 0,
	@MsgContentsType tinyint = 0,
	@BetTransId varchar(2000) = NULL -- remove when admin launch batchmessage
	,@LeagueGroupId SMALLINT = 0
	/*	
	Created by: Alan
	Task : insert/update special and normal message
	DB: DBMSG/bodb_Message
	Original: 20090910@KhoaTran: Dot_Msg_SetMessage

	Revisions:
		- 20180925@Alan: Clone SP For SpecialDelete [101082]
		- 20220221@Max: Remove SABA of league name for China View sites [Redmine: #168651]

	Param's Explanation:
		@MessageId: MessageId of a message
		@Content_en : English Message Content 
		@Content_ch : Tridional Chinese Message Content 
		@Content_cs : Simple Chinese Message Content 
		@Content_jp : Japanese Message Content 
		@Content_it : Italian Message Content 
		@Content_th : Thai Message Content 
		@Content_ko : Korean Message Content 
		@Content_es : Spanish Message Content 
		@Content_vn : Vinam Message Content 
		@Content_id : Indonisia Message Content 
		@Content_el : Greece Message Content 
		@Content_zhcn: New Chinese Simplified MessageContent
		@MsgType    : 
		= 1 : message to customer (personal)
		= 3 : message to indicate site (refer to table MsgSite and MsgTarget.targetid) 
		@IsSticky   : Is special Message or not 
		@Creator    : Creator ID 
		@CreatorName: Creator Name 
		@IsTest     : Is test or not 
		@MatchId    : matchid of a match
		@IsBatch    : 
		= 0 : normal message (no need to replace the symbol @@ by transid when display)
		= 1 : special message (need to replace the symbol @@ by transid when display)
	*/

AS
SET NOCOUNT ON
BEGIN
	IF EXISTS (SELECT MessageId FROM dbo.Msg with (nolock) WHERE MessageId = @MessageId)
	BEGIN
		-- update
		UPDATE dbo.Msg WITH (rowlock,updlock)
		SET
			Content_ch = @Content_ch,
			Content_cs = @Content_cs,
			Content_it = @Content_it,
			Content_jp = @Content_jp,
			Content_th = @Content_th,
			Content_en = @Content_en,
			Content_ko = @Content_ko,
			Content_es = @Content_es,
			Content_vn = @Content_vn,
			Content_id = @Content_id,
			Content_el = @Content_el,
			Content_mx = @Content_mx,
			Content_zhcn = @Content_zhcn,
			LastUpdateTime = getdate(),
			MsgType = @MsgType,
			IsSticky = @IsSticky,
			LastUpdator = @Creator,
			LastUpdateName = @CreatorName,
			IsTest = @IsTest,
			MatchId = @MatchId,
			IsBatch = @IsBatch,
			MsgContentsType = @MsgContentsType ,
			LeagueGroupID = @LeagueGroupId
		WHERE MessageId = @MessageId;
		SELECT @MessageID AS MessageId;
	END
	ELSE
	BEGIN
		-- insert
		INSERT dbo.Msg (Content_ch, Content_it, Content_cs, Content_jp, Content_th,
						Content_en, Content_ko, Content_es, Content_vn, Content_id,
						Content_el, Content_mx, Content_zhcn,
						MsgType, IsSticky, Creator, CreatorName, MatchId,
						LastUpdator, LastUpdateName, CreateTime, LastUpdateTime, PostTime, IsTest,
						IsBatch,
						MsgContentsType, LeagueGroupID
						) 
		VALUES(@Content_ch, @Content_it, @Content_cs, @Content_jp, @Content_th, 
  			   @Content_en, @Content_ko, @Content_es, @Content_vn, @Content_id,
			   @Content_el, @Content_mx, @Content_zhcn,
			   @MsgType, @IsSticky, @Creator, @CreatorName, @MatchId,
			   @Creator, @CreatorName, getdate(), getdate(), getdate(), @IsTest,
			   @IsBatch,
			   @MsgContentsType, @LeagueGroupId
				);
		
		SELECT SCOPE_IDENTITY() AS MessageId;
	END
END
