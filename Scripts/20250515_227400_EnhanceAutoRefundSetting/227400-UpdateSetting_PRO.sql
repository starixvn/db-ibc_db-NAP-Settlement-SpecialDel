/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241223@Hughie
	Task: Change Setting AutoRefund [Redmine:#227400]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

DECLARE @DuplicateResources TABLE (ResourceID VARCHAR(10))

INSERT INTO @DuplicateResources
SELECT ResourceID 
FROM AutoRefundSetting WITH (NOLOCK)
WHERE ResourceID IN ('376', '386', '387', '390', '391', '393')
AND Sporttype = 1
AND (
    LEN(Conditions) - LEN(REPLACE(Conditions, '"sourceResource":"38205","action":"Refund"', '')) 
) / LEN('"sourceResource":"38205","action":"Refund"') = 2
    
IF EXISTS (SELECT 1 FROM @DuplicateResources)
BEGIN
    DECLARE @UpdateTable TABLE (
        ResourceID VARCHAR(10),
        OriginalJSON NVARCHAR(MAX),
        UpdatedJSON NVARCHAR(MAX)
    )

    INSERT INTO @UpdateTable (ResourceID, OriginalJSON)
    SELECT ResourceID, Conditions 
    FROM AutoRefundSetting WITH (NOLOCK)
    WHERE ResourceID IN (SELECT ResourceID FROM @DuplicateResources)
    AND Sporttype = 1

    UPDATE @UpdateTable
    SET UpdatedJSON = 
        STUFF(
            OriginalJSON, 
            CHARINDEX('"sourceResource":"38205"', OriginalJSON), 
            LEN('"sourceResource":"38205"'), 
            '"sourceResource":"38105"'
        )

    UPDATE ars WITH (ROWLOCK, UPDLOCK)
    SET ars.Conditions = ut.UpdatedJSON,
        ars.RepUpdateTime = [dbo].[f_GetDateTime2]()
    FROM AutoRefundSetting ars
    INNER JOIN @UpdateTable ut ON ars.ResourceID = ut.ResourceID
    WHERE ars.Sporttype = 1
    
    SELECT 'Updated ResourceIDs: ' + 
           STUFF((SELECT ', ' + ResourceID FROM @DuplicateResources FOR XML PATH('')), 1, 2, '')
END
ELSE
BEGIN
    SELECT 'No duplicate sourceResource="38205" found that need updating.'
END