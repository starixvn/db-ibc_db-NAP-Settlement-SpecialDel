/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_GenerateLuckyDraw_VerificationCode] (
	@Rand1          FLOAT
   ,@Rand2          FLOAT
   ,@NewId1         VARCHAR(36)
   ,@NewId2         VARCHAR(36)
   ,@NewId3         VARCHAR(36)
)
RETURNS VARCHAR(20)
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
	DECLARE @verificationCode VARCHAR(20) = ''
	DECLARE @cnt TINYINT = 1

	SET @verificationCode = STUFF(LEFT (REPLACE(@NewId1,'-',''),12), CAST((Round((10 * @Rand1 + 1 ), 0)) AS INT), 1, CHAR(97 + Abs(Checksum(@NewId2)) % 26))
	WHILE (1=1)
	BEGIN
		SELECT @verificationCode = STUFF(@verificationCode, CAST((Round((10 * @Rand2 + 1 ), 0)) AS INT), 1, CHAR(97 + Abs(Checksum(@NewId3)) % 26))
		SET @cnt = @cnt + 1
		IF @cnt = 5
			BREAK
	END

    RETURN @verificationCode
END
GO
