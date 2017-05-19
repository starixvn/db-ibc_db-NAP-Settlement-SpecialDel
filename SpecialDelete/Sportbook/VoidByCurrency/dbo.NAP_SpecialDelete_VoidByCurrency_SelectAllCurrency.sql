USE [CustDB]
GO
/****** Object:  StoredProcedure [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectAllCurrency]    Script Date: 04/25/2016 09:31:50 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectAllCurrency]
AS
/*
	Created: Kent
	Date: 20161205
	DB: DBCUST/CustDB

	Revisions: 		
		- 20161205@Kent: Get all currency [Redmine:#67987]		
*/
BEGIN
	SET NOCOUNT ON
	
	SELECT exchangeid AS Id, currency AS CurrencyCode
	FROM dbo.exchange WITH(NOLOCK)
	WHERE [Description] IS NULL OR [Description] <> 'Unused'
	ORDER BY CASE WHEN Code = 'CNY' THEN 0 ELSE 1 END, Code
	
	SET NOCOUNT OFF
END
GO

GRANT EXECUTE ON [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectAllCurrency]  TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectAllCurrency]  TO [vnteam] AS [dbo]
GO