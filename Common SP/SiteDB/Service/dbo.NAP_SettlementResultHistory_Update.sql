/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[dbo.NAP_SettlementResultHistory_Schedule]
	 @MatchId					INT		
	,@SessionID				    VARCHAR(50)		
	,@StatusID					TINYINT		
AS
/*	
	Created by: 20221026@Kathy
	Task: Settlement  
	
	Revisions:
		- 20221026@Kathy: Enhance settlement performance of siteDB on Central/SubDB [178694]

	Param's Explanation:  
		   
*/
BEGIN	
	SET NOCOUNT ON

	UPDATE SettlementResultHistory
	SET StatusID = @StatusID
	WHERE matchId = @MatchId
		AND StatusID = @StatusID

END