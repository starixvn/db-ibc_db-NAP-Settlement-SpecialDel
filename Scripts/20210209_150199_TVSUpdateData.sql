/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210209@Max
	Task: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets - [Redmine: #150199]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

USE bodb02
GO
CREATE TABLE #TicketVoiding_tmp(
	[TransId] [bigint] NOT NULL,
	[MessageId] [int] NOT NULL,
	[ReasonId] [int] NOT NULL,
	[MatchId] [int] NULL,
	[CreatedDate] [datetime] NULL ,
	[IssueTypeID] [tinyint] NULL,
	[SubIssueTypeID] [tinyint] NULL,
	[CustID] [int] NULL,
	Isfinished BIT NULL
	)

CREATE TABLE #TicketVoiding_tmp_Batch(
	[TransId] [bigint] NOT NULL,
	[MessageId] [int] NOT NULL,
	[ReasonId] [int] NOT NULL,
	[MatchId] [int] NULL,
	[CreatedDate] [datetime] NULL ,
	[IssueTypeID] [tinyint] NULL,
	[SubIssueTypeID] [tinyint] NULL,
	[CustID] [int] NULL
)

DECLARE @VoidingHistoryId INT,@CreatedDate DATETIME,  @MessageId INT, @ReasonId INT, @Matchid INT, @IssueTypeID TINYINT, @SubIssueTypeID TINYINT

--PRO
SET @VoidingHistoryId = 34943

--Test Local
--SET @VoidingHistoryId = 27369

SELECT TOP 1 @CreatedDate = v.CreatedDate
		, @MessageId = v.MessageId
		, @ReasonId = v.ReasonId
		, @Matchid = v.MatchId
		, @IssueTypeID = v.IssueTypeID
		, @SubIssueTypeID = v.SubIssueTypeID
FROM TicketVoiding_VoidedTransaction v WITH(NOLOCK)
	INNER JOIN zzzbettrans b WITH (NOLOCK) ON v.TransId = b.transid 
WHERE b.VoidingHistoryId = @VoidingHistoryId

SELECT @CreatedDate AS CreatedDate,@MessageId AS MessageId,@ReasonId AS ReasonId
	, @Matchid AS Matchid, @IssueTypeID AS IssueTypeID, @SubIssueTypeID AS SubIssueTypeID
 
INSERT INTO #TicketVoiding_tmp (TransId, MessageId, ReasonId, MatchId, CreatedDate, IssueTypeID, SubIssueTypeID, CustID)
SELECT b.transid, @MessageId, @ReasonId, @Matchid, @CreatedDate, @IssueTypeID, @SubIssueTypeID, b.custid
FROM dbo.zzzbettrans b WITH (NOLOCK)
	OUTER APPLY (
			SELECT v.TransId
			FROM dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK)
			WHERE v.TransId = b.transid
		)t
WHERE b.VoidingHistoryId = @VoidingHistoryId
	AND  t.TransId IS NULL
	
-- Deployer Info
DECLARE @debug_message VARCHAR(500)
SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)

WHILE (1 = 1)
BEGIN
	
	TRUNCATE TABLE #TicketVoiding_tmp_Batch

    UPDATE TOP (1000) t
		SET Isfinished = 1
	OUTPUT DELETED.TransId, DELETED.MessageId, DELETED.ReasonId, DELETED.MatchId, DELETED.CreatedDate, DELETED.IssueTypeID, DELETED.SubIssueTypeID, DELETED.CustID 
	INTO #TicketVoiding_tmp_Batch (TransId, MessageId, ReasonId, MatchId, CreatedDate, IssueTypeID, SubIssueTypeID, CustID)
    FROM #TicketVoiding_tmp t 
    WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0 BREAK
	
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	INSERT INTO dbo.TicketVoiding_VoidedTransaction (TransId, MessageId, ReasonId, MatchId, CreatedDate, IssueTypeID, SubIssueTypeID, CustID)
	SELECT TransId, MessageId, ReasonId, MatchId, CreatedDate, IssueTypeID, SubIssueTypeID, CustID
	FROM #TicketVoiding_tmp_Batch
		
	WAITFOR DELAY '00:00:00.280'			
END	

----------- CHECK DATA -----------------------
SELECT v.*
FROM dbo.zzzbettrans b WITH (NOLOCK)
	LEFT JOIN  dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON v.TransId = b.transid
WHERE b.VoidingHistoryId = 34943 AND v.TransId IS NULL
------------------------------------------------

DROP TABLE #TicketVoiding_tmp_Batch
DROP TABLE #TicketVoiding_tmp