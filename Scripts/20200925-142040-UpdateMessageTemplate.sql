/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20200925@Max
	Task: TVS - Modify message template - [Redmine: #142040]
	DB: bodb02 - DBTRANS
*/

USE bodb02
GO

--Template 6
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong odds displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賠率顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 6

--Template 7
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong score displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual score is "{{Actual Score}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比分顯示錯誤,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確比分為 "{{Actual Score}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确比分为 "{{Actual Score}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确比分为 "{{Actual Score}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 7

--Template 36
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong score displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}which affected are considered VOID. Parlay counted as (1). The actual score is "{{Actual ScoreOW}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比分顯示錯誤,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作廢受影響的注單. 過關以(1)計算. 正確比分為 "{{Actual ScoreOW}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作废受影响的注单. 过关以(1)计算. 正确比分为 "{{Actual ScoreOW}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比分显示错误,"{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{WrongScoreOW}}只作废受影响的注单. 过关以(1)计算. 正确比分为 "{{Actual ScoreOW}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 36

--Template 8
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "HDP{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "HDP{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "讓球盤{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "讓球盤{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "让球盘{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "让球盘{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 8

--Template 29
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "{{Home team name}} {{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "{{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 29

--Template 30
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "{{Away team name}} {{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "{{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 30

--Template 9
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H HDP{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "1H HDP{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場讓球盤{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "上半場讓球盤{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场让球盘{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场让球盘{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 9

--Template 31
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "1H {{Home team name}} {{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "上半場  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场  {{Home team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 31

--Template 32
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "1H  {{Away team name}} {{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "上半場 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场 {{Away team name}} {{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 32

--Template 10
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong OU displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "OU-{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "OU-{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於大小盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "大小盤-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "大小盤-{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 10

--Template 11
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H OU displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H OU-{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). The actual market is "1H OU-{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場大小盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場大小盤-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. 正確盤口為 "上半場大小盤-{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场大小盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场大小盘-{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. 正确盘口为 "上半场大小盘-{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 11

--Template 12
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to early kick off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 12

--Template 13
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to early kick off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 13

--Template 14
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to match early tip off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 14

--Template 15
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to match early tip off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 15

--Template 16
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to event early start, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 16

--Template 17
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to event early start, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID (Except Live Game). Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事時間提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單 (除了走地). 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间提前开始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单 (除了走地). 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 17

--Template 18
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to event early tee off, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 之後只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于賽事提前開始, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 之后只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 18

/*---------------------------------------*/
--Template 19
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong kick off time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於開賽時間顯示有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于开赛时间显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于开赛时间显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 19

--Template 20
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong tip off time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于開賽時間顯示有誤 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于开赛时间错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于开赛时间错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 20

--Template 21
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong event start time displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], bet ID: "@@" placed after {{KO time}} which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于開賽時間顯示有誤 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注單: "@@" 投注於 {{KO time}} 只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于赛事时间显示错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于赛事时间显示错误 , "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}], 注单: "@@" 投注于 {{KO time}} 只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 21

--Template 35
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered on Live betting for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於滾球賽事盤口錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}] , 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 35