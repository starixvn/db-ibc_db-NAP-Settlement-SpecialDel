/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240516@July 
	Task: [TVS] Update template message remove blank after {{PlacedFromTimeRange}} - [Redmine: #194093]
	DB: DBCTG/bodb02
*/
USE bodb02
GO


UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to the number of scheduled overs being reduced for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比賽輪數减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!' 
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 38

UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to match was abandoned before the scheduled overs, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比賽輪數减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!' 
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 50

UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to Player [{{Player Name}}] did not participate, [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 因参賽者 [{{Player Name}}] 未参賽, [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!' 
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 63
