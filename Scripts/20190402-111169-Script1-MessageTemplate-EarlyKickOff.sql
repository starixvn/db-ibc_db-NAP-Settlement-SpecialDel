/*
	Script 1
	Created by: Jacob
	Date: 20190329
	Task: Update Message Templates for some types of Other Sports #111169
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- TemplateId = 12 - Early Kick Off -  Non-Live - Soccer

UPDATE [dbo].[TicketVoiding_MessageTemplate]
  SET
      [MsgEnglish] = N'Attn:[{{Sport type}}] Due to early kick off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} are considered VOID (Except Live Game). Parlay counted as (1). Sorry for the inconvenience caused!',
      [MsgChineseTraditional] = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後已被作廢 (除了走地). 過關以(1)計算. 不便之處 敬請見諒!',
      [MsgChineseSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!',
      [MsgChineseNewSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!'
WHERE TemplateId = 12;
GO

-- TemplateId = 14 - Early Kick Off -  Non-Live - Basketball
UPDATE [dbo].[TicketVoiding_MessageTemplate]
  SET
      [MsgEnglish] = N'Attn:[{{Sport type}}] Due to match early tip off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} are considered VOID (Except Live Game). Parlay counted as (1). Sorry for the inconvenience caused!',
      [MsgChineseTraditional] = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後已被作廢 (除了走地). 過關以(1)計算. 不便之處 敬請見諒!',
      [MsgChineseSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!',
      [MsgChineseNewSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!'
WHERE TemplateId = 14;
GO

-- TemplateId = 16 - Early Kick Off -  Non-Live - Default 
UPDATE [dbo].[TicketVoiding_MessageTemplate]
  SET
      [MsgEnglish] = N'Attn:[{{Sport type}}] Due to event early start, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} are considered VOID (Except Live Game). Parlay counted as (1). Sorry for the inconvenience caused!',
      [MsgChineseTraditional] = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後已被作廢 (除了走地). 過關以(1)計算. 不便之處 敬請見諒!',
      [MsgChineseSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!',
      [MsgChineseNewSimplified] = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后已被作废 (除了走地). 过关以(1)计算. 不便之处 敬请见谅!'
WHERE TemplateId = 16;
GO
