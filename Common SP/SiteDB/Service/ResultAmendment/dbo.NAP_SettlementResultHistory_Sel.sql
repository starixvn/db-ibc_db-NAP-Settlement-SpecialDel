/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Sel]
	 @StatusID		SMALLINT  = 0
	,@MatchId		INT		  = NULL

AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]
		- 20240403@Aries: Enhance MSite2 for Result Amendment [Redmine: #203084]

	Param's Explanation:  
					'
*/
BEGIN	
	SET NOCOUNT ON

	IF @StatusID = 0
	BEGIN
		SELECT h.matchid
			  ,h.SessionID
			  ,h.StatusID
			  ,h.CreatedDate
		FROM SettlementResultHistory AS h WITH(NOLOCK)
		WHERE h.StatusID IN (3,99) 
			AND h.matchid = ISNULL(@MatchId,h.matchid)
	END
	ELSE
	BEGIN
		SELECT h.matchid
			  ,h.SessionID
			  ,h.StatusID
			  ,h.CreatedDate
		FROM SettlementResultHistory AS h WITH(NOLOCK)
		WHERE h.StatusID = @StatusID
			AND h.matchid = ISNULL(@MatchId,h.matchid)
	END

END