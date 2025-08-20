/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20250815@Max
	Task: Auto Refund- Soccer- Penalty Shoot-out- Sudden Death - [Redmine: #227277]
	DB: DBPRO-bodb02
*/

USE bodb02

/*--------Update current setting----------*/
UPDATE s SET 
s.[Trigger] = '[{"action":"Cal","matchType":2,"childMatchType":201,"conditions":1,"targetIsCrrMatch":0,"targetIsCrrResource":0,"targetResource":"38101,38102,38103,38104,38105,38201,38202,38203,38204,38205,38301,38302,38303,38304,38305,38401,38402,38403,38404,38405,38501,38502,38503,38504,38505,386,387,390,391,393,376,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":0,"targetIsCrrResource":0,"targetResource":"38101,38102,38103,38104,38105,38201,38202,38203,38204,38205,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '00'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38101","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38102,38103,38104,38105,38202,38203,38204,38205,38301,38401,38501,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38301,38401,38501","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38101'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38102","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38103,38104,38105,38203,38204,38205,38302,38402,38502,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38302,38402,38502","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38102'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38103","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38104,38105,38204,38205,38303,38403,38503,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38303,38403,38503","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38103'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38104","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38105,38205,38304,38404,38504,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38304,38404,38504","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38104'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38105","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38305,38405,38505,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38305,38405,38505","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38105'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38201","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38102,38103,38104,38105,38202,38203,38204,38205,38301,38401,38501,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38301,38401,38501","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38201'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38202","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38203,38204,38205,38103,38104,38105,38302,38402,38502,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38302,38402,38502","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38202'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38203","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38204,38205,38104,38105,38303,38403,38503,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38303,38403,38503","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38203'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38204","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38205,38105,38304,38404,38504,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38304,38404,38504","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38204'

UPDATE s SET 
s.[Trigger] = '[{"action":"CfmRefundAdminSite","matchType":2,"childMatchType":202,"conditions":3,"targetIsCrrMatch":1,"targetIsCrrResource":1,"targetResource":"38205","targetResourceChildMatchType":202},{"action":"Refund","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38305,38405,38505,376,386,387,390,391,393,38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225","targetResourceChildMatchType":202},{"action":"Cal","matchType":2,"childMatchType":202,"conditions":0,"targetIsCrrMatch":1,"targetIsCrrResource":0,"targetResource":"38305,38405,38505","targetResourceChildMatchType":202}]'
,s.RepUpdateTime = [dbo].[f_GetDateTime2]()
FROM dbo.AutoRefundSetting s WITH (ROWLOCK, UPDLOCK)
WHERE s.Sporttype = 1 AND s.ResourceID = '38205'

/*--------Update current setting----------*/
/*--------Insert new setting------------*/
DECLARE @tmp_ResourceId AS TABLE (ResourceId VARCHAR(50))
INSERT INTO @tmp_ResourceId(ResourceId)
SELECT value
FROM string_split('38106,38107,38108,38109,38110,38111,38112,38113,38114,38115,38116,38117,38118,38119,38120,38121,38122,38123,38124,38125,38206,38207,38208,38209,38210,38211,38212,38213,38214,38215,38216,38217,38218,38219,38220,38221,38222,38223,38224,38225',',')

INSERT INTO dbo.AutoRefundSetting([Sporttype],[ResourceID],[Trigger],[Conditions],[RepUpdateTime])
SELECT 1,t.ResourceId,'[]'
	,'[{"matchType":2,"childMatchType":202,"conditions":[{"gID":1,"name":"Rule1","conditions":[{"sourceMatchType":3,"sourceChildMatchType":201,"sourceResource":"00","action":"Cal","conditions":1}]},{"gID":2,"name":"Rule2","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"00","action":"Cal","conditions":0},{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"'+ t.ResourceId +'","action":"CfmRefundAdminSite","conditions":3}]},{"gID":3,"name":"Rule3","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38105","action":"Refund","conditions":0}]},{"gID":4,"name":"Rule4","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38104","action":"Refund","conditions":0}]},{"gID":5,"name":"Rule5","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38103","action":"Refund","conditions":0}]},{"gID":6,"name":"Rule6","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38102","action":"Refund","conditions":0}]},{"gID":7,"name":"Rule7","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38101","action":"Refund","conditions":0}]},{"gID":8,"name":"Rule8","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38201","action":"Refund","conditions":0}]},{"gID":9,"name":"Rule9","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38202","action":"Refund","conditions":0}]},{"gID":10,"name":"Rule10","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38203","action":"Refund","conditions":0}]},{"gID":11,"name":"Rule11","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38204","action":"Refund","conditions":0}]},{"gID":12,"name":"Rule12","conditions":[{"sourceMatchType":1,"sourceChildMatchType":202,"sourceResource":"38205","action":"Refund","conditions":0}]}]}]'
	,[dbo].[f_GetDateTime2]()
FROM @tmp_ResourceId t
/*--------Insert new setting------------*/
