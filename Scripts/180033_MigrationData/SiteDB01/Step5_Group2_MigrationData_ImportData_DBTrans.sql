/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - DBTRANS
    DB: DBCTG-bodb02

	 Revisions:
		- 20221107@Victoria: INSERT from the copy all data of the following tables [Redmineid:#180033] 
							 CustLimitBet_LIC,CustLimitBetHistory_LIC: get by custid
							 CustLimitBet_QueueRetry & CustLimitBetQueue: Only get status = 0 [running]
*/

USE bodb02
GO
------------------------------------------------
/*********UPDATE DATA IF ALREADY EXISTS****************/
--CustLimitBet_LIC
UPDATE main
SET [Matchid]=clb.[Matchid],[AccumTurnover]=clb.[AccumTurnover],[AccumPayout]=clb.[AccumPayout],[EventTypeID]=clb.[EventTypeID],
	[LastQueueID]=clb.[LastQueueID],[ModifiedDate]=clb.[ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBet_LIC_Copy clb WITH (NOLOCK)
	INNER JOIN [dbo].[CustLimitBet_LIC] main WITH (NOLOCK) ON main.CustID = clb.CustID AND main.Matchid = clb.Matchid AND main.EventTypeID = clb.EventTypeID 

--CustLimitBetHistory_LIC
UPDATE main
SET	[Matchid]=clbh.[Matchid],[Transid]=clbh.[Transid],[TurnoverAdjust]=clbh.[TurnoverAdjust],[PayoutAdjust]=clbh.[PayoutAdjust],
	[EventTypeID]=clbh.[EventTypeID],[CreatedDate]=clbh.[CreatedDate],
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBetHistory_LIC_Copy clbh WITH (NOLOCK)
	INNER JOIN [dbo].[CustLimitBetHistory_LIC] main WITH (NOLOCK) ON main.CustID = clb.CustID AND main.Transid = clb.Transid AND main.EventTypeID = clb.EventTypeID 

/*********INSERT DATA IF NOT EXISTS****************/
--CustLimitBet_LIC
INSERT INTO [dbo].[CustLimitBet_LIC] ([Matchid], [CustID], [AccumTurnover], [AccumPayout], [EventTypeID], [LastQueueID], [ModifiedDate])
SELECT	clb.[Matchid], clb.[CustID], clb.[AccumTurnover], clb.[AccumPayout], clb.[EventTypeID], clb.[LastQueueID], clb.[ModifiedDate]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBet_LIC_Copy clb WITH (NOLOCK)
	LEFT JOIN [dbo].[CustLimitBet_LIC] main WITH (NOLOCK) ON main.CustID = clb.CustID AND main.Matchid = clb.Matchid AND main.EventTypeID = clb.EventTypeID 
WHERE main.CustID IS NULL AND main.Matchid IS NULL AND main.EventTypeID IS NULL

--CustLimitBetHistory_LIC
INSERT INTO [dbo].[CustLimitBetHistory_LIC] ([Matchid], [CustID], [Transid], [TurnoverAdjust], [PayoutAdjust], [EventTypeID], [CreatedDate])
SELECT	clbh.[Matchid], clbh.[CustID], clbh.[Transid], clbh.[TurnoverAdjust], clbh.[PayoutAdjust], clbh.[EventTypeID], clbh.[CreatedDate]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBetHistory_LIC_Copy clbh WITH (NOLOCK)
	LEFT JOIN [dbo].[CustLimitBetHistory_LIC] main WITH (NOLOCK) ON main.CustID = clb.CustID AND main.Transid = clb.Transid AND main.EventTypeID = clb.EventTypeID 
WHERE main.CustID IS NULL AND main.Transid IS NULL AND main.EventTypeID IS NULL

--CustLimitBet_QueueRetry
INSERT INTO [dbo].[CustLimitBet_QueueRetry] ([TransId], [Sitetype], [MainQueueId], [StatusId], [Createddate], [Trycount])
SELECT	q.[TransId], q.[Sitetype], q.[MainQueueId], q.[StatusId], q.[Createddate], q.[Trycount]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBet_QueueRetry_Copy q WITH (NOLOCK)
	LEFT JOIN [dbo].[CustLimitBet_QueueRetry] main WITH (NOLOCK) ON main.TransId = q.TransId
WHERE main.TransId IS NULL

--CustLimitBetQueue
INSERT INTO [dbo].[CustLimitBetQueue] ([Matchid], [CustID], [EventTypeID], [Transids], [ActionID], [Statusid], [CreatedDate], [ExecTime], [Duration], [ErrMsg])
SELECT	q.[Matchid], q.[CustID], q.[EventTypeID], q.[Transids], q.[ActionID], q.[Statusid], q.[CreatedDate], q.[ExecTime], q.[Duration], q.[ErrMsg]
FROM DBSIG01.SiteDB01tmp.dbo.CustLimitBetQueue_Copy q WITH (NOLOCK)
	LEFT JOIN [dbo].[CustLimitBetQueue] main WITH (NOLOCK) ON main.Transids = q.Transids
WHERE main.Transids IS NULL
