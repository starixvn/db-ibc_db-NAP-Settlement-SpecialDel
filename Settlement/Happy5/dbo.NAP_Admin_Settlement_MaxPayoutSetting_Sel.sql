/*<info serverAlias="DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_MaxPayoutSetting_Sel
	 @ListCust		VARCHAR(MAX)
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBSIC/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]
		- 20250328@Louisa: extend data type of currency from tinyint to smallint [Redmine:#222173]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @SiteDBGroupId			SMALLINT
	SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())

	;WITH cteCustIds
	AS(
		SELECT   tbl.c			AS Custid
				,tbl.cur	    AS Currency 		
		FROM OPENJSON(@ListCust) WITH (
				c		INT
			   ,cur		SMALLINT

		) AS tbl
	)
	SELECT	t.custid, fc.MaxWinLimit
	FROM	CustDB.dbo.Customer AS c WITH(NOLOCK)
		INNER JOIN cteCustIds t ON t.custid = c.custid
		INNER JOIN CustDB.dbo.Site AS s WITH(NOLOCK) ON s.site = c.site
		INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs ON s.siteid = fs.siteid
		INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc ON	t.currency = fc.ExchangeId AND fc.SiteDBGroupId = @SiteDBGroupId
END
GO
