/*<info serverAlias="DBLOG-bodb_Customerlog" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_HybridParlayLogOffset_Sel] 
	@MaxOffSet INT = 0 OUTPUT
AS
/*
    Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBLOG-bodb_Customerlog
	
	Revisions: 
		- 20251027@Max: Init new SP [Redmine: #241652]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON;

	SELECT @MaxOffSet = (SELECT MAX(Offset) FROM dbo.BetBuilderHybridParlayLog l WITH (NOLOCK))
END