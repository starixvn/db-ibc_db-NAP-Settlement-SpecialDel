/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchTicket_Checking]
	 @Matchid INT
AS
/*
    Created by: 20230808@Aries
    Task: Enhance Auto Refund for Tennis Matches [Redmine:#189433]
    DB: DBTXN/BODB02 
    
    Revisions: 
		- 20230808@Aries: Created [Redmine:#189433]
        - 20240502@Aries: Enhance Auto Refund for child matches of Tennis [Redmine:#204693]
*/
BEGIN
	SET NOCOUNT ON

    DECLARE  @IsCentral			BIT = 0	

    EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

    IF EXISTS (	SELECT TOP 1 1 FROM bettrans WITH(NOLOCK) WHERE matchid = @Matchid AND statusID IN (111,112,113) AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END)
    BEGIN  
        SELECT 1 AS IsExistTicket, 1 AS IsExistSettledTicket
        RETURN
    END

    IF EXISTS (	SELECT TOP 1 1 FROM bettransm WITH(NOLOCK) WHERE matchid = @Matchid AND statusID IN (111,112,113) AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END)
    BEGIN 
        SELECT 1 AS IsExistTicket, 1 AS IsExistSettledTicket
        RETURN
    END

    
    IF EXISTS (	SELECT TOP 1 1 FROM bettrans WITH(NOLOCK) WHERE matchid = @Matchid AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END)
    BEGIN  
        SELECT 1 AS IsExistTicket, 0 AS IsExistSettledTicket
        RETURN
    END

    IF EXISTS (	SELECT TOP 1 1 FROM bettransm WITH(NOLOCK) WHERE matchid = @Matchid AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END)
    BEGIN 
        SELECT 1 AS IsExistTicket, 0 AS IsExistSettledTicket
        RETURN
    END

    SELECT 0 AS IsExistTicket, 0 AS IsExistSettledTicket
    RETURN
END
GO