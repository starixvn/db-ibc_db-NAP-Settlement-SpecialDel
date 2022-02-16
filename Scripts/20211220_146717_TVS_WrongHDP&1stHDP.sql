/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211220@July
	Task: TVS - Wrong Handicap/Wrong 1st HDP - [Redmine: #146717]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,8,'Wrong HDP',N'亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,22,'Wrong HDP',N'亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,23,'Wrong HDP',N'亚洲盘显示错误')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,9,'Wrong 1st HDP',N'上半场亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,24,'Wrong 1st HDP',N'上半场亚洲盘显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,25,'Wrong 1st HDP',N'上半场亚洲盘显示错误')

GO

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "HDP -{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "HDP -{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "讓球盤 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "讓球盤 -{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 8 

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H HDP -{{Wrong Market}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "1H HDP -{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場讓球盤 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "上半場讓球盤 -{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场让球盘 -{{Wrong Market}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场让球盘 -{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 9

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "{{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 29

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "{{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "{{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 30

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "1H {{Home team name}} -{{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場  {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "上半場  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场  {{Away team name}} {{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场  {{Home team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 31

UPDATE TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong 1H HDP displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "1H {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). The actual market is "1H  {{Away team name}} -{{HDP Value}}".  {{CheckStatement}}Sorry for the inconvenience caused!'
    ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於上半場讓球盤顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "上半場 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 正確盤口為 "上半場 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于上半场让球盘显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "上半场 {{Home team name}} -{{HDP Value}}" {{FromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 正确盘口为 "上半场 {{Away team name}} -{{HDP Value}}". {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 32