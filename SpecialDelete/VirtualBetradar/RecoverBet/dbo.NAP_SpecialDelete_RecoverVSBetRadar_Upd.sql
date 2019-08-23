/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverVSBetRadar_Upd] 
	@TicketType					VARCHAR(100),
	@Type						VARCHAR(100)	= NULL,
		
	@MatchId					INT				= 0,		
	@TransIds					VARCHAR(MAX)	= '',
		
    @UserID						INT,
    @IP							VARCHAR(15),    
        
    @CompletedMatchIds			VARCHAR(MAX)	= '' OUTPUT, 
    @ReCalculatedMainTransIds   VARCHAR(MAX)	= '' OUTPUT,
    @NegativeBalanceUsers		VARCHAR(MAX)	= '' OUTPUT,
    @ErrMsg						NVARCHAR(200)	= '' OUTPUT,
    @ErrCode					INT				= 0	 OUTPUT
AS
/*  
	Created by: Kent  
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]			

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
	
	IF @TicketType = 'Single'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverSingleVSBetRadar_Upd]			
			@TransIds = @TransIds,
			@UserID = @UserID,
			@IP= @IP,
			@CompletedMatchIds = @CompletedMatchIds OUTPUT,     
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@ErrCode = @ErrCode OUTPUT
	END
	ELSE IF @TicketType = 'Mix Parlay' AND @Type = 'Main'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverMainParlayVSBetRadar_Upd] 
			@TransIds = @TransIds,				
			@UserID = @UserID,
			@IP = @IP,    		            
			@ReCalculatedMainTransIds = @ReCalculatedMainTransIds OUTPUT,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT,
			@ErrMsg = @ErrMsg OUTPUT,
			@ErrCode = @ErrMsg OUTPUT
	END
	ELSE IF @TicketType = 'Mix Parlay' AND @Type = 'Sub'			
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_RecoverSubParlayVSBetRadar_Upd] 
			@MatchId = @MatchId,		
			@TransIds = @TransIds,				
			@UserID = @UserID,
			@IP = @IP,    		            
			@ReCalculatedMainTransIds = @ReCalculatedMainTransIds OUTPUT,
			@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT,
			@ErrMsg	= @ErrMsg OUTPUT,
			@ErrCode = @ErrCode OUTPUT
	END
	
	SET NOCOUNT OFF		
END
GO