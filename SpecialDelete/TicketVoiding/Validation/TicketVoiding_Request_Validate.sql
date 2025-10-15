/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Request_Validate]
(
	 @RequestId				INT			  = NULL
   , @UserID			  	INT			  = NULL
   , @MarkTransIds			VARCHAR(MAX)  =	NULL
   , @UnMarkTransIds		VARCHAR(MAX)  =	NULL
)
AS
/*	Created by: 20251015@July
	Task: Enhance Add/Edit request flow to prevent marking ticket while request is not created [Redmine:#238929]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251015@July: Create new SP [Redmine:#238929]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	-- Write useraction log 
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)

	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN		
			SET @sqlCommand = 'EXEC dbo.TicketVoiding_Request_Validate '
				+ CASE WHEN @RequestId IS NULL THEN '' ELSE '@RequestId = ' + CONVERT(NVARCHAR(50), @RequestId) END
				+ CASE WHEN @UserID IS NULL THEN '' ELSE ',@UserID = ' + CONVERT(NVARCHAR(50), @UserID) END
				+ CASE WHEN @MarkTransIds IS NULL THEN '' ELSE ',@MarkTransIds = ''' + CONVERT(NVARCHAR(MAX), @MarkTransIds) + '''' END
				+ CASE WHEN @UnMarkTransIds IS NULL THEN '' ELSE ',@UnMarkTransIds = ''' + CONVERT(NVARCHAR(MAX), @UnMarkTransIds) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, @UserID, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	
	INSERT INTO @tmpMarkTransId (TransId)
	SELECT value
	FROM STRING_SPLIT(@MarkTransIds, ',')
	WHERE value <> ''

	INSERT INTO @tmpUnmarkTransId (TransId)
	SELECT value
	FROM STRING_SPLIT(@UnMarkTransIds, ',')
	WHERE value <> ''

	SET @MarkTransIds = ''
	SET @UnmarkTransIds = ''

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMarkTransId)
	BEGIN
		DELETE m
		FROM @tmpMarkTransId m 
		OUTER APPLY ( 
						SELECT RequestId, MatchId, TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
						WHERE RequestId = @RequestId AND m.TransId = TransId
						UNION ALL 
						SELECT RequestId, MatchId, TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
						WHERE RequestId = @RequestId AND m.TransId = TransId 
					)um
		WHERE um.TransId IS NULL

		SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,''),'')
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tmpUnmarkTransId)
	BEGIN
		--Mark again
		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,''),'')
	END
	
	SELECT @MarkTransIds AS MarkTransIds
	     , @UnmarkTransIds AS UnmarkTransIds

	-- Write useraction log	
	BEGIN TRY
        IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	       
            INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, NULL, @UserID, NULL, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH
END
