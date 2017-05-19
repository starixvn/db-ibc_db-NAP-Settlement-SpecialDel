USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_Admin_Calculate_RefundHT]    Script Date: 07/15/2016 09:32:27 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/****** Object:  Stored Procedure dbo.NAP_Admin_Calculate_RefundHT    Script Date: 19/10/2015 10:46:58 AM ******/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_RefundHT] @matchid INT
    ,@IsExcludeBetdaq BIT = 0
    ,@IsExcludeBetfair BIT = 0
    ,@strBettypes VARCHAR(MAX) = NULL
AS
/*    Created by: Kathy
    Date: 20140213
    Task: Refund HT 
    DB: DBTXN/BODB02
    Revisions:
        - 20140426@Kathy: Add 1H total goal (126) [Redmine:#14449]
        - 20140729@Kathy: Add one more account(BF3) into BetFair's group [Redmine:#19665]
        - 20140620@Kathy: Apply BetRadar:
                            - Add 1st Correct Score(151)     
                            - Refund FT bettypes  [Redmine:#17142]
        - 20140811@Kathy: Support new 11 bettypes [Redmine:#19667]        
        - 20150422@Jamie: Manual Settlement Betradar phase 2 [Redmine: #27212]    
        - 20150919@Kathy: Intergrate Myanmar Odds ( 4 new bettypes: 301->304)    
        - 20151016@Kathy: Refund HT/FT & 2nd FT bettypes in case of match 3x30 [Redmine:#45626]
        - 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160120@Patrick: PH-AiO - Change request [Redmine: #51116]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]

    Param's Explanation:
        + @IsExcludeBetdaq: 
            = 1 : Refund Excluding BetDaq
            = 0 : Refund HT including BetDaq 
        + @IsExcludeBetfair: 
            = 1 : Refund Excluding Betfair
            = 0 : Refund HT including Betfair
                
*/
BEGIN
    SET NOCOUNT ON
	
	DECLARE @xml XML	
	SET @xml = CONVERT(XML, REPLACE('<root><r t="' + @strBettypes + '"/></root>', ',','"/><r t="'))
	
	DECLARE @tblBettypes TABLE (bettype SMALLINT)
	INSERT INTO @tblBettypes (bettype)
	SELECT T.c.value('./@t','SMALLINT')
	FROM @xml.nodes('/root/r') AS T(c)
	
    WHILE 1 = 1
    BEGIN
        UPDATE TOP (10000) dbo.bettrans WITH (ROWLOCK, UPDLOCK)
        SET [status] = N'Refund'
            ,statusID = 103
            ,ruben = 1
            ,winlost = actual_stake
            ,awinlost = 0
            ,mwinlost = 0
            ,swinlost = 0
            ,playercomm = 0
            ,comm = 0
            ,acomm = 0
            ,scomm = 0
        WHERE matchid = @matchid
            --AND [status] not in (N'Void', N'Reject')
            AND statusID NOT IN (103, 101, 102)          
            AND bettype IN (SELECT bettype FROM @tblBettypes)
            AND 1 = CASE 
                        WHEN @IsExcludeBetdaq = 1 AND (custid IN (50057, 879241, 103873, 78761, 851668, 878902) OR recommend = 1688156) THEN 0
                        WHEN @IsExcludeBetfair = 1 AND custid IN (2331, 1077687, 115770, 15523642) THEN 0
                        ELSE 1
                    END

        IF @@ROWCOUNT < 10000
            BREAK
    END
END

GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Calculate_RefundHT] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Calculate_RefundHT] TO [vnteam] AS [dbo]