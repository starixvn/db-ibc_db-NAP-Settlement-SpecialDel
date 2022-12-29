-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
(
	@transIds VARCHAR(MAX)
	, @SiteDBGroupID SMALLINT = 1
	, @tablename VARCHAR(200) = ''
)
/*
	Created by: 20221229@July
	Task: execRep SP for Settlement [Redmine:#181575]
	DB: DBCTG-bodb02
	
	Revisions:
		- 	20221229@July: update sitedbgroupid [Redmine:#181575]

	Param's Explanation:
	
	Samlple execution to parse XML

	DECLARE @transIds VARCHAR(MAX), @xml XML
	
	SET @transIds = (SELECT TOP 10 transid as t
		from bettrans (NOLOCK)
		FOR XML RAW ('r'), ROOT ('root'))

	SET @xml = CAST(@transIds as XML)

	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))

*/	
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @transidXML XML
	DECLARE @tempTrans TABLE (TransID BIGINT PRIMARY KEY)

	SET @transidXML = CONVERT(XML, @Transids)
	
	INSERT INTO @tempTrans (TransID)
	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))
	
	IF (@tablename = 'bettrans' AND OBJECT_ID(N'dbo.bettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
		
	IF (@tablename = 'bettransm' AND OBJECT_ID(N'dbo.bettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettrans14' AND OBJECT_ID(N'dbo.bettrans14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransm14' AND OBJECT_ID(N'dbo.bettransm14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransRnG' AND OBJECT_ID(N'dbo.bettransRnG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'Translog' AND OBJECT_ID(N'dbo.Translog') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'BettransLC' AND OBJECT_ID(N'dbo.BettransLC') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransG' AND OBJECT_ID(N'dbo.bettransG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransRnG14' AND OBJECT_ID(N'dbo.bettransRnG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'Translog14' AND OBJECT_ID(N'dbo.Translog14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'BettransLC14' AND OBJECT_ID(N'dbo.BettransLC14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransG14' AND OBJECT_ID(N'dbo.bettransG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettrans' AND OBJECT_ID(N'dbo.zzzbettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettransm' AND OBJECT_ID(N'dbo.zzzbettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_Single' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_Single') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_Single b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_SubParlay' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_SubParlay') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_SubParlay b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
			
END

GO
