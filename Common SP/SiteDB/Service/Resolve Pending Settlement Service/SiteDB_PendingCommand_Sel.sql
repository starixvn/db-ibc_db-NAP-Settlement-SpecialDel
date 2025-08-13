/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.SiteDB_PendingCommand_Sel
    @SiteDBGroupID SMALLINT
	,@batch SMALLINT
AS
/*	
	Created: 20250416@Louisa
	Task:Enhance settlement flow when sitedb have down time [Redmine:#217722]
	DB: DBCTG/bodb02
	
	Revisions:
		- 20250416@Louisa: Enhance settlement flow when sitedb have down time [Redmine:#217722]
		- 20250523@Louisa: Enhance settlement flow when sitedb have down time - Phase 2 [Redmine:#227313]
AS

*/
BEGIN
	DECLARE @tmp_SettlePending TABLE
	(	 pID			INT 
		,MatchId		INT	 
		,ProductType	VARCHAR(50)	
		,SPName			VARCHAR(100)
		,Parameter		VARCHAR (MAX)
		,SystemName		VARCHAR(50)	
		,AdminID		INT		
		,Action			VARCHAR(20)		
		,CreateDate		DATETIME
	)

	DECLARE @tmp_TVSPending TABLE	( TransId BIGINT, MatchId INT, SiteDBGroupID SMALLINT )

	DECLARE @MaxTime DATETIME
	
    INSERT INTO  @tmp_SettlePending 
    SELECT TOP (@batch)
		pID
		,matchid		
		,ProductType	
		,SPName
		,Parameter
		,SystemName
		,AdminID
		,Action
		,CreateDate
	FROM SiteDB_PendingCommand c WITH(NOLOCK)
	WHERE SiteDBGroupID = @SiteDBGroupID 
		AND StatusID = 0
	ORDER BY pID ASC

	SELECT @MaxTime = MAX(CreateDate) FROM @tmp_SettlePending

	INSERT INTO @tmp_TVSPending ( TransId, MatchId)
	SELECT TransId, Matchid 
	FROM TicketVoiding_PendingMarkTickets WITH(NOLOCK)
	WHERE CreatedDate <= @MaxTime
		AND StatusId = 1

	IF EXISTS (SELECT TOP 1 1 FROM @tmp_TVSPending WHERE MatchId = 29)
	BEGIN
		INSERT INTO @tmp_TVSPending (Matchid)
		SELECT DISTINCT bm.Matchid
		FROM @tmp_TVSPending tvs 
			INNER JOIN bettrans b WITH(NOLOCK) 
				ON tvs.TransId = b.TransId
			INNER JOIN bettransm bm
				ON bm.refno = b.refno
		WHERE tvs.MatchId =29

	END

	DELETE s
	FROM @tmp_SettlePending s
		INNER JOIN @tmp_TVSPending tvs 
			ON s.MatchId = tvs.MatchId
	WHERE tvs.MatchId <> 29

	 SELECT	pID
			,matchid		
			,ProductType	
			,SPName
			,Parameter
			,SystemName
			,AdminID
			,Action
			,CreateDate
	FROM  @tmp_SettlePending 
	ORDER BY pID ASC

END
 
  

