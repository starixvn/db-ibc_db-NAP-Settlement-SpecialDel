/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlayLog_Ins] 
	@LegOddsJSON	NVARCHAR(MAX)
	,@Offset		INT	
	,@ErrCode		INT = 0 OUTPUT
	,@ErrMsg		NVARCHAR(200) = NULL OUTPUT
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		INSERT INTO dbo.BetBuilderHybridParlayLog (MatchID, TransId, Odds, Offset, LogDate)
		SELECT js.MatchId AS MatchId, js.TransId AS TransId, js.Odds AS Odds, @Offset AS Offset, GETDATE()
		FROM OPENJSON(@LegOddsJSON) WITH (MatchId INT, TransId BIGINT, Odds SMALLMONEY) js
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			,@ErrMsg = ERROR_MESSAGE()
	END CATCH
	
END