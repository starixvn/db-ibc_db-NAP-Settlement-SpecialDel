/*<info serverAlias="DBSIG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].NAP_SettlementResultHistory_Update
	 @MatchId					INT		
	,@SessionIDs				VARCHAR(MAX)		
	,@StatusID					SMALLINT	
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

	DECLARE @tmlSession TABLE(SessionID VARCHAR(50))

	INSERT INTO @tmlSession(SessionID)
	SELECT f.value
	FROM STRING_SPLIT(@SessionIDs, ',') f
	
	UPDATE  h
	SET  h.StatusID = CASE WHEN @StatusID >= 0 THEN @StatusID
						   WHEN @StatusID < 0 AND h.StatusID IS NULL THEN 0
						   WHEN @StatusID < 0 AND h.StatusID = 100 THEN 1
					  END 
		,h.ModifiedDate = GETDATE()
		,h.RepUpdateTime = SYSDATETIME()
	FROM SettlementResultHistory AS h WITH(UPDLOCK, ROWLOCK)
	WHERE h.matchId = @MatchId
		AND h.SessionID IN (SELECT t.SessionID FROM @tmlSession AS t)
END