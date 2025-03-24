/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/1
/*
    Created: 20250318@Aries
	Task: Sportsbook » SOP » Soccer » Phase 2 [Redmine: #220444]
	DB: DBPRO/bodb02
*/
USE bodb02
/*
        The list of bet types is retrieved from Google Sheets
        -https://docs.google.com/spreadsheets/d/1Bd4P2ZhlUlo9nJ8qc0rUzcvRbQXn01-McmWTai9yOio/edit?gid=1272824640#gid=1272824640
        -",{""ID"": " & A2 & ", ""Group"": """ & D2 & """}"
*/


DECLARE @json NVARCHAR(MAX) = '[{"ID":7,"Group":"1H"},{"ID":8,"Group":"1H"},{"ID":12,"Group":"1H"},{"ID":15,"Group":"1H"},{"ID":16,"Group":"BothHalf"},{"ID":17,"Group":"2H"},{"ID":18,"Group":"2H"},{"ID":30,"Group":"1H"},{"ID":126,"Group":"1H"},{"ID":127,"Group":"1H"},{"ID":128,"Group":"BothHalf"},{"ID":403,"Group":"1H"},{"ID":404,"Group":"1H"},{"ID":405,"Group":"2H"},{"ID":410,"Group":"1H"},{"ID":411,"Group":"1H"},{"ID":412,"Group":"1H"},{"ID":414,"Group":"1H"},{"ID":416,"Group":"BothHalf"},{"ID":419,"Group":"2H"},{"ID":420,"Group":"2H"},{"ID":421,"Group":"2H"},{"ID":426,"Group":"1H"},{"ID":427,"Group":"1H"},{"ID":428,"Group":"2H"},{"ID":429,"Group":"2H"},{"ID":430,"Group":"2H"},{"ID":431,"Group":"2H"},{"ID":432,"Group":"2H"},{"ID":433,"Group":"2H"},{"ID":434,"Group":"BothHalf"},{"ID":435,"Group":"BothHalf"},{"ID":436,"Group":"BothHalf"},{"ID":437,"Group":"BothHalf"},{"ID":438,"Group":"BothHalf"},{"ID":439,"Group":"BothHalf"},{"ID":440,"Group":"BothHalf"},{"ID":441,"Group":"BothHalf"},{"ID":442,"Group":"BothHalf"},{"ID":443,"Group":"BothHalf"},{"ID":444,"Group":"BothHalf"},{"ID":445,"Group":"BothHalf"},{"ID":446,"Group":"BothHalf"},{"ID":447,"Group":"BothHalf"},{"ID":452,"Group":"BothHalf"},{"ID":453,"Group":"1H"},{"ID":456,"Group":"1H"},{"ID":457,"Group":"1H"},{"ID":459,"Group":"1H"},{"ID":463,"Group":"1H"},{"ID":464,"Group":"1H"},{"ID":466,"Group":"1H"},{"ID":471,"Group":"1H"},{"ID":472,"Group":"2H"},{"ID":474,"Group":"1H"},{"ID":476,"Group":"1H"},{"ID":478,"Group":"1H"},{"ID":484,"Group":"1H"},{"ID":485,"Group":"1H"},{"ID":487,"Group":"1H"},{"ID":489,"Group":"1H"},{"ID":490,"Group":"2H"},{"ID":492,"Group":"1H"},{"ID":493,"Group":"BothHalf"},{"ID":494,"Group":"1H"},{"ID":495,"Group":"2H"},{"ID":496,"Group":"BothHalf"},{"ID":497,"Group":"BothHalf"}]';

UPDATE sp
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.groupResult', j.[Group])
FROM SettlementSpecialBettypeProfile as sp
    JOIN OPENJSON(@json) WITH (ID INT, [Group] NVARCHAR(50)) AS j ON sp.Bettype = j.ID
WHERE  sp.sporttype = 1