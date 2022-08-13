/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Insert]
	@RequestId			INT
	,@MatchId			INT
	,@BatchId			INT = NULL
	,@VoidingHistoryId	INT
	,@VoidingTypeId		TINYINT
	,@TotalTicket		INT
	,@TransIds			VARCHAR(MAX)

	,@UserId			INT
	,@IP				VARCHAR(50)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20210501@July: TVS - Abnormal Account [Redmine: #143666]
		- 20210209@Kathy: insert queue slowly with abnormal account issue type [Redmine:#150199]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #TmpTransId (TransId BIGINT, MatchId INT)
	CREATE TABLE #TmpQueue_Insert (MatchId INT, VoidingHistoryId INT, VoidingTypeId TINYINT, TotalTicket INT, TransIds VARCHAR(MAX), UserId INT, IP VARCHAR(50))
	CREATE TABLE #TmpInputTransIds (TransId BIGINT PRIMARY KEY)
	
	IF (@MatchId <> 0 )
	BEGIN
		INSERT INTO dbo.TicketVoiding_Queue (
			RequestId
			,MatchId
			,VoidingHistoryId
			,TransIds
			,StatusId
			,UserId
			,Ip
			,VoidingTypeId
			,TotalTicket
		)
		SELECT	@RequestId
				,@MatchId
				,@VoidingHistoryId
				,@TransIds
				,0 -- waiting
				,@UserId
				,@IP
				,@VoidingTypeId
				,@TotalTicket
	END
	ELSE
	BEGIN -- Apply for Abnormal account

		INSERT INTO #TmpInputTransIds(TransId)
		SELECT 	DISTINCT value
		FROM 	STRING_SPLIT(@TransIds, ',')
		
		INSERT INTO #TmpTransId (TransId, MatchId)
		SELECT DISTINCT b.TransId, b.matchid
		FROM	dbo.TicketVoiding_RequestDetailTicket_Single b WITH(NOLOCK)
			INNER JOIN #TmpInputTransIds t
				ON 	t.TransId = b.TransId
		WHERE 	b.RequestId = @RequestId		

		INSERT INTO #TmpQueue_Insert (MatchId, VoidingHistoryId, VoidingTypeId, TotalTicket, TransIds, UserId, IP)
		SELECT s.MatchId
			  ,@VoidingHistoryId
			  ,@VoidingTypeId
			  ,COUNT (s.TransId)
			  ,STUFF((SELECT DISTINCT  ',' + CAST( m.TransId AS VARCHAR(20))
							  FROM #TmpTransId m
							  WHERE s.MatchId = m.MatchId
							  FOR XML PATH ('')
							),1,1,'')
			  ,@UserId
			  ,@IP
		FROM #TmpTransId s
		GROUP BY MatchId

		INSERT INTO dbo.TicketVoiding_Queue (
			RequestId
			,MatchId
			,VoidingHistoryId
			,TransIds
			,StatusId
			,UserId
			,Ip
			,VoidingTypeId
			,TotalTicket
		)
		SELECT	@RequestId
				,q.MatchId
				,q.VoidingHistoryId
				,q.TransIds
				,0 -- waiting
				,q.UserId
				,q.IP
				,q.VoidingTypeId
				,q.TotalTicket
		FROM #TmpQueue_Insert q
	END

	DROP TABLE #TmpTransId
	DROP TABLE #TmpQueue_Insert
	DROP TABLE #TmpInputTransIds

END
GO

