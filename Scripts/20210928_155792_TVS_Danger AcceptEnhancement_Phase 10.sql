/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211012@July
	Task: TVS - Danger Accept Enhancement - Phase 10 - [Redmine: #155792]
	DB: DBTXN-bodb02
*/


USE bodb02
GO

--dbo.TicketVoiding_SubIssueType
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'HT/FT (Real Soccer) - Full Time' WHERE SubIssueTypeId = 67
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'HT/FT (Futsal) - Full Time' WHERE SubIssueTypeId = 78
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'HT/FT (Virtual) - Full Time' WHERE SubIssueTypeId = 85

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (86, 1, 'HT/FT (Real Soccer) - Half Time')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (87, 1, 'HT/FT (Futsal) - Half Time')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (88, 1, 'HT/FT (Virtual) - Half Time')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (89, 1, 'Next Goal - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (90, 1, 'Next Goal - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (91, 1, 'Next Goal')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (92, 1, 'Penalty Shootout - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (93, 1, 'Penalty Shootout - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (94, 1, 'Penalty Shootout')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF

-------dbo.TicketVoiding_MessageTemplate
--Next Goal
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified, JsonValue)
VALUES ( 46
		,N'Attn:[{{Sport type}}] Due to {{Next Goal}} goal has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於 {{Next Goal}} 入球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于 {{Next Goal}} 入球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于 {{Next Goal}} 入球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'[{"Name":"Next Goal","MsgEnglish":"Next Goal","MsgChineseTraditional":"Next Goal (TC)","MsgChineseSimplified":"Next Goal (SC)","MsgChineseNewSimplified":"Next Goal (New SC)"}]'
		)
--Penalty Shootout
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 47
		,N'Attn:[{{Sport type}}] Due to the first penalty kick had been taken, match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于点球赛已开踢, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		)

-------dbo.TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (39,1,86)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,86)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (44,1,87)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,87)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (45,1,88)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,88)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (46,1,89)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,89)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (46,1,90)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,90)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (46,1,91)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,91)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (47,1,92)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,92)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (47,1,93)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,93)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (47,1,94)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,94)

-----------dbo.TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,86,'Match Had Been Completed ',N'由于赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,87,'Match Had Been Completed ',N'由于赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,88,'Match Had Been Completed ',N'由于赛事已结束')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,89,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,90,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,91,'Danger Accept In Goal',N'有进球的危险时段中误被接受')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,92,'First penalty kick had been taken',N'点球赛已开踢')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,93,'First penalty kick had been taken',N'点球赛已开踢')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,94,'First penalty kick had been taken',N'点球赛已开踢')



