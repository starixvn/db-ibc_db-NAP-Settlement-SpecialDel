/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_PendingMarkTickets_Insert]
(	
	 @SiteDBDownInfoJson	VARCHAR(MAX)  = NULL
	,@RequestId				INT			  = NULL
	,@ActionId				INT			  = 2
)
AS
/*	
	Created by: 20250610@July
	Task: [TVS] Enhance TVS in case 1 or many siteDBs down - Add/Edit request [Redmine: #228047]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20250610@July: Create new SP [Redmine: #228047]
		- 20250815@Lani: [TVS] Return both running and settle tickets of sitedbdown [Redmine: #232580]

	Param's explanation:
	  Notes: Call after save request done
		
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
			SET @sqlCommand = 'EXEC dbo.TicketVoiding_PendingMarkTickets_Insert '
					+ CASE WHEN @RequestId IS NULL THEN '' ELSE '@RequestId = ' + CONVERT(NVARCHAR(50), @RequestId) END
					+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
					+ CASE WHEN @SiteDBDownInfoJson IS NULL THEN '' ELSE ',@SiteDBDownInfoJson = ''' + CONVERT(NVARCHAR(MAX), @SiteDBDownInfoJson) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, NULL, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 
	
	-- Write useraction log
	DECLARE @sqlCommand NVARCHAR(MAX), @ID UNIQUEIDENTIFIER
			, @SubmittedDate DATETIME = GETDATE()
			, @spName VARCHAR(500) = OBJECT_NAME(@@PROCID)
	SET @ID =  NEWID()
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	
			SET @sqlCommand = 'EXEC dbo.TicketVoiding_PendingMarkTickets_Insert '
					+ CASE WHEN @RequestId IS NULL THEN '' ELSE '@RequestId = ' + CONVERT(NVARCHAR(50), @RequestId) END
					+ CASE WHEN @ActionId IS NULL THEN '' ELSE ',@ActionId = ' + CONVERT(NVARCHAR(50), @ActionId) END
					+ CASE WHEN @SiteDBDownInfoJson IS NULL THEN '' ELSE ',@SiteDBDownInfoJson = ''' + CONVERT(NVARCHAR(MAX), @SiteDBDownInfoJson) + '''' END

			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, @sqlCommand, NULL, NULL, GETDATE(),@SubmittedDate)
		END	
	END TRY
	BEGIN CATCH
	END CATCH 

	DECLARE @Decompress_SiteDBDownInfoJson NVARCHAR(MAX) = NULL
	SET @Decompress_SiteDBDownInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @SiteDBDownInfoJson, 1)) AS NVARCHAR(MAX))

	DECLARE @tmpSiteDBDownInfo TABLE (MatchId INT, TransId BIGINT, IsMixParlay BIT, SiteDBGroupID SMALLINT, isMarked BIT)

	IF @ActionId = 2 --Change other action to take note
	BEGIN
		DELETE p
		FROM dbo.TicketVoiding_PendingMarkTickets p
		WHERE RequestId = @RequestId
	END

	INSERT INTO @tmpSiteDBDownInfo (MatchId, TransId, IsMixParlay, SiteDBGroupID, isMarked)
	SELECT mid ,t ,isP ,sitedb, isMarked
	FROM OPENJSON(@Decompress_SiteDBDownInfoJson) 
	WITH( mid INT, t BIGINT, isP BIT ,sitedb SMALLINT, isMarked BIT
	) tbl

	INSERT INTO dbo.TicketVoiding_PendingMarkTickets (TransId, MatchId, StatusId, SiteDBGroupID, RequestId)
	SELECT TransId
		  ,MatchId
		  ,1 -- StatusId = 1 for Running
		  ,SiteDBGroupID
		  ,@RequestId
	FROM @tmpSiteDBDownInfo s
	WHERE NOT EXISTS ( SELECT TOP 1 1 
					   FROM dbo.TicketVoiding_PendingMarkTickets p WITH (NOLOCK)
					   WHERE s.TransId = p.TransId AND p.RequestId = @RequestId
					)
		AND isMarked = 1

	-- Write useraction log	
	BEGIN TRY
		IF OBJECT_ID (N'TVS_UserActionLog') IS NOT NULL 
		BEGIN	       
			INSERT INTO TVS_UserActionLog (ID, SPName, SqlCommand, UserID, Matchid, CreatedDate, SubmittedDate)
			VALUES (@ID, @spName, NULL, NULL, NULL, GETDATE(),@SubmittedDate)
		END        
	END TRY
	BEGIN CATCH
	END CATCH

END
GO