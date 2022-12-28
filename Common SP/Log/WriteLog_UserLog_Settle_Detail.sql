ALTER PROCEDURE dbo.WriteLog_UserLog_Settle_Detail
	@Sporttype SMALLINT = 1
	,@MatchId INT = 0
	,@SelectedResouce VARCHAR(MAX) = NULL
AS
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpSelectedResouce TABLE (ResourceId VARCHAR(20))


	INSERT INTO dbo.UserLog_Settle_Detail(Sporttype, MatchId, ResourceId)
	SELECT	@Sporttype, @MatchId, ResourceId
	FROM	@tmpSelectedResouce

END