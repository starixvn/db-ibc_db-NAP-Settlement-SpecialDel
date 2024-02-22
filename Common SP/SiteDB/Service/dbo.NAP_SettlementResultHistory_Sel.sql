/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SettlementResultHistory_Sel]
	 @StatusID		SMALLINT  = NULL

AS
/*	
	Created by: 20231214@Aries
	Task: Settlement  
	DB: DBCTG-bodb02
	
	Revisions:
		- 20231214@Aries: Result Amendment [Redmine: #196401]

	Param's Explanation:  
					'
*/
BEGIN	
	SET NOCOUNT ON

	SELECT h.matchid
		  ,h.SessionID
		  ,h.StatusID
		  ,h.CreatedDate
	FROM SettlementResultHistory AS h WITH(NOLOCK)
	WHERE h.StatusID = ISNULL(@StatusID,h.StatusID)

END