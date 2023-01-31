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

	IF OBJECT_ID('TicketVoiding_AutoVoidQueue','U') IS NOT NULL
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
	
	IF OBJECT_ID('TicketVoiding_Letstalk','U') IS NOT NULL
	BEGIN
		WHILE (1=1)
		BEGIN
			DELETE TOP(2000) sv
			FROM dbo.TicketVoiding_Letstalk sv
			WHERE sv.StatusId = 2
				AND sv.CreatedDate <= @Archive_Date
			
			IF @@ROWCOUNT = 0 BREAK
		END	
	END
	

	DROP TABLE #requestid_tmp 	
END
GO
	
