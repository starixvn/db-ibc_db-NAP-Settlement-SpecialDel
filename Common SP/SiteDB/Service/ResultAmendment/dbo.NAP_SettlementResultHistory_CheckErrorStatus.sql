/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_CheckErrorStatus]
	 @MatchId		INT		
	,@SessionID		VARCHAR(50)		
	,@CreatedDate	DATETIME	
	,@ActualResult	VARCHAR(MAX)	
AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBSIG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]
*/
BEGIN	
	SET NOCOUNT ON
	
	SELECT SessionID
	FROM SettlementResultHistory WITH(NOLOCK)
	WHERE matchId = @MatchId
		AND CreatedDate < @CreatedDate
		AND ActualResult = @ActualResult
		AND StatusID = 99
END