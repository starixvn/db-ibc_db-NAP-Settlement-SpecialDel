/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201222@Max
	Task: TVS - Modify the translation of Parlay words - [Redmine: #147531]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

-- UPDATE Template 1
UPDATE ms SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in goal danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
	,ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有進球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
	,ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 1


