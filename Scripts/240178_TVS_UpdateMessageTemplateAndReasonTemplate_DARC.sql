﻿/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20251006@Lani
	Task: [TVS] Danger Accepted - Update message template of sub type Penalty Shootout [Redmine: #240178]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

UPDATE mt
SET mt.MsgEnglish = N'Attn:[{{Sport type}}] Due to the penalty shootout had been started in the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
   ,mt.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
   ,mt.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
   ,mt.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM TicketVoiding_MessageTemplate AS mt WITH (UPDLOCK, ROWLOCK)
WHERE mt.TemplateId = 47 

UPDATE rt
SET rt.ReasonEnglish = 'Penalty shootout had been started'
   ,rt.ReasonChineseSimplified = N'点球赛已开踢'
FROM TicketVoiding_ReasonTemplate AS rt WITH (UPDLOCK, ROWLOCK)
WHERE rt.SubIssueTypeId = 92