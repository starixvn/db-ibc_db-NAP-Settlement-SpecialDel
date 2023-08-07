/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: compare data between SITEDB3 and DBTRANS [Redmineid:#181595] 

*/

---Run on SITEDB3

USE bodb02
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects WHERE name = 'CheckSum_MigrateSiteDB3_Temp')
BEGIN
	CREATE TABLE CheckSum_MigrateSiteDB3_Temp ( ID INT IDENTITY (1,1), TransId BIGINT, TableName VARCHAR(100) )
END

TRUNCATE TABLE CheckSum_MigrateSiteDB3_Temp

--------compare bettrans  --------------------------------------
	;WITH cte_bettrans_SITEDB3 AS (
		SELECT TransId
				,BINARY_CHECKSUM(  t.status, t.winlost, t.awinlost, t.mwinlost, t.playercomm, t.comm, t.acomm, t.apositiontaking, t.mpositiontaking, t.tpositiontaking, t.spositiontaking
									, t.playerdiscount, t.discount, t.adiscount, t.comstatus, t.oddsspread, t.ruben, t.statuswinlost, t.modds, t.sdiscount, t.scomm, t.swinlost, t.statusID, t.winlostdate
								) AS TotalCheckSum
		FROM dbo.bettrans t WITH(NOLOCK)
			INNER JOIN Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
	)
	,cte_bettrans_DBTRANS AS (
		SELECT TransId , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM(  t.status, t.winlost, t.awinlost, t.mwinlost, t.playercomm, t.comm, t.acomm, t.apositiontaking, t.mpositiontaking, t.tpositiontaking, t.spositiontaking
																		, t.playerdiscount, t.discount, t.adiscount, t.comstatus, t.oddsspread, t.ruben, t.statuswinlost, t.modds, t.sdiscount, t.scomm, t.swinlost, t.statusID, t.winlostdate
																	) AS TotalCheckSum
									FROM bodb02.dbo.bettrans t WITH (NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.custid '
						)
	)
	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'bettrans' AS TableName
	FROM cte_bettrans_SITEDB3 site3
		INNER JOIN cte_bettrans_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


--------bettransRnG --------------------------------------
	;WITH cte_bettransRnG_SITEDB3 AS (
		SELECT	TransId  
				,BINARY_CHECKSUM(  status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, playerdiscount, discount  
								 ,adiscount, sdiscount, statusID, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate
								) AS TotalCheckSum
		FROM dbo.bettransRnG t WITH (NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
	)
	,cte_bettransRnG_DBTRANS AS (
	SELECT TransId , TotalCheckSum
	FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM(  status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, playerdiscount, discount  
																 ,adiscount, sdiscount, statusID, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate
															) AS TotalCheckSum
								FROM bodb02.dbo.bettransRnG t WITH (NOLOCK)
									INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.custid '
							)
	)
	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'bettransRnG' AS TableName
	FROM cte_bettransRnG_SITEDB3 site3
		INNER JOIN cte_bettransRnG_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

--------bettransLC  --------------------------------------
	;WITH cte_bettransLC_SITEDB3 AS (
		SELECT	TransId  
				,BINARY_CHECKSUM(	status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, playerdiscount, discount, adiscount
									, sdiscount, statusID, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, winlostdate						
								) AS TotalCheckSum
		FROM dbo.bettransLC t WITH (NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
	)
	,cte_bettransLC_DBTRANS AS (
		SELECT	TransId , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM(	status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking, playerdiscount, discount, adiscount
																	, sdiscount, statusID, IsSum, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm	,winlostdate					
																) AS TotalCheckSum
									FROM bodb02.dbo.bettransLC t WITH (NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.custid '
						)
	)
	
	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'bettransLC' AS TableName
	FROM cte_bettransLC_SITEDB3 site3
		INNER JOIN cte_bettransLC_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

--------bettransG  --------------------------------------
	;WITH cte_bettransG_SITEDB3 AS (
		SELECT	TransId 
				,BINARY_CHECKSUM( status, winlost, apositiontaking, mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount
									, playercomm, comm,acomm, statuswinlost, ruben, spositiontaking, swinlost, sdiscount, scomm, statusID, winlostdate
								) AS TotalCheckSum 
		FROM dbo.bettransG g WITH (NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = g.custid
	)
	,cte_bettransG_DBTRANS AS (
		SELECT	TransId , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM( status, winlost, apositiontaking, mpositiontaking, tpositiontaking, awinlost, mwinlost, playerdiscount, discount, adiscount
								, playercomm, comm,acomm, statuswinlost, ruben, spositiontaking, swinlost, sdiscount, scomm, statusID, winlostdate
																) AS TotalCheckSum  
									FROM bodb02.dbo.bettransG g WITH (NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = g.custid '
						)
	)

	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'bettransG' AS TableName
	FROM cte_bettransG_SITEDB3 site3
		INNER JOIN cte_bettransG_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


---------translog  --------------------------------------
	;WITH cte_translog_SITEDB3 AS (
		SELECT	translogid  
				,BINARY_CHECKSUM(	status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking
									,playerdiscount, discount, adiscount, sdiscount, statusID, checkCount, winlostdate
								) AS TotalCheckSum 
		FROM dbo.translog t WITH (NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = t.custid
	)
	,cte_translog_DBTRANS AS (
		SELECT	translogid  , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT translogid  , BINARY_CHECKSUM(	status, apositiontaking, mpositiontaking, tpositiontaking, spositiontaking
																		,playerdiscount, discount, adiscount, sdiscount, statusID, checkCount, winlostdate
																	) AS TotalCheckSum 
									FROM bodb02.dbo.translog t WITH (NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH (NOLOCK) ON c.custid = t.custid '
						)
	)

 	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.translogid, 'translog' AS TableName
	FROM cte_translog_SITEDB3 site3
		INNER JOIN cte_translog_DBTRANS trans 
			ON site3.translogid = trans.translogid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

---------bettransm  --------------------------------------
	;WITH cte_bettransm_SITEDB3 AS (
		SELECT	transid 
				,BINARY_CHECKSUM(	bm.status, bm.winlost, bm.comstatus, bm.betfrom, bm.apositiontaking, bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost
									,bm.playerdiscount, bm.discount, bm.adiscount, bm.playercomm, bm.comm, bm.acomm, bm.isfinish, bm.statuswinlost, bm.ruben
									, bm.spositiontaking, bm.swinlost,bm.sdiscount, bm.scomm, bm.statusID, bm.winlostdate
								) AS TotalCheckSum
		FROM dbo.bettransm bm WITH (NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH (NOLOCK) ON c.custid = bm.custid
	)
	,cte_bettransm_DBTRANS AS (
		SELECT	transid , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM(	bm.status, bm.winlost, bm.comstatus, bm.betfrom, bm.apositiontaking, bm.mpositiontaking, bm.tpositiontaking, bm.awinlost, bm.mwinlost
																	,bm.playerdiscount, bm.discount, bm.adiscount, bm.playercomm, bm.comm, bm.acomm, bm.isfinish, bm.statuswinlost, bm.ruben
																	, bm.spositiontaking, bm.swinlost,bm.sdiscount, bm.scomm, bm.statusID, bm.winlostdate
																) AS TotalCheckSum
									FROM bodb02.dbo.bettransm bm WITH (NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626  c WITH (NOLOCK) ON c.custid = bm.custid '
						)
	)

	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'bettransm' AS TableName
	FROM cte_bettransm_SITEDB3 site3
		INNER JOIN cte_bettransm_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)

---------transfer  --------------------------------------
	;WITH cte_transfer_SITEDB3 AS  (
		SELECT TransId
				,BINARY_CHECKSUM(	CONVERT(VARCHAR(50), TransDate, 121),CONVERT(VARCHAR(50), WinlostDate, 121),Bettype,Stake,Actual_Stake
								,Winlost,AWinlost,MWinlost,SWinlost,PlayerComm,Comm,AComm,SComm,StatusId
							) AS TotalCheckSum
		FROM dbo.Transfer t WITH(NOLOCK)
			INNER JOIN dbo.Customer_SiteDB_Migrate_xtest c WITH(NOLOCK) ON t.CustId = c.custid
	)
	, cte_transfer_DBTRANS AS  (
		SELECT TransId , TotalCheckSum
		FROM OPENQUERY ( DBCTG, ' SELECT TransId, BINARY_CHECKSUM(	CONVERT(VARCHAR(50), TransDate, 121),CONVERT(VARCHAR(50), WinlostDate, 121),Bettype,Stake,Actual_Stake
																	,Winlost,AWinlost,MWinlost,SWinlost,PlayerComm,Comm,AComm,SComm,StatusId
																) AS TotalCheckSum
									FROM bodb02.dbo.transfer t WITH(NOLOCK)
										INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 c WITH(NOLOCK) On t.CustId = c.custid '
						)
	)

	INSERT INTO CheckSum_MigrateSiteDB3_Temp ( TransId, TableName )
	SELECT site3.transid, 'transfer' AS TableName
	FROM cte_transfer_SITEDB3 site3
		INNER JOIN cte_transfer_DBTRANS trans 
			ON site3.transid = trans.transid
	WHERE ISNULL(site3.TotalCheckSum,0) <> ISNULL(trans.TotalCheckSum,0)


------------------------------------------------
	SELECT COUNT(1) as cnt, TableName
	FROM CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK)
	GROUP BY TableName


