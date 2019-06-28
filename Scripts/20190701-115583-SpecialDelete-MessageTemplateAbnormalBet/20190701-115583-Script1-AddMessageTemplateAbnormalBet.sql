/*
	Script 1
	Created by: Raymond
	Date: 20190701
	Task: Add Message Templates for Abnormal Bet #115583
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- TemplateId = 34 - Abnormal bet message
INSERT INTO [dbo].[TicketVoiding_MessageTemplate]
       ([TemplateId],
        [MsgEnglish],
        [MsgChineseTraditional],
        [MsgChineseSimplified],
        [MsgChineseNewSimplified],
        [JsonValue]
       )
VALUES
       (34,
        N'Attn:[{{Sport type}}] Due to abnormal bets, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" are considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!',
        N'請注意:[{{Sport type}}] 由於非正常投注, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!',
        N'请注意:[{{Sport type}}] 由于非正常投注, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!',
        N'请注意:[{{Sport type}}] 由于非正常投注, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!',
        N''
       );
GO	
   
-- Update TemplateId = 30 
UPDATE [dbo].[TicketVoiding_MessageTemplate]
SET [MsgChineseTraditional] = N'請注意:[{{Sport type}}] 由於亞洲盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. 正確盤口為 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
      [MsgChineseSimplified] = N'请注意:[{{Sport type}}] 由于亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
      [MsgChineseNewSimplified] = N'请注意:[{{Sport type}}] 由于亚洲盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}已被作废. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 30;
GO
