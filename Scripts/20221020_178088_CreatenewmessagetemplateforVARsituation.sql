/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221020@July
	Task: [TVS] Create new message template for VAR situation - [Redmine: #178088]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

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
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Main Booking - Home - NO VAR' WHERE SubIssueTypeId = 3
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (111, 1,'Main Booking - Away - NO VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (112, 1,'Goal - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (113, 1,'Goal - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (114, 1,'Goal - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (115, 1,'Pen Goal/VAR Pen Goal - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (116, 1,'Pen Goal/VAR Pen Goal - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (117, 1,'Pen Goal/VAR Pen Goal - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (118, 1,'BET/FC Pen Goal/Goal - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (119, 1,'BET/FC Pen Goal/Goal - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (120, 1,'BET/FC Pen Goal/Goal - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (121, 1,'Red Card/VAR Red Card - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (122, 1,'Red Card/VAR Red Card - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (123, 1,'2YC (Red card) - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (124, 1,'2YC (Red card) - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (125, 1,'Betradar/FC Red card - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (126, 1,'Betradar/FC Red card - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (127, 1,'Main Booking - Home - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (128, 1,'Main Booking - Away - VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (129, 1,'Goal/PEN (1st & 2nd mark) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (130, 1,'Goal/PEN (1st & 2nd mark) - Home  - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (131, 1,'Goal/PEN (1st & 2nd mark) - Away - VAR')

--Red Card - Sub VAR
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (132, 1,'No Indication Home RC - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (133, 1,'No Indication Away RC - VAR')

--Wrong score - Sub VAR
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Goal (No Onwards) - NO VAR' WHERE SubIssueTypeId = 7
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Goal (Onwards) - NO VAR' WHERE SubIssueTypeId = 35
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Away Goal (No Onwards) - NO VAR' WHERE SubIssueTypeId = 94
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Away Goal (Onwards) - NO VAR' WHERE SubIssueTypeId = 95
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Wrong Indication Goal (No Onwards) - NO VAR' WHERE SubIssueTypeId = 96
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Wrong Indication Goal (Onwards) - NO VAR' WHERE SubIssueTypeId = 97

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (134, 3,'No Indication Home Booking (No Onwards) - NO VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (135, 3,'No Indication Home Booking (Onwards) - NO VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (136, 3,'No Indication Away Booking (No Onwards) - NO VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (137, 3,'No Indication Away Booking (Onwards) - NO VAR')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (138, 3,'No Indication Home Goal (No Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (139, 3,'No Indication Home Goal (Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (140, 3,'No Indication Away Goal (No Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (141, 3,'No Indication Away Goal (Onwards) - VAR' )
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (142, 3,'Wrong Indication Goal (No Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (143, 3,'Wrong Indication Goal (Onwards) - VAR' )
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (144, 3,'No Indication Home Booking (No Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (145, 3,'No Indication Home Booking (Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (146, 3,'No Indication Away Booking (No Onwards) - VAR')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (147, 3,'No Indication Away Booking (Onwards) - VAR')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId) 
VALUES (3,1,111) --Main Booking - Away
--VAR message setting
,(51,1,112)
,(51,1,113)
,(51,1,114)
,(51,1,115)
,(51,1,116)
,(51,1,117)
,(51,1,118)
,(51,1,119)
,(51,1,120)

,(52,1,121)
,(53,1,122)
,(52,1,123)
,(53,1,124)
,(52,1,125)
,(53,1,126)
,(54,1,127)
,(55,1,128)
,(51,1,129)
,(51,1,130)
,(51,1,131)
/*Red Card*/
,(56,1,132)
,(57,1,133)
/*Wrong Score*/
,(58,1,133)
,(7,1,134)
,(36,1,135)
,(7,1,136)
,(36,1,137)

,(58,1,138)
,(58,1,139)
,(58,1,140)
,(58,1,141)
,(59,1,142)
,(59,1,143)
,(60,1,144)
,(60,1,145)
,(61,1,146)
,(61,1,147)

SELECT * FROM TicketVoiding_SubIssueType where IssueTypeId = 3


SELECT s.SubIssueTypeId,s.SubIssueTypeName,ms.TemplateId,m.MsgEnglish 
FROM TicketVoiding_MessageTemplateSetting ms
inner join TicketVoiding_MessageTemplate m on ms.TemplateId = m.TemplateId
inner join dbo.TicketVoiding_SubIssueType s on ms.SubIssueTypeId = s.SubIssueTypeId
where IssueTypeId = 3 and ms.TemplateId <> 9999
and s.SubIssueTypeId in (1,55,56,59,57,58,62,60,61,4,5,63,64,65,66,3,77,75,76)
order by SubIssueTypeId asc, SubIssueTypeName asc

SELECT * FROM TicketVoiding_IssueType
SELECT * FROM TicketVoiding_SubIssueType where IssueTypeId = 1 and SubIssueTypeName like '%PEN%'
SELECT * from TicketVoiding_MessageTemplate   
select * from TicketVoiding_MessageTemplateSetting where SubIssueTypeId =3

select transdesc,betteam, betid,* from dbo.bettrans where matchid = 70048097 and transid = 41239885134168183
select transdesc,betteam, betcheck,* from dbo.bettransm where matchid = 70048097


select  transids, IssueDetail  from dbo.ticketvoiding_requestdetail
where IssueDetail is not null
order by id desc
