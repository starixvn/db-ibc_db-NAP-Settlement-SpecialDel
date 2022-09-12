/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd] 
	@SearchBy				VARCHAR(100),
	
	@MatchId				INT = 0,	
	@TransIds				VARCHAR(MAX) = '',
	
	@SubTransIds			VARCHAR(MAX) = '',
	
	@UserName 				NVARCHAR(50),
    @Password				NVARCHAR(50),
    @UserID					INT,
    @IP						VARCHAR(15),
    @Reason					NVARCHAR(500)	= '',
	@ReasonSC				NVARCHAR(500)	= ''
AS
/*  
	Created by: Kent  
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02	    

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]
		- 20181207@Alan: Support Chinese Email [105976]	
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's Explanation:
		- @SearchBy:		
		'MatchId': Search by @MatchId + @BetTypes
		'SubTransIds': Search by @SubTransIds
		
		- @TransIds : Main transids.
		
		- @SubTransIds : TransIds of sub parlay tickets
*/
BEGIN
	SET NOCOUNT ON	
	
	IF @SearchBy = 'MatchId'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarByMatchId_Upd]
			@MatchId = @MatchId,
			@TransIds = @TransIds,
			@UserName = @UserName,
			@Password = @Password,
			@UserID	= @UserID,
			@IP	= @IP,
			@Reason	= @Reason,
			@ReasonSC = @ReasonSC
	END
	ELSE IF @SearchBy = 'SubTransIds'
	BEGIN
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarBySubIds_Upd]
			@SubTransIds = @SubTransIds,
			@UserName = @UserName,
			@Password = @Password,
			@UserID	= @UserID,
			@IP	= @IP,
			@Reason	= @Reason,
			@ReasonSC = @ReasonSC
	END
						
	SET NOCOUNT OFF
END
GO