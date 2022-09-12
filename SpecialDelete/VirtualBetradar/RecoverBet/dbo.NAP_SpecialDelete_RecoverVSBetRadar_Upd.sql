/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverVSBetRadar_Upd] 
	@TicketType					VARCHAR(100),
	@Type						VARCHAR(100)	= NULL,
		
	@MatchId					INT				= 0,		
	@TransIds					VARCHAR(MAX)	= '',
		
    @UserID						INT,
    @IP							VARCHAR(15)
AS
/*  
	Created by: Kent  
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]		
		- 20210617@July: TVS - Modify the way to get move bet date [Redmine: #154974]	
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

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
	
	SET NOCOUNT OFF		
END
GO