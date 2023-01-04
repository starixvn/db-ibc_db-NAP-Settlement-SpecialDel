/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_CheckVoidBetPermission_TransInfo] 
(
	@TransIds  VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20221124
	Task: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20221124@Max: Create new SP [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]

	Param's explanation:	
		- @TransIds: '12343091763609600,12343108943478784'
		
*/
BEGIN
	SET NOCOUNT ON	

	DECLARE @SiteDBGroupID SMALLINT = 0 
		,@TransInfoJson VARBINARY(MAX)

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	DECLARE @TransIdTemp TABLE (transid BIGINT PRIMARY KEY)

	INSERT INTO @TransIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	CREATE TABLE #TransInfo (
		matchid			INT
	    ,transid		BIGINT
	    ,Subtransid		BIGINT
	    ,bettype		SMALLINT
	    ,betdaqid		BIGINT
	    ,statusID		TINYINT
	    ,SubstatusID	TINYINT
	    ,IsMixParlay	BIT DEFAULT(0)
	    ,IsMoved14		BIT DEFAULT(0)
	    ,SiteDBGroupID	SMALLINT
    )

	--Search tickets single
	INSERT INTO #TransInfo(
		matchid 
		,transid
		,Subtransid 
		,bettype 
		,betdaqid 
		,statusID 
		,SubstatusID 
		,IsMixParlay
		,IsMoved14
		,SiteDBGroupID
	)
	SELECT b.matchid
		,b.TransId
		,b.transid AS SubTransID
		,b.bettype
		,b.betdaqid 
		,b.statusID 
		,b.statusID AS SubstatusID 
		,CASE WHEN b.bettype IN (9,29,2799) THEN 1 ELSE 0 END IsMixParlay
		,0 AS IsMoved14
		,b.SiteDBGroupID
	FROM @TransIdTemp t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE b.SiteDBGroupID = @SiteDBGroupID

	--Search tickets parlay
	IF EXISTS (SELECT TOP(1) 1 FROM @TransIdTemp t
					INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = t.transid AND bm.SiteDBGroupID = @SiteDBGroupID
			)
	BEGIN
		INSERT INTO #TransInfo(
			matchid 
			,transid
			,Subtransid 
			,bettype 
			,betdaqid 
			,statusID 
			,SubstatusID 
			,IsMixParlay 
			,IsMoved14
			,SiteDBGroupID
		)
		SELECT bm.matchid
			  ,bm.TransId
			  ,bm.transid AS SubTransID
			  ,bm.bettype
			  ,NULL AS betdaqid
			  ,bm.statusID 
			  ,bm.statusID AS SubstatusID
			  ,1 AS IsMixParlay
			  ,0 AS IsMoved14
			  ,bm.SiteDBGroupID
		FROM @TransIdTemp t
			INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.TransId = t.transid
		WHERE bm.SiteDBGroupID = @SiteDBGroupID
	END

	--Search tickets 14
	IF EXISTS (SELECT TOP(1) 1 FROM @TransIdTemp t
					INNER JOIN dbo.bettrans14 b14 WITH (NOLOCK) ON b14.transid = t.transid AND b14.SiteDBGroupID = @SiteDBGroupID
			)
	BEGIN
		INSERT INTO #TransInfo(
			matchid 
			,transid
			,Subtransid 
			,bettype 
			,betdaqid 
			,statusID 
			,SubstatusID 
			,IsMixParlay 
			,IsMoved14 
			,SiteDBGroupID
		)
		SELECT b.matchid
			,b.TransId
			,b.transid AS SubTransID
			,b.bettype
			,b.betdaqid 
			,b.statusID 
			,b.statusID AS SubstatusID 
			,CASE WHEN b.bettype IN (9,29,2799) THEN 1 ELSE 0 END IsMixParlay
			,1 AS IsMoved14 
			,b.SiteDBGroupID
		FROM @TransIdTemp t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
		WHERE b.SiteDBGroupID = @SiteDBGroupID
	END

	--RETURN DATA
	SET @TransInfoJson = COMPRESS((SELECT matchid AS 'mid'
		,transid AS 't'
		,Subtransid 's_t'
		,bettype AS 'btype'
		,betdaqid AS 'bdaq'
		,statusID AS 'sid'
		,SubstatusID AS 's_sid'
		,IsMixParlay AS 'isP'
		,IsMoved14 AS 'isM'
		,SiteDBGroupID AS 'sitedb'
	FROM #TransInfo
	FOR JSON AUTO))

	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
	
	DROP TABLE #TransInfo
END

