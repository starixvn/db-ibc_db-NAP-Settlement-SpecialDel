/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Delete]
AS
/*	
	Created: 20221003@Max
    Task: [TVS] Enhance archive process of TVS data regarding the Scale Out DB project - [Redmine: #178234]
    DB: DBTXN/bodb02
    Revisions:
		- 20221003@Max: Create SP - [Redmine: #178234]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #requestid_tmp (RequestId INT)

	DECLARE @Archive_Date DATETIME
	SELECT @Archive_Date = DATEADD(MONTH, -2, GETDATE())

	IF OBJECT_ID('TicketVoiding_AutoVoidRequest_Queue','U') IS NOT NULL
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) aq
			FROM dbo.TicketVoiding_AutoVoidRequest_Queue aq
			WHERE aq.StatusId = 2
				AND aq.Starttime <= @Archive_Date
			
			IF @@ROWCOUNT = 0 BREAK
		END	
	END
	
	IF OBJECT_ID('TicketVoiding_Queue','U') IS NOT NULL
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) q
			FROM dbo.TicketVoiding_Queue q
			WHERE q.StatusId = 2
				AND q.Starttime <= @Archive_Date
			
			IF @@ROWCOUNT = 0 BREAK
		END	
	END
	
	IF OBJECT_ID('TicketVoiding_Void_Service','U') IS NOT NULL
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) sv
			FROM dbo.TicketVoiding_Void_Service sv
			WHERE sv.StatusId = 2
				AND sv.CreatedDate <= @Archive_Date
			
			IF @@ROWCOUNT = 0 BREAK
		END	
	END
	
	IF OBJECT_ID('TicketVoiding_RequestDetail_MixParlay','U') IS NOT NULL
	BEGIN
		INSERT INTO #requestid_tmp (RequestId)
		SELECT r.RequestId
		FROM dbo.TicketVoiding_Request r WITH (NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = r.RequestId AND rd.FilterBy = 1
		WHERE r.IssueTypeId = 11

		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) rm
			FROM dbo.TicketVoiding_RequestDetail_MixParlay rm
				LEFT JOIN #requestid_tmp t ON t.RequestId = rm.RequestId
			WHERE t.RequestId IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
		END	
	END

	DROP TABLE #requestid_tmp 	
END
GO
	
