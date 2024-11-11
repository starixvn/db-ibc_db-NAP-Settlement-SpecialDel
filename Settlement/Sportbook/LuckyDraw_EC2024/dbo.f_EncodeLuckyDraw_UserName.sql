/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_EncodeLuckyDraw_UserName] (
	@UserName      VARCHAR(30)
)
RETURNS VARCHAR(30)
/*
	Created by: 20240401@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20240401@Aries: EC 2024-Correct Score Sharing and Lucky Draw-(Pool prize) [Redmine:#202309]

	Param's Explanation:  	   
*/
AS
BEGIN
	DECLARE @totalLen   INT         = 0
    SET  @totalLen = len(@UserName) 

    IF @totalLen < 3 OR @totalLen IS NULL
    BEGIN
        RETURN @UserName;
    END

    RETURN CONCAT(LEFT(@UserName, 3),'*****',RIGHT(@UserName, 3))
END
GO

