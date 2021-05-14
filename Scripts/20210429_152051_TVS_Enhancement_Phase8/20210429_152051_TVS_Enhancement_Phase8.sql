/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210429@July
	Task: TVS - Enhancement- Phase 8 - [Redmine: #152051]
	DB: DBTXN-bodb02
*/

--dbo.TicketVoiding_SubIssueType
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Red Card/VAR Red Card - Home' WHERE SubIssueTypeId = 4
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Red Card/VAR Red Card - Away' WHERE SubIssueTypeId = 5

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (55, 1, 'Goal - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (56, 1, 'Goal - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (57, 1, 'Pen Goal/VAR Pen Goal - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (58, 1, 'Pen Goal/VAR Pen Goal - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (59, 1, 'Pen Goal/VAR Pen Goal')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (60, 1, 'Betradar/FC Goal - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (61, 1, 'Betradar/FC Goal - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (62, 1, 'Betradar/FC Goal')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (63, 1, '2YC (Red card) - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (64, 1, '2YC (Red card) - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (65, 1, 'Betradar/FC Red card - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (66, 1, 'Betradar/FC Red card - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (67, 1, 'HT/FT (Real Soccer)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (68, 1, 'Main Corner - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (69, 1, 'Main Corner - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (70, 1, 'Next Corner - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (71, 1, 'Next Corner - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (72, 1, 'Main Booking - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (73, 1, 'Main Booking - Away')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (74, 1, 'Next Booking - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (75, 1, 'Next Booking - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (76, 1, 'Next Booking - All')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (77, 1, 'Main Goal Kick - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (78, 1, 'Main Goal Kick - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (79, 1, 'Main Goal Kick')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (80, 1, 'Next Goal Kick - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (81, 1, 'Next Goal Kick - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (82, 1, 'Next Goal Kick')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (83, 1, 'Goal/PEN (1st & 2nd mark) - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (84, 1, 'Goal/PEN (1st & 2nd mark) - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (85, 1, 'Goal/PEN (1st & 2nd mark)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (86, 1, 'HT/FT (Futsal)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (87, 1, '* Goal/PEN Foul (OBS) - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (88, 1, '* Goal/PEN Foul (OBS) - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (89, 1, '* Goal/PEN Foul (OBS)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (90, 1, '* Goal/PEN Foul (not allowance) - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (91, 1, '* Goal/PEN Foul (not allowance) - Away')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (92, 1, '* Goal/PEN Foul (not allowance)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (93, 1, 'HT/FT (Virtual)')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

-------dbo.TicketVoiding_MessageTemplate
--HT/FT (Real Soccer)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 39
		,N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		)
--Next Booking
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified,JsonValue)
VALUES ( 40
		,N'Attn:[{{Sport type}}] Due to {{Next Booking}} Booking has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}],bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請註意:[{{Sport type}}] 由於 {{Next Booking}} 罰牌賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于 {{Next Booking}} 罚牌赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于 {{Next Booking}} 罚牌赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'[{"Name":"Next Booking","MsgEnglish":"Next Booking","MsgChineseTraditional":"Next Booking (TC)","MsgChineseSimplified":"Next Booking (SC)","MsgChineseNewSimplified":"Next Booking (New SC)"}]'
		)
--Main Goal Kick
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 42
		,N'Attn:[{{Sport type}}] Due to bets erroneously accepted in Goal Kick danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請註意:[{{Sport type}}] 由於註單在有龍門球的危險時段中誤被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的註單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于注单在有龙门球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于注单在有龙门球的危险时段中误被接受, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		)
--Next Goal Kick
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified,JsonValue)
VALUES ( 43
		,N'Attn:[{{Sport type}}] Due to {{Next Goal Kick}} Goal Kick has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}],bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請註意:[{{Sport type}}] 由於{{Next Goal Kick}} 龍門球賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于{{Next Goal Kick}} 龙门球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于{{Next Goal Kick}} 龙门球赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'[{"Name":"Next Goal Kick","MsgEnglish":"Next Goal Kick","MsgChineseTraditional":"Next Goal Kick (TC)","MsgChineseSimplified":"Next Goal Kick (SC)","MsgChineseNewSimplified":"Next Goal Kick (New SC)"}]'
		)
--HT/FT (Futsal)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 44
		,N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		)
--HT/FT (Virtual)
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 45
		,N'Attn:[{{Sport type}}] Due to match has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於賽事已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于赛事已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
		)

-------dbo.TicketVoiding_MessageTemplateSetting
--No.1,2,3
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,55)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,55)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,56)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,56)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,57)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,57)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,58)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,58)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,59)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,59)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,60)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,60)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,61)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,61)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,62)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,62)

--No.5,6
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (4,1,63)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,63)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (5,1,64)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,64)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (4,1,65)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,65)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (5,1,66)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,66)
--No.7

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (39,1,67)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,67)
--No.8

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (2,1,68)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,68)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (2,1,69)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,69)
--No.9

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (33,1,70)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,70)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (33,1,71)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,71)
--No.10

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (3,1,72)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,72)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (3,1,73)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,73)
--No.11

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (40,1,74)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,74)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (40,1,75)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,75)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (40,1,76)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,76)
--No.12

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (42,1,77)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,77)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (42,1,78)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,78)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (42,1,79)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,79)
--No.13

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (43,1,80)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,80)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (43,1,81)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,81)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (43,1,82)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,82)
--No.14
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,83)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,83)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,84)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,84)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,85)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,85)

--No.15
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (44,1,86)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,86)
--No.16
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,87)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,87)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,88)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,88)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,89)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,89)
--No.17
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,90)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,90)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,91)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,91)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (1,1,92)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,92)
--No.15
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (45,1,93)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,93)

-----------dbo.TicketVoiding_ReasonTemplate
--No.1,2,3
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,55,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,56,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,57,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,58,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,59,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,60,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,61,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,62,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
--No.5,6

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,63,'Danger Accept In Home Red Card',N'主隊紅牌危險時段中誤被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,64,'Danger Accept In Away Red Card',N'客队红牌危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,65,'Danger Accept In Home Red Card',N'主隊紅牌危險時段中誤被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,66,'Danger Accept In Away Red Card',N'客队红牌危险时段中误被接受')
--No.7

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,67,'Match Had Been Completed ',N'由于赛事已结束')
--No.8

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,68,'Danger Accept In Corner',N'在有角球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,69,'Danger Accept In Corner',N'在有角球的危险时段中误被接受')
--No.9

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,70,'Danger Accept In Corner',N'在有角球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,71,'Danger Accept In Corner',N'在有角球的危险时段中误被接受')
--No.10

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,72,'Danger Accept In Booking',N'有罚牌的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,73,'Danger Accept In Booking',N'有罚牌的危险时段中误被接受')
--No.11

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,74,'Booking has been completed',N'罚牌赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,75,'Booking has been completed',N'罚牌赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,76,'Booking has been completed',N'罚牌赛事已结束')
--No.12

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,77,'Danger Accept In Goal Kick',N'由于注单在有龙门球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,78,'Danger Accept In Goal Kick',N'由于注单在有龙门球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,79,'Danger Accept In Goal Kick',N'由于注单在有龙门球的危险时段中误被接受')
--No.13

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,80,'Goal Kick has been completed',N'龙门球赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,81,'Goal Kick has been completed',N'龙门球赛事已结束')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,82,'Goal Kick has been completed',N'龙门球赛事已结束')
--No.14

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,83,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,84,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,85,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
--No.15

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,86,'Match Had Been Completed ',N'由于赛事已结束')
--No.16

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,87,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,88,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,89,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
--No.17
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,90,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,91,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,92,'Danger Accept In Goal',N'有进球的危险时段中误被接受')
--No.18
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,93,'Match Had Been Completed ',N'由于赛事已结束')
