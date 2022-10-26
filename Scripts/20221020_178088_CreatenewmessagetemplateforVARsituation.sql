/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221020@July
	Task: [TVS] Create new message template for VAR situation - [Redmine: #178088]
	DB: DBCTG-bodb02
*/

USE bodb02
GO
--Add column IsVAR into dbo.TicketVoiding_MessageTemplateSetting
ALTER TABLE dbo.TicketVoiding_MessageTemplateSetting ADD IsCheckedVar BIT

INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 51
,N'Attn:[{{Sport type}}] Due to a goal was scored from a penalty awarded from VAR review for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於在視頻助理裁判 (VAR) 審查後通過點球取得進球, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于在视频助理裁判 (VAR) 审查后通过点球取得进球, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于在视频助理裁判 (VAR) 审查后通过点球取得进球, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 52
,N'Attn:[{{Sport type}}] Due to an official decision to award Home team red card after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定主隊有紅牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队有红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队有红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 53
,N'Attn:[{{Sport type}}] Due to an official decision to award Away team red card after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定客隊有紅牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队有红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队有红牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 54
,N'Attn:[{{Sport type}}] Due to an official decision to award Home team Booking after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定主隊有罰牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队有罚牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队有罚牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 55
,N'Attn:[{{Sport type}}] Due to an official decision to award Away team Booking after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定客隊有罰牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队有罚牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队有罚牌, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 56
,N'Attn:[{{Sport type}}] Due to an official decision to cancel Home team red card after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定主隊紅牌無效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队红牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队红牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 57
,N'Attn:[{{Sport type}}] Due to an official decision to cancel Away team red card after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定客隊紅牌無效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队红牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队红牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 58
,N'Attn:[{{Sport type}}] Due to an official decision to award a goal after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定進球有效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定进球有效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定进球有效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 59
,N'Attn:[{{Sport type}}] Due to an official decision to cancel Home team Booking after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定主隊罰牌無效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队罚牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定主队罚牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 60
,N'Attn:[{{Sport type}}] Due to an official decision to cancel Away team Booking after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定客隊罰牌無效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队罚牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定客队罚牌无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 61
,N'Attn:[{{Sport type}}] Due to an official decision to cancel a goal after reviewing VAR for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於官方在視頻助理裁判 (VAR) 審查後判定進球无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定进球无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于官方在视频助理裁判 (VAR) 审查后判定进球无效, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
GO

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Main Booking - Home' WHERE SubIssueTypeId = 3
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (111, 1,'Main Booking - Away')

--Wrong score - Sub VAR
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Goal (No Onwards)' WHERE SubIssueTypeId = 7
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Goal (Onwards)' WHERE SubIssueTypeId = 35
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Away Goal (No Onwards)' WHERE SubIssueTypeId = 94
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Away Goal (Onwards)' WHERE SubIssueTypeId = 95
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Wrong Indication Goal (No Onwards)' WHERE SubIssueTypeId = 96
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Wrong Indication Goal (Onwards)' WHERE SubIssueTypeId = 97

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (112, 3,'No Indication Home Booking (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (113, 3,'No Indication Home Booking (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (114, 3,'No Indication Away Booking (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (115, 3,'No Indication Away Booking (Onwards)')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId) 
VALUES (3,1,111) --Main Booking - Away
,(7,1,112)
,(36,1,113)
,(7,1,114)
,(36,1,115)

--VAR setting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId, IsCheckedVar) 
VALUES 
--Danger Accepted
 (51,1,1,1)
,(51,1,55,1)
,(51,1,56,1)
,(51,1,57,1)
,(51,1,58,1)
,(51,1,59,1)
,(51,1,60,1)
,(51,1,61,1)
,(51,1,62,1)
,(52,1,4,1)
,(53,1,5,1)
,(52,1,63,1)
,(53,1,64,1)
,(52,1,65,1)
,(53,1,66,1)
,(54,1,3,1)
,(55,1,111,1)
,(51,1,75,1)
,(51,1,76,1)
,(51,1,77,1)
--Red Card
,(56,1,15,1)
,(57,1,16,1)
--Wrong Score
,(58,1,7,1)
,(58,1,35,1)
,(58,1,94,1)
,(58,1,95,1)
,(59,1,112,1)
,(59,1,113,1)
,(60,1,114,1)
,(60,1,115,1)
,(61,1,96,1)
,(61,1,97,1)

