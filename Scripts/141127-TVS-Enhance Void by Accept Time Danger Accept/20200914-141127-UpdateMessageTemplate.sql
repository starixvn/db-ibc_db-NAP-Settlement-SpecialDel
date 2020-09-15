/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20200914@Max
	Task: [TVS] Enhance Void by Accept Time in Void Single Bet and TVS Danger Accept - [Redmine: #141127]
	DB: bodb02 - DBTRANS
*/

USE bodb02
GO

--Template 1
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in goal danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有進球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有进球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 1

--Template 2
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in corner danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有角球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有角球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有角球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 2

--Template 3
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in booking danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在有罰牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在有罚牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在有罚牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 3

--Template 4
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to bets erroneously accepted in home red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在主隊有紅牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在主队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@"{{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在主队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@"{{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 4

--Template 5
UPDATE ms
	SET ms.MsgEnglish = N'red card	Attn:[{{Sport type}}] Due to bets erroneously accepted in away red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於注單在客隊有紅牌的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于注单在客队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于注单在客队有红牌的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 5

--Template 22
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}]], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 22

--Template 23
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於客隊紅牌遺漏顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队红牌遗漏显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 23

--Template 24
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於紅牌錯誤設置予主隊導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于红牌错误设置予主队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于红牌错误设置予主队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 24

--Template 25
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於紅牌錯誤設置予客隊導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于红牌错误设置予客队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于红牌错误设置予客队导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 25

--Template 26
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to red card being awarded to Home team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 26

--Template 27
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to red card being awarded to Away team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於客隊於常規時段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队于常规时段内已得红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 27

--Template 28
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to wrong odds offered on replacement of sent-off player for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於红牌球員被替换導致提供錯誤的賠率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于红牌球员被替换导致提供错误的赔率, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 28

--Template 33
UPDATE ms
	SET ms.MsgEnglish = N'Attn:[{{Sport type}}] Due to {{Next Corner}} corner has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID . Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!',
		ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於{{Next Corner}}角球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于{{Next Corner}}角球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 33