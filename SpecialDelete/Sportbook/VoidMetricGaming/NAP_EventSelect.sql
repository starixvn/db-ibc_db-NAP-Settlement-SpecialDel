USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_EventSelect]    Script Date: 12/10/2015 10:26:33 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/****** Object:  Stored Procedure dbo.NAP_EventSelect    Script Date: 24/11/2015 11:14:39 AM ******/
ALTER PROCEDURE [dbo].[NAP_EventSelect] 
    @MatchId    INT
    ,@VendorID  INT = 5
    ,@ErrCode    INT = 0 OUTPUT
    ,@ErrMsg    NVARCHAR(200) = '' OUTPUT
AS
/*  
    Created: 20150623@Dominic  
    Task : Get event details
    DB: DBPRO/bodb02  

      
    Revisions:    
		- 20151209@Kathy: Only display "Open Time" when event have not been settled yet [Redmine:#49019]
          
    Param's Explanation:  

*/
BEGIN
    IF NOT EXISTS(SELECT TOP 1 1 FROM [ResultDetail3rd] WITH(NOLOCK) WHERE MatchID = @MatchId)
    BEGIN
        SELECT @ErrCode = 101, @ErrMsg = 'Invalid match'
        RETURN
    END
    SELECT	GameID
			,CASE 
				WHEN gameid = 805 THEN Custom1+'%' 
				WHEN GameID = 801 
					AND ISNULL(Custom1,'') <> ''
					AND ((ResultStatusID = 1 AND SettlementStatusID = 0) 
							OR (ResultStatusID = 5 AND SettlementStatusID = 1)
						) THEN SUBSTRING(Custom1,1,CHARINDEX('-',Custom1) - 1) --  only display "Open Time" when event have not been settled yet. 
				ELSE Custom1 
				END Custom1
    FROM	[dbo].[ResultDetail3rd] WITH(NOLOCK)
    WHERE	MatchID = @MatchId 
			AND VendorID = @VendorID
    ORDER BY GameID,Custom1
END

GO
