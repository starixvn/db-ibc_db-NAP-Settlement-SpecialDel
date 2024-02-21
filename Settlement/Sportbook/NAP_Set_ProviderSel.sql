/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet " viewers="" isFunction="0"></info>*/
ALTER PROC [dbo].[NAP_Set_ProviderSel]
AS
/*
    Created by: 20240122@Aries
    Task: Provider Result Log [Redmine:#199100]
    DB: DBPRO/BODB02 
    
    Revisions:            
		- 20240122@Aries: Provider Result Log [Redmine:#199100]
*/
BEGIN
	SET NOCOUNT ON

	SELECT  p.SourceId
		   ,p.SourceName
	FROM ProviderInfo AS p WITH(NOLOCK)
	WHERE p.SourceID < 1001 
		AND p.SourceID NOT IN (98,99,100)
		AND p.isActive = 1
END
GO