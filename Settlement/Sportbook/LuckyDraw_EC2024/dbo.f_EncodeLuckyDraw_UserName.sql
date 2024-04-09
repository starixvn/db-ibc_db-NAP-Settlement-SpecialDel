/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
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
           ,@start      INT         = 4
           ,@len        INT         = 4
           ,@dymmyStr   VARCHAR(50) = '*'

    SET  @totalLen = len(@UserName) 

    IF @totalLen <= 3
    BEGIN
        RETURN @UserName;
    END

    IF @totalLen < 9
    BEGIN
        SET @len = @totalLen - 3
        SET @dymmyStr = REPLICATE('*', @len)

        RETURN STUFF(@UserName, @start, @len, @dymmyStr)
    END

    IF @totalLen >= 9
    BEGIN
        SET @len = @totalLen - 6
        SET @dymmyStr = REPLICATE('*', @len)

        RETURN STUFF(@UserName, @start, @len, @dymmyStr)
    END

    RETURN @UserName

END
GO
