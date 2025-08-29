/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_BriefInfo_Select] 
(
	@VoidingHistoryIds VARCHAR(MAX) = ''
   ,@OnlineServerId	   VARCHAR(10) = NULL
)
AS
/*	
	Created by: 20240814@Max
	Task: [TVS] Manage Request - Enhancements [Redmine: #208623]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions:	
		- 20240814@Max: Create SP [Redmine: #208623]
		- 20250828@July: [TVS] ScaleOut DBTrans [Phase 7] Manage Request page [Redmine: #236438]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @SiteDBGroupID			 SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	CREATE TABLE #tmpTicket (
		TransId			BIGINT
		,subTransId     BIGINT
		,matchid		INT
		,custid			INT
		,Srecommend		INT
		,IsCashOut		BIT DEFAULT(0)
		,IsDeposit      BIT DEFAULT(0) --1: Deposit/ 0: Credit
		,SiteDBGroupID	SMALLINT
		,IsCancelCashOut BIT DEFAULT(0)
		,site			NVARCHAR(100)
		,IsChinaView	BIT DEFAULT(0)
	)
	
	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	DECLARE @tmp_VoidingHistory AS TABLE (VoidingHistoryId INT)
	DECLARE @tmpOnlineServerId AS TABLE (ServerId SMALLINT)

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmpOnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	INSERT INTO @tmp_VoidingHistory (VoidingHistoryId)
	SELECT value AS VoidingHistoryId
	FROM STRING_SPLIT(@VoidingHistoryIds, ',')
	WHERE value <> ''

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, custid, SiteDBGroupID, IsCancelCashOut)
	SELECT	z.transid			
			,z.matchid
			,z.custid
			,z.SiteDBGroupID
			,CASE WHEN z.comstatus = 'CO' THEN 1 ELSE 0 END AS IsCancelCashOut
	FROM	dbo.zzzbettrans z WITH(NOLOCK)
	WHERE	EXISTS(SELECT 1 FROM @tmp_VoidingHistory WHERE VoidingHistoryId = z.VoidingHistoryId) 
			AND 1 = CASE WHEN z.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1
						 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = z.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
						 ELSE 0 END

	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, custid, SiteDBGroupID)
	SELECT	zm.transid		
			,zm.matchid
			,zm.custid
			,zm.SiteDBGroupID
	FROM	dbo.zzzbettransm zm WITH(NOLOCK)
	WHERE	EXISTS(SELECT 1 FROM @tmp_VoidingHistory WHERE VoidingHistoryId = zm.VoidingHistoryId) 
			AND 1 = CASE WHEN zm.SiteDBGroupID = @SiteDBGroupID AND EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1
						 WHEN NOT EXISTS(SELECT 1 FROM @tmpOnlineServerId WHERE ServerId = zm.SiteDBGroupID) THEN 1  -- Get ticket sitedb down
						 ELSE 0 END

	UPDATE t 
		SET srecommend = b.srecommend
			,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
	FROM	#tmpTicket t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid AND t.SiteDBGroupID = b.SiteDBGroupID
			
	--For void14 abnormal account only (only single + main parlay)
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId)
	BEGIN
		UPDATE t 
			SET srecommend = b.srecommend
				,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK)
				ON t.TransId = b.transid AND t.SiteDBGroupID = b.SiteDBGroupID
	END

	UPDATE	t
		SET transid = b.transid
			,srecommend = b.srecommend
	FROM	#tmpTicket t
		INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid AND t.SiteDBGroupID = bm.SiteDBGroupID
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND t.SiteDBGroupID = b.SiteDBGroupID
	WHERE EXISTS(SELECT 1 FROM f_TVS_SpeciallyBettypes() f WHERE f.TypeId IN (0,1) AND bettype = b.matchid)

	UPDATE	t
		SET site = c.site
			,IsChinaView = ISNULL(s.IsChinaView, 0)
	FROM	#tmpTicket t
		INNER JOIN CustDB.dbo.customer c WITH (NOLOCK) ON c.custid = t.srecommend
		INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON c.site = s.site

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM #tmpTicket al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)

	SELECT DISTINCT tmp.matchid
		, tbl.AffectedLicenseeNames
		,tbl.CancelCashOutLicenseesNames
		,tbl.ChinaViewLicenseesNames
	FROM #tmpTicket tmp
	CROSS APPLY (
		SELECT STUFF((SELECT DISTINCT  ',' + site
									FROM #tmpTicket t
									WHERE t.IsDeposit = 1 AND t.matchid = tmp.matchid
									FOR XML PATH ('')),1,1,'') AS AffectedLicenseeNames
			,STUFF((SELECT DISTINCT  ',' + site
									FROM #tmpTicket t
									WHERE t.IsCancelCashOut = 1 AND t.matchid = tmp.matchid AND t.IsDeposit = 1
									FOR XML PATH ('')),1,1,'') AS CancelCashOutLicenseesNames
			,STUFF((SELECT DISTINCT  ',' + site
									FROM #tmpTicket t
									WHERE t.IsChinaView = 1 AND t.matchid = tmp.matchid AND t.IsDeposit = 1
									FOR XML PATH ('')),1,1,'') AS ChinaViewLicenseesNames
	)tbl
	
	DROP TABLE #tmpTicket;
END
