/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_PendingMarkTickets_Insert]
(	
	 @SiteDBDownInfoJson	VARCHAR(MAX)  = NULL
	,@RequestId				INT			  = NULL
)
AS
/*	
	Created by: 20250610@July
	Task: [TVS] Enhance TVS in case 1 or many siteDBs down - Add/Edit request [Redmine: #228047]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20250610@July: Create new SP [Redmine: #228047]

	Param's explanation:
	  Notes: Call after save request done
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @Decompress_SiteDBDownInfoJson NVARCHAR(MAX) = NULL
	SET @Decompress_SiteDBDownInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @SiteDBDownInfoJson, 1)) AS NVARCHAR(MAX))

	DECLARE @tmpSiteDBDownInfo TABLE (MatchId INT, TransId BIGINT, IsMixParlay BIT, SiteDBGroupID SMALLINT, isMarked BIT)

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
					   WHERE s.TransId = p.TransId AND s.MatchId = p.MatchId
					)

END
GO