/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created by: 20250701@Lani
	Task: [TVS] Technical Error - Update message template
	DB: DBCTG-bodb02

	Revisions:
		- 20250701@Lani: [TVS] Technical Error - Update message template [Redmine: #231398]

	Param's Explanation:
		
*/
USE bodb02
GO
UPDATE m
SET 
	m.MsgEnglish = 'Attn:[{{Sport type}}] Following a review of the match between, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused'
   ,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 經審查賽事 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
   ,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 经审查赛事, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 经审查赛事, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
FROM TicketVoiding_MessageTemplate AS m WITH (UPDLOCK, ROWLOCK)
WHERE m.TemplateId = 48


