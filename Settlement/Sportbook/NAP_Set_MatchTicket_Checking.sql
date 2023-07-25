/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchTicket_Checking]
	 @Matchid INT
AS
/*
    Created by: 20230808@Aries
    Task: Enhance Auto Refund for Tennis Matches [Redmine:#189433]
    DB: DBTXN/BODB02 
    
    Revisions: 
		- 20230808@Aries: Created [Redmine:#189433]
*/
BEGIN
	SET NOCOUNT ON
    
    IF EXISTS (	SELECT TOP 1 1 FROM bettrans WITH(NOLOCK) WHERE matchid = @Matchid)
    BEGIN  
        SELECT 1 AS IsExistTicket
        RETURN
    END

    IF EXISTS (	SELECT TOP 1 1 FROM bettransm WITH(NOLOCK) WHERE matchid = @Matchid)
    BEGIN 
        SELECT 1 AS IsExistTicket
        RETURN
    END

    SELECT 0 AS IsExistTicket
    RETURN
END
GO