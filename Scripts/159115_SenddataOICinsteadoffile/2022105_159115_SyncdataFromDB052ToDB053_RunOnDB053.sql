/*<info serverAlias="DBLIC_STANDBY-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211118@July
	Task: Send data to OIC instead of file - Sync data from DB052 to DB053 - [Redmine: #159115]
	DB: DBLIC_STANDBY-bodb_Licensee
*/


DECLARE @SessionIDs VARCHAR(MAX) ='0a326dcd-bcb4-42aa-8799-2afae710188a'
		,@ResultID  BIGINT, @SessionID UNIQUEIDENTIFIER, @SiteName NVARCHAR(50), @MatchID INT, @EventDate DATETIME, @CreatedDate DATETIME, @ModifiedDate DATETIME
		,@ResultID_New BIGINT
CREATE TABLE #tmpSessionID (SessionID VARCHAR(50))

INSERT INTO #tmpSessionID (SessionID)
SELECT DISTINCT val
FROM bodb02.dbo.f_SplitString(@SessionIDs, ',')
WHERE val <> ''
OPTION (MAXRECURSION 0)

CREATE TABLE #LicenseeResultAmendmentSource (
	ResultID	 BIGINT,
	SessionID	 UNIQUEIDENTIFIER,
	SiteName	 NVARCHAR(50),
	MatchID		 INT,
	EventDate	 DATETIME,
	CreatedDate  DATETIME,
	ModifiedDate DATETIME,
	IsFinish     BIT
)

INSERT INTO #LicenseeResultAmendmentSource(ResultID, SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate) 
SELECT	a.ResultID, a.SessionID, a.SiteName, a.MatchID, a.EventDate, a.CreatedDate, a.ModifiedDate
FROM db052.bodb_licensee.dbo.LicenseeResultAmendment a WITH(NOLOCK)
	INNER JOIN #tmpSessionID b ON a.SessionID = b.SessionID

WHILE (1 =1)
BEGIN
	SET @ResultID_New = 0

	UPDATE TOP (1) m 
	SET m.IsFinish = 1
		,@ResultID = m.ResultID 
		,@SessionID = m.SessionID
		,@SiteName = m.SiteName
		,@MatchID = m.MatchID
		,@EventDate = m.EventDate
		,@CreatedDate = m.CreatedDate
		,@ModifiedDate = m.ModifiedDate
	FROM #LicenseeResultAmendmentSource m 
	WHERE m.IsFinish IS NULL 

	IF @@ROWCOUNT = 0 BREAK;

	INSERT INTO dbo.LicenseeResultAmendment(SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate)
	SELECT @SessionID,@SiteName,@MatchID,@EventDate,@CreatedDate,@ModifiedDate

	SET @ResultID_New = SCOPE_IDENTITY()

	INSERT INTO dbo.LicenseeResultAmendmentDetails(ResultID,TransID,CustID,Recommend)
	SELECT @ResultID_New, TransID, CustID, Recommend 
	FROM db052.bodb_licensee.dbo.LicenseeResultAmendmentDetails a WITH(NOLOCK)
	WHERE a.ResultID = @ResultID

END

DROP TABLE #LicenseeResultAmendmentSource
DROP TABLE #tmpSessionID