/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadar_Sel]
	@SearchBy		 VARCHAR(100),
	
	@MatchId		 INT = 0,
	@BetTypes		 VARCHAR(MAX) = '',
	
	@SubTransIds	 VARCHAR(MAX) = '',
	
	@InvalidTransIds VARCHAR(MAX) = '' OUTPUT
AS
/*  
	Created by: Kent
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02   
	Original:NAP_SpecialDelete_VoidParlaySubVSBetRadar_Sel     

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]	
		- 20170831@Kent: VS BetRadar Change on Void Parlay Sub Bets [Redmine:#82405]		

	Param's Explanation:			
		- @SearchBy:		
		'MatchId': Search by @MatchId + @BetTypes
		'SubTransIds': Search by @SubTransIds
		
		- @SubTransIds : TransIds of sub parlay tickets
*/
BEGIN
	SET NOCOUNT ON
	
	SET @InvalidTransIds = ''
	
	IF @SearchBy = 'MatchId'
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarByMatchId_Sel]
			@MatchId = @MatchId,
			@BetTypes = @BetTypes	  
	ELSE IF @SearchBy = 'SubTransIds'
		EXEC [dbo].[NAP_SpecialDelete_VoidParlaySubVSBetRadarBySubIds_Sel]
			@SubTransIds = @SubTransIds,	
			@InvalidTransIds = @InvalidTransIds OUTPUT			
	
	SET NOCOUNT OFF		
END
GO