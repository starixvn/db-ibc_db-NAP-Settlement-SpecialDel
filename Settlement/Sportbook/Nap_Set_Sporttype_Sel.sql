/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Set_Sporttype_Sel]
	@ProductId TINYINT = 1
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

	SELECT s.SportType, s.SportName
	FROM dbo.Sports s WITH(NOLOCK)
	WHERE 1 = CASE WHEN @ProductId = 1 AND s.SportType <=99 THEN 1
					ELSE 0
					END
END
GO