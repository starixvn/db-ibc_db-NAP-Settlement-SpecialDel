/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverVSBetRadar_Upd] 
	@TicketType					VARCHAR(100),
	@Type						VARCHAR(100)	= NULL,
	@MatchId					INT				= NULL,		
	@TransIds					VARCHAR(MAX)	= '',
    @UserId						INT,
    @IP							VARCHAR(15)
AS
/*  
	Created by: 20170607@Kent  
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]		
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]	
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230330@July: Write log into table TVS_UserActionLog [Redmine: #185245]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's Explanation:			
		- @TicketType:		
		'Single': Single ticket
		'Mix Parlay': Parlay ticket
		
		- @Type:		
		'Sub': Sub-parlay ticket
		'Main': Main-parlay ticket
		
		- @TransIds : Main transids.
*/
BEGIN
	SET NOCOUNT ON
	
	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN
			SET @sqlCommand = 'EXEC dbo.NAP_SpecialDelete_RecoverVSBetRadar_Upd '
				+ CASE WHEN @TicketType IS NULL THEN '' ELSE '@TicketType = ''' + CONVERT(NVARCHAR(50), @TicketType) + '''' END
				+ CASE WHEN @Type IS NULL THEN '' ELSE ',@Type = ''' + CONVERT(NVARCHAR(50), @Type) + '''' END
				+ CASE WHEN @TransIds IS NULL THEN '' ELSE ',@TransIds = ''' + CONVERT(NVARCHAR(MAX), @TransIds) + '''' END
				+ CASE WHEN @UserId IS NULL THEN '' ELSE ',@UserId = ' + CONVERT(NVARCHAR(50), @UserId) END
				+ CASE WHEN @IP IS NULL THEN '' ELSE ',@IP = ''' + CONVERT(NVARCHAR(50), @IP) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	IF @TicketType = 'Single'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverSingleVSBetRadar_Upd]			
			@TransIds = @TransIds,
			@UserID = @UserID,
			@IP= @IP
	END
	ELSE IF @TicketType = 'Mix Parlay' AND @Type = 'Main'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverMainParlayVSBetRadar_Upd] 
			@TransIds = @TransIds,				
			@UserID = @UserID,
			@IP = @IP
	END
	ELSE IF @TicketType = 'Mix Parlay' AND @Type = 'Sub'			
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverSubParlayVSBetRadar_Upd] 
			@MatchId = @MatchId,		
			@TransIds = @TransIds,				
			@UserID = @UserID,
			@IP = @IP
	END
	
	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN     
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserId, @MatchId, GETDATE(),@SubmittedDate)
		END      
	END TRY
	BEGIN CATCH
	END CATCH

	SET NOCOUNT OFF		
END
GO