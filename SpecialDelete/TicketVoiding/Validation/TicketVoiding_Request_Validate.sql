/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_Validate]
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
		CROSS APPLY ( 
						SELECT RequestId, MatchId, TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
						WHERE RequestId = @RequestId AND m.TransId = TransId
						UNION ALL 
						SELECT RequestId, MatchId, TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay WITH(NOLOCK)
						WHERE RequestId = @RequestId AND m.TransId = TransId 
					)um

		--For case ticket marked function and then save request. Expect: NOT unmarked this ticket.
		BEGIN
			--For single
			DELETE m
			FROM @tmpMarkTransId m 
				INNER JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON m.TransId = mt.TransId
			WHERE mt.MarkType = 0 -- For 0: SD, 1: TVS

			--For sub parlay
			DELETE m
			FROM @tmpMarkTransId m
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.TransId = bm.TransId
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno
					CROSS APPLY (
						 SELECT TOP 1 m.TransId, m.MarkType 
						 FROM dbo.MarkedTransaction m WITH (NOLOCK) 
						 WHERE b.TransId = m.TransId AND bm.matchid = m.MatchId -- Case main parlay for 2 match sub
					 )mt
			WHERE mt.MarkType = 0 -- For 0: SD, 1: TVS
		END

		SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,''),'')
	END

	IF EXISTS (SELECT TOP 1 1 FROM @tmpUnmarkTransId)
	BEGIN
		--For case ticket marked function and then save request. Expect: NOT marked this ticket.
		BEGIN
			--For single
			DELETE m
			FROM @tmpUnmarkTransId m 
				INNER JOIN dbo.MarkedTransaction mt WITH (NOLOCK) ON m.TransId = mt.TransId
			WHERE mt.MarkType = 0 -- For 0: SD, 1: TVS

			--For sub parlay
			DELETE m
			FROM @tmpUnmarkTransId m
					INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.TransId = bm.TransId
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno
					CROSS APPLY (
						 SELECT TOP 1 m.TransId, m.MarkType 
						 FROM dbo.MarkedTransaction m WITH (NOLOCK) 
						 WHERE b.TransId = m.TransId AND bm.matchid = m.MatchId -- Case main parlay for 2 match sub
					 )mt
			WHERE mt.MarkType = 0 -- For 0: SD, 1: TVS
		END
		
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
            SET @sqlCommand = 'OUTPUT ' 
							+ CASE WHEN ISNULL(@MarkTransIds,'') = '' THEN '' ELSE '@MarkTransIds = ''' + CONVERT(NVARCHAR(MAX), @MarkTransIds) + '''' END
							+ CASE WHEN ISNULL(@UnMarkTransIds,'') = '' THEN '' ELSE ',@UnMarkTransIds = ''' + CONVERT(NVARCHAR(MAX), @UnMarkTransIds) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
            VALUES (@ID, @spName, @sqlCommand, @UserID, NULL, GETDATE(),@SubmittedDate)
        END        
	END TRY
	BEGIN CATCH
	END CATCH
END
