/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220301@July
	Task: TVS - Enhancement for Cash Out - [Redmine: #169237]
	DB: DBTXN-bodb02

	Note: add 'Cash Out Cancelled' into message template
*/
USE bodb02
GO

/*dbo.TicketVoiding_MessageTemplate*/

--1.Wrong Odds
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong odds displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賠率顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 6

--2.Wrong Score
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong score displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. The actual score is "{{Actual Score}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比分顯示錯誤,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. 正確比分為 "{{Actual Score}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. 正确比分为 "{{Actual Score}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. 正确比分为 "{{Actual Score}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 7

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong score displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. The actual score is "{{Actual ScoreOW}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比分顯示錯誤,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. 正確比分為 "{{Actual ScoreOW}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作废受影响的注单. 串关以(1)计算. 实时兑现. 正确比分为 "{{Actual ScoreOW}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作废受影响的注单. 串关以(1)计算. 实时兑现. 正确比分为 "{{Actual ScoreOW}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 36

--3.Wrong HDP/Wrong Quarter HDP
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "HDP -{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "HDP -{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "讓球盤 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "讓球盤 -{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 8

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 29

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 30

--4.Wrong 1st HDP
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H HDP -{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "1H HDP -{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場讓球盤 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "上半場讓球盤 -{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 9

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "1H {{Home team name}} -{{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場  {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "上半場  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 31

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "1H  {{Away team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "上半場 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 32

--5.Wrong OU
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong OU displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "OU-{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "OU-{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於大小盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "大小盤-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "大小盤-{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 10

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to the number of scheduled overs being reduced for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "OU-{{Wrong Market}} onwards" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比賽輪數减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "大小盤-{{Wrong Market}} 開始" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}} 开始" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}} 开始" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 38

--6.Wrong 1st OU
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H OU displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H OU-{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "1H OU-{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場大小盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場大小盤-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即時兌現. 正確盤口為 "上半場大小盤-{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现. 正确盘口为 "上半场大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 11

--7.Early Kick Off
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to early kick off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 12

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to early kick off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 13

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to match early tip off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 14

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to match early tip off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 15

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to event early start, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 16

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to event early start, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 17

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to event early tee off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 18

--8.Wrong Kick Off Time
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong kick off time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於開賽時間顯示有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于开赛时间显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于开赛时间显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 19

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong tip off time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于開賽時間顯示有誤 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于开赛时间错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于开赛时间错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 20

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong event start time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于開賽時間顯示有誤 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间显示错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间显示错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 21

--9.Wrong Market Offered
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered on Live betting for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於滾球賽事盤口錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}] , 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 35

--10.Danger Accepted
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in goal danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有進球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 1

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in corner danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有角球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有角球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有角球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 2

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in booking danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有罰牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有罚牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有罚牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 3

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in home red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在主隊有紅牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在主队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@"{{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在主队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@"{{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 4

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in away red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在客隊有紅牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在客队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在客队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 5

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{Next Corner}} corner has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於{{Next Corner}}角球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 33

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 39

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{Next Booking}} Booking has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}],bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於 {{Next Booking}} 罰牌賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{Next Booking}} 罚牌赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{Next Booking}} 罚牌赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 40

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in Goal Kick danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於註單在有龍門球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的註單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有龙门球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有龙门球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 42

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{Next Goal Kick}} Goal Kick has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}],bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於{{Next Goal Kick}} 龍門球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于{{Next Goal Kick}} 龙门球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于{{Next Goal Kick}} 龙门球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 43

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 44

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 45

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to {{Next Goal}} goal has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{Next Goal}} 入球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{Next Goal}} 入球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{Next Goal}} 入球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 46

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to the first penalty kick had been taken, match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 47

--11.Red Card
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 22

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於客隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算.  实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 23

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊紅牌錯誤顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 24

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於客隊紅牌錯誤顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 25

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to red card being awarded to Home team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 26

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to red card being awarded to Away team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於客隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 27

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong odds offered on replacement of sent-off player for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於红牌球員被替换導致提供錯誤的賠率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 28

--14.Match Completed
UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK,UPDLOCK)
SET	MsgEnglish = N'Attn:[{{Sport type}}] Due to "{{Wicket No}} Wicket" has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於 "{{Wicket No}}三柱門" 已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的註單. 串關以(1)計算. 即時兌現. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 "{{Wicket No}}三柱门" 已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 "{{Wicket No}}三柱门" 已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. 实时兑现. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 41
