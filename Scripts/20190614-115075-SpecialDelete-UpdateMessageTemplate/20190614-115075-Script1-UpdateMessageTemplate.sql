/*
	Script 1
	Created by: Raymond
	Date: 20190614
	Task: Update some Message Templates #115075
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- TemplateId = 33 - Danger Accepted > Next Corner

UPDATE [dbo].[TicketVoiding_MessageTemplate]
  SET
      [MsgEnglish] = N'Attn:[{{Sport type}}] Due to {{Next Corner}} corner has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
      [MsgChineseTraditional] = N'請注意:[{{Sport type}}] 由於{{Next Corner}}角球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
      [MsgChineseSimplified] = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
      [MsgChineseNewSimplified] = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}已被作废. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 33;
GO

-- TemplateId = 25 - Red Card > Wrong Indication - Away RC
UPDATE [dbo].[TicketVoiding_MessageTemplate]
  SET
	  [MsgChineseTraditional] = N'請註意:[{{Sport type}}] 由於紅牌錯誤設置予客隊導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}已被作廢. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
WHERE TemplateId = 25;
GO