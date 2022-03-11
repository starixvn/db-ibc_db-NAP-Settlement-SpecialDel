/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220310@July
	Task: TVS - Update message content - [Redmine: #169783]
	DB: DBTXN-bodb02

	Note: add {{SpecialBetType}} into message template 
*/
USE bodb02
GO

/*dbo.TicketVoiding_MessageTemplate*/

--1.Wrong Odds
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong odds displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}賠率顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 6

--2.Wrong HDP/Wrong Quarter HDP
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "HDP -{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "HDP -{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "讓球盤 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "讓球盤 -{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 8

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 29

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 30

--3.Wrong OU
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong OU displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "OU-{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "OU-{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}大小盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "大小盤-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "大小盤-{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 10

