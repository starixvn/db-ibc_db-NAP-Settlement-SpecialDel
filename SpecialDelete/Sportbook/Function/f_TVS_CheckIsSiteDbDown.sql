/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_TVS_CheckIsSiteDbDown]
(
    @SiteDBGroupID SMALLINT,
    @CurrentSiteDBGroupID SMALLINT,
    @OnlineServerIds VARCHAR(10)
)
RETURNS BIT
AS
/*
	Created by: 20251011@Lani
	Task: [TVS] Danger Accepted/Wrong Score - Display the excluding ticket based on the business rules - CICD rule [Redmine: #236067]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions: 
		- 20251011@Lani: Create new function - Refactor code following CI/CD rules [Redmine: #236067]
*/
BEGIN
    DECLARE @Result BIT = 0
    
	DECLARE @TmpServerIds AS TABLE (ServerId SMALLINT)

	INSERT INTO @TmpServerIds (ServerId) 
	SELECT value
	FROM STRING_SPLIT(@OnlineServerIds,',')
	WHERE value <> ''

    IF @SiteDBGroupID = @CurrentSiteDBGroupID 
       AND EXISTS (SELECT 1 FROM @TmpServerIds WHERE ServerId = @SiteDBGroupID)
    BEGIN
        SET @Result = 1
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM @TmpServerIds WHERE ServerId = @CurrentSiteDBGroupID) --Get ticket of sitedbdown
    BEGIN
        SET @Result = 1
    END
    
    RETURN @Result
END
GO