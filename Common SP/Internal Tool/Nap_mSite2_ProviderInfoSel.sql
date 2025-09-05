/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_mSite2_ProviderInfoSel]
AS
/*
	Created by: 20250808@Louisa
	Task: mSite2-mapping Provider  [Redmine:#235224]
	Server: db061
	DB: DBPRO-bodb02

	Revision:
		20250808@Louisa: Create [Redmine:#235224]

	* @ProductId = 1: Sportbook

*/
BEGIN
	SET NOCOUNT ON

	SELECT p.SourceId, p.SourceName, p.Remark
	FROM ProviderInfo p WITH(NOLOCK)
	WHERE p.SourceId < 1001 
		AND p.SourceId <> 100
		AND p.isActive = 1

END
GO