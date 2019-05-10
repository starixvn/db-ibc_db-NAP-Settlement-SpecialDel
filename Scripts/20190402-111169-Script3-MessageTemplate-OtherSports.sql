/*
	Script 3
	Created by: Jacob
	Date: 20190329
	Task: Update Message Templates for some types of Other Sports #111169
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- Insert Wrong HDP
DECLARE @WrongOddsTypeId TINYINT= 2, @WrongScoreTypeId TINYINT= 3, @WrongHDPTypeId TINYINT= 4, @Wrong1stHDPTypeId TINYINT= 5, @WrongOUTypeId TINYINT= 6;
DECLARE @AwayVirtualHeadReversedId TINYINT, @HomeVirtualHeadReversedId TINYINT;
DECLARE @AwayVirtualHeadReversed1stId TINYINT, @HomeVirtualHeadReversed1stId TINYINT;
DECLARE @Wrong1stOUId TINYINT;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@WrongHDPTypeId,
        N'Away Virtual Head Reversed'
       );
SELECT @AwayVirtualHeadReversedId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@WrongHDPTypeId,
        N'Home Virtual Head Reversed'
       );
SELECT @HomeVirtualHeadReversedId = @@IDENTITY;

-- INSERT Wrong 1H HDP
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@Wrong1stHDPTypeId,
        N'Away Virtual Head Reversed'
       );
SELECT @AwayVirtualHeadReversed1stId = @@IDENTITY;
INSERT INTO [dbo].[TicketVoiding_SubIssueType]
       ([IssueTypeId],
        [SubIssueTypeName]
       )
VALUES
       (@Wrong1stHDPTypeId,
        N'Home Virtual Head Reversed'
       );
SELECT @HomeVirtualHeadReversed1stId = @@IDENTITY;

-- INSERT Template
DECLARE @WrongOddsTemplateId SMALLINT= 6, @WrongScoreTemplateId SMALLINT= 7, @WrongHDPTemplateId SMALLINT= 8, @Wrong1stHDPTemplateId SMALLINT= 9, @WrongOUTemplateId SMALLINT= 10, @Wrong1stOUTemplateId SMALLINT= 11;
DECLARE @AwayVirtualHeadReversedTemplateId SMALLINT= 29, @HomeVirtualHeadReversedTemplateId SMALLINT= 30;
DECLARE @AwayVirtualHeadReversed1stTemplateId SMALLINT= 31, @HomeVirtualHeadReversed1stTemplateId SMALLINT= 32;

INSERT INTO [dbo].[TicketVoiding_MessageTemplate]
       ([TemplateId],
        [MsgEnglish],
        [MsgChineseTraditional],
        [MsgChineseSimplified],
        [MsgChineseNewSimplified],
        [JsonValue]
       )
VALUES
       (@AwayVirtualHeadReversedTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). The actual market is "{{Home team name}} {{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於亞洲盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. 正確盤口為 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'[{"Name":"HDP Value","MsgEnglish":"HDP Value","MsgChineseTraditional":"HDP Value (TC)","MsgChineseSimplified":"HDP Value (SC)","MsgChineseNewSimplified":"HDP Value (New SC)"}]'
       ),
       (@HomeVirtualHeadReversedTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). The actual market is "{{Away team name}} {{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於上半場亞洲盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. 正確盤口為 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'[{"Name":"HDP Value","MsgEnglish":"HDP Value","MsgChineseTraditional":"HDP Value (TC)","MsgChineseSimplified":"HDP Value (SC)","MsgChineseNewSimplified":"HDP Value (New SC)"}]'
       ),
       (@AwayVirtualHeadReversed1stTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). The actual market is "1H {{Home team name}} {{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於上半場亞洲盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. 正確盤口為 "上半場  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "上半场  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "上半场  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'[{"Name":"HDP Value","MsgEnglish":"HDP Value","MsgChineseTraditional":"HDP Value (TC)","MsgChineseSimplified":"HDP Value (SC)","MsgChineseNewSimplified":"HDP Value (New SC)"}]'
       ),
       (@HomeVirtualHeadReversed1stTemplateId,
        N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}are considered VOID. Parlay counted as (1). The actual market is "1H  {{Away team name}} {{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於上半場亞洲盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. 正確盤口為 "上半場 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "上半场 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于上半场亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "上半场 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
        N'[{"Name":"HDP Value","MsgEnglish":"HDP Value","MsgChineseTraditional":"HDP Value (TC)","MsgChineseSimplified":"HDP Value (SC)","MsgChineseNewSimplified":"HDP Value (New SC)"}]'
       );

-- Delete Old Settings
DELETE [dbo].[TicketVoiding_MessageTemplateSetting]
WHERE SubIssueTypeId BETWEEN 6 AND 11;
-- Insert Settings

DECLARE @WrongOddsSubTypeId TINYINT= 6, @WrongScoreSubTypeId TINYINT= 7, @WrongHDPSubTypeId TINYINT= 8, @Wrong1stHDPSubTypeId TINYINT= 9, @WrongOUSubTypeId TINYINT= 10, @Wrong1stOUSubTypeId TINYINT= 11, @WrongHDPAwayVirtualHeadReversedSubTypeId TINYINT= 22, @WrongHDPHomeVirtualHeadReversedSubTypeId TINYINT= 23, @Wrong1stHDPAwayVirtualHeadReversedSubTypeId TINYINT= 24, @Wrong1stHDPHomeVirtualHeadReversedSubTypeId TINYINT= 25;
INSERT INTO [dbo].[TicketVoiding_MessageTemplateSetting]
       ([TemplateId],
        [Sporttype],
        [SubIssueTypeId]
       )
VALUES
       (@WrongOddsTemplateId, -- Wrong Odds
        NULL,
        @WrongOddsSubTypeId
       ),
       (@WrongScoreTemplateId, -- Wrong Score
        NULL,
        @WrongScoreSubTypeId
       ),
       (@WrongHDPTemplateId, -- Wrong HDP
        NULL,
        @WrongHDPSubTypeId
       ),
       (@AwayVirtualHeadReversedTemplateId, -- Wrong HDP
        NULL,
        @WrongHDPAwayVirtualHeadReversedSubTypeId
       ),
       (@HomeVirtualHeadReversedTemplateId, -- Wrong HDP
        NULL,
        @WrongHDPHomeVirtualHeadReversedSubTypeId
       ),
       (@Wrong1stHDPTemplateId, -- Wrong 1st HDP
        NULL,
        @Wrong1stHDPSubTypeId
       ),
       (@AwayVirtualHeadReversed1stTemplateId, -- Wrong 1st HDP
        NULL,
        @Wrong1stHDPAwayVirtualHeadReversedSubTypeId
       ),
       (@HomeVirtualHeadReversed1stTemplateId, -- Wrong 1st HDP
        NULL,
        @Wrong1stHDPHomeVirtualHeadReversedSubTypeId
       ),
       (@WrongOUTemplateId, -- Wrong OU
        NULL,
        @WrongOUSubTypeId
       ),
       (@Wrong1stOUTemplateId, -- Wrong OU
        NULL,
        @Wrong1stOUSubTypeId
       );
GO