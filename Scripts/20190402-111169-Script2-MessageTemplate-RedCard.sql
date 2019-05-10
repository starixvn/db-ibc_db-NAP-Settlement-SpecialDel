/*
	Script 2
	Created by: Jacob
	Date: 20190329
	Task: Update Message Templates for some types of Other Sports #111169
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- Insert Red Card Issue
DECLARE @RedCardIssueTypeId TINYINT;
INSERT INTO [dbo].[TicketVoiding_IssueType]([IssueTypeName])
VALUES(N'Red Card');
SELECT @RedCardIssueTypeId = @@IDENTITY;

-- Insert SubIssueType
DECLARE @NoIndicationHomeRCId TINYINT, @NoIndicationAwayRCId TINYINT, @WrongIndicationHomeRCId TINYINT, @WrongIndicationAwayRCId TINYINT, @RCAwardUnderRegularTimeHomeId TINYINT, @RCAwardUnderRegularTimeAwayId TINYINT, @ReplacementOfSentOffPlayerId TINYINT;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'No Indication - Home RC'
       );
SELECT @NoIndicationHomeRCId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'No Indication - Away RC'
       );
SELECT @NoIndicationAwayRCId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'Wrong Indication - Home RC'
       );
SELECT @WrongIndicationHomeRCId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'Wrong Indication - Away RC'
       );
SELECT @WrongIndicationAwayRCId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'RC award under regular time - Home'
       );
SELECT @RCAwardUnderRegularTimeHomeId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'RC award under regular time - Away'
       );
SELECT @RCAwardUnderRegularTimeAwayId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@RedCardIssueTypeId,
        N'Replacement of Sent-off player'
       );
SELECT @ReplacementOfSentOffPlayerId = @@IDENTITY;

-- INSERT Template
DECLARE @NoIndicationHomeRCTemplateId SMALLINT= 22, @NoIndicationAwayRCTemplateId SMALLINT= 23, @WrongIndicationHomeRCTemplateId SMALLINT= 24, @WrongIndicationAwayRCTemplateId SMALLINT= 25, @RCAwardUnderRegularTimeHomeTemplateId SMALLINT= 26, @RCAwardUnderRegularTimeAwayTemplateId SMALLINT= 27, @ReplacementOfSentOffPlayerTemplateId SMALLINT= 28;
INSERT INTO [dbo].[TicketVoiding_MessageTemplate]
       ([TemplateId],
        [MsgEnglish],
        [MsgChineseTraditional],
        [MsgChineseSimplified],
        [MsgChineseNewSimplified],
        [JsonValue]
       )
VALUES
       (@NoIndicationHomeRCTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於主隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@NoIndicationAwayRCTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於客隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@WrongIndicationHomeRCTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於紅牌錯誤設置予主隊導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于红牌错误设置予主队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于红牌错误设置予主队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@WrongIndicationAwayRCTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'请注意:[{{Sport type}}] 由于红牌错误设置予主队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于红牌错误设置予客队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于红牌错误设置予客队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@RCAwardUnderRegularTimeHomeTemplateId,
        N'Attn:[{{Sport type}}] Due to red card being awarded to Home team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於主隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@RCAwardUnderRegularTimeAwayTemplateId,
        N'Attn:[{{Sport type}}] Due to red card being awarded to Away team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於客隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       ),
       (@ReplacementOfSentOffPlayerTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong odds offered on replacement of sent-off player for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於红牌球員被替换導致提供錯誤的賠率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       );

-- Insert Red Card Settings
INSERT INTO [dbo].[TicketVoiding_MessageTemplateSetting]
       ([TemplateId],
        [Sporttype],
        [SubIssueTypeId]
       )
VALUES
       (@NoIndicationHomeRCTemplateId, -- 1
        1,
        @NoIndicationHomeRCId
       ),
       (9999,
        NULL,
        @NoIndicationHomeRCId
       ),
       (@NoIndicationAwayRCTemplateId, -- 2
        1,
        @NoIndicationAwayRCId
       ),
       (9999,
        NULL,
        @NoIndicationAwayRCId
       ),
       (@WrongIndicationHomeRCTemplateId, -- 3
        1,
        @WrongIndicationHomeRCId
       ),
       (9999,
        NULL,
        @WrongIndicationHomeRCId
       ),
       (@WrongIndicationAwayRCTemplateId, --4
        1,
        @WrongIndicationAwayRCId
       ),
       (9999,
        NULL,
        @WrongIndicationAwayRCId
       ),
       (@RCAwardUnderRegularTimeHomeTemplateId, -- 5
        1,
        @RCAwardUnderRegularTimeHomeId
       ),
       (9999,
        NULL,
        @RCAwardUnderRegularTimeHomeId
       ),
       (@RCAwardUnderRegularTimeAwayTemplateId, -- 6
        1,
        @RCAwardUnderRegularTimeAwayId
       ),
       (9999,
        NULL,
        @RCAwardUnderRegularTimeAwayId
       ),
       (@ReplacementOfSentOffPlayerTemplateId, -- 7
        1,
        @ReplacementOfSentOffPlayerId
       ),
       (9999,
        NULL,
        @ReplacementOfSentOffPlayerId
       );
GO