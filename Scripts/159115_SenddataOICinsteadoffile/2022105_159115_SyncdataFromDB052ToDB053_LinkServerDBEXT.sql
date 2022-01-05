/*<info serverAlias="DBLIC_STANDBY-bodb_Licensee" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211118@July
	Task: Send data to OIC instead of file - Sync data from DB052 to DB053 - [Redmine: #159115]
	DB: DBLIC_STANDBY-bodb_Licensee
*/


DECLARE @SessionIDs VARCHAR(MAX) =''

CREATE TABLE #tmpSessionID (SessionID VARCHAR(50))
CREATE TABLE #tmpResultID (ResultID BIGINT)

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
	ModifiedDate DATETIME
)

CREATE TABLE #LicenseeResultAmendmentDetailsSource
(
	ResultID	BIGINT,
	TransID		BIGINT,
	CustID		INT,
	Recommend	INT
)

INSERT INTO #LicenseeResultAmendmentSource(ResultID,SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate) 
SELECT	a.ResultID, a.SessionID, a.SiteName, a.MatchID, a.EventDate, a.CreatedDate, a.ModifiedDate
FROM DBEXT.bodb_licensee.dbo.LicenseeResultAmendment a WITH(NOLOCK)
	INNER JOIN #tmpSessionID b ON a.SessionID = b.SessionID

INSERT INTO #tmpResultID (ResultID)
SELECT DISTINCT ResultID
FROM #LicenseeResultAmendmentSource

SET IDENTITY_INSERT LicenseeResultAmendment ON
INSERT INTO dbo.LicenseeResultAmendment(ResultID,SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate)
SELECT ResultID,SessionID,SiteName,MatchID,EventDate,CreatedDate,ModifiedDate
FROM #LicenseeResultAmendmentSource a
SET IDENTITY_INSERT LicenseeResultAmendment OFF

INSERT INTO #LicenseeResultAmendmentDetailsSource(ResultID,TransID,CustID,Recommend) 
SELECT	a.ResultID, TransID, CustID, Recommend
FROM DBEXT.bodb_licensee.dbo.LicenseeResultAmendmentDetails a WITH(NOLOCK)
	INNER JOIN #tmpResultID b ON a.ResultID = b.ResultID

INSERT INTO dbo.LicenseeResultAmendmentDetails(ResultID,TransID,CustID,Recommend)
SELECT ResultID, TransID, CustID, Recommend 
FROM #LicenseeResultAmendmentDetailsSource 

DROP TABLE #LicenseeResultAmendmentSource
DROP TABLE #LicenseeResultAmendmentDetailsSource		
DROP TABLE #tmpResultID
DROP TABLE #tmpSessionID