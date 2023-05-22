/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_AutoUnmark_TransInfo_Select]
(
	 @MatchId		INT				= NULL
	,@Sporttype		VARCHAR(MAX)	= ''
	,@IsExcludeTest BIT				= 1
	,@MarkedBy		INT				= 0
)
AS
/*	Created by: 20220831@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20220831@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230427@July: Support sport Cricket for function Mark/Unmark Tickets [Redmine: #187052]

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	CREATE TABLE #tmp_TransId (transid BIGINT, matchid INT, userid INT, createddate DATETIME, refno BIGINT,statusID TINYINT, bettype SMALLINT, MarkType TINYINT, betid NVARCHAR(100))
	CREATE TABLE #CTE_FilterByTicketStatus(MatchId INT, transid BIGINT, bettype SMALLINT, UserId INT, CreatedDate DATETIME, MarkType INT, betid NVARCHAR(100))

	DECLARE @Sporttypes AS TABLE (sporttype SMALLINT)

	DECLARE @SiteDBGroupID	SMALLINT = 0
		   ,@TransInfoJson	VARBINARY(MAX)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	INSERT INTO @Sporttypes (sporttype)
	SELECT DISTINCT value AS sporttype
	FROM STRING_SPLIT(@Sporttype, ',')

	INSERT INTO #tmp_TransId (transid, matchid, userid, createddate, refno, statusID, bettype, MarkType, betid)
	SELECT mt.TransId
		,mt.MatchId
		,mt.UserId
		,mt.CreatedDate
		,CASE WHEN b.matchid = 29 THEN b.refno ELSE NULL END AS refno
		,b.statusID
		,CASE WHEN b.matchid = 29 THEN NULL ELSE b.bettype END AS bettype
		,CASE WHEN mt.MarkType = 2 THEN 2 ELSE 0 END AS MarkType
		,CASE WHEN b.matchid = 29 THEN NULL ELSE CONVERT(NVARCHAR(100), b.betid) END AS betid 
	FROM dbo.MarkedTransaction mt WITH (NOLOCK)
		INNER JOIN dbo.bettrans AS b WITH (NOLOCK) ON mt.TransId = b.transid 
		INNER JOIN dbo.match m WITH (NOLOCK) ON mt.MatchId = m.matchid
		INNER JOIN @Sporttypes s ON s.sporttype = m.sporttype
		INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
	WHERE ((@IsExcludeTest = 1 AND l.isTest = 0) OR @IsExcludeTest = 0)
		AND 1 = CASE WHEN @MatchId IS NULL THEN 1 
					 ELSE 
						CASE WHEN m.sporttype <> 50 AND m.matchid = @MatchId THEN 1 
								WHEN m.sporttype = 50 AND (m.matchid = @MatchId OR m.ParentID = @MatchId) THEN 1
								ELSE 0 END
						END
		AND ((mt.UserId = @MarkedBy) OR @MarkedBy = 0)
		AND m.sporttype <= 99
		AND 1 = CASE WHEN b.matchid <> 29 AND b.statusID IN (101,102) THEN 0 ELSE 1 END
		AND b.SiteDBGroupID = @SiteDBGroupID

	INSERT INTO #CTE_FilterByTicketStatus (transid, MatchId, bettype, UserId, CreatedDate, MarkType, betid)
	SELECT f.TransId
		,f.MatchId
		,f.bettype
		,f.UserId
		,f.CreatedDate
		,f.MarkType
		,f.betid 
	FROM #tmp_TransId AS f
	WHERE f.refno IS NULL

	UNION ALL
			
	SELECT f.TransId
		,f.MatchId
		,m.bettype
		,f.UserId
		,f.CreatedDate
		,f.MarkType
		,m.betcheck as betid
	FROM #tmp_TransId AS f
		INNER JOIN bettransm AS m WITH (NOLOCK, INDEX = IX_refno) ON f.matchid = m.matchid AND f.refno = m.refno
	WHERE m.statusID NOT IN (101, 102) AND m.SiteDBGroupID = @SiteDBGroupID
					
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
			,transid AS 't'
			,bettype AS 'btype'
			,UserId AS 'us'
			,CreatedDate AS 'crdate'
			,MarkType AS 'mt'
			,betid AS 'bid'
	FROM #CTE_FilterByTicketStatus
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson

	DROP TABLE #tmp_TransId
	DROP TABLE #CTE_FilterByTicketStatus

END