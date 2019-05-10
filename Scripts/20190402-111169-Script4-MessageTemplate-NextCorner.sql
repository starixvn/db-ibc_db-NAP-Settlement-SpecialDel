/*
	Script 4
	Created by: Jacob
	Date: 20190329
	Task: Update Message Templates for some types of Other Sports #111169
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- Insert SubType Next Corner
DECLARE @DangerAcceptTypeId TINYINT= 1
DECLARE @NextCornerSubTypeId TINYINT
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@DangerAcceptTypeId,
        N'Next corner'
       );
SELECT @NextCornerSubTypeId = @@IDENTITY;

-- INSERT Template
DECLARE @NextCornerTemplateId SMALLINT= 33
INSERT INTO [dbo].[TicketVoiding_MessageTemplate]
       ([TemplateId],
        [MsgEnglish],
        [MsgChineseTraditional],
        [MsgChineseSimplified],
        [MsgChineseNewSimplified],
        [JsonValue]
       )
VALUES
       (@NextCornerTemplateId,
        N'Attn:[{{Sport type}}] Due to {{Next Corner}} corner has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於{{Next Corner}}角球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'[{"Name":"Next Corner","MsgEnglish":"Next Corner","MsgChineseTraditional":"Next Corner (TC)","MsgChineseSimplified":"Next Corner (SC)","MsgChineseNewSimplified":"Next Corner (New SC)"}]'
       );

-- Insert Settings

INSERT INTO [dbo].[TicketVoiding_MessageTemplateSetting]
       ([TemplateId],
        [Sporttype],
        [SubIssueTypeId]
       )
VALUES
       (@NextCornerTemplateId, -- Soccer
        1,
        @NextCornerSubTypeId
       ),
       (9999, -- Others 
        NULL,
        @NextCornerSubTypeId
       )
GO