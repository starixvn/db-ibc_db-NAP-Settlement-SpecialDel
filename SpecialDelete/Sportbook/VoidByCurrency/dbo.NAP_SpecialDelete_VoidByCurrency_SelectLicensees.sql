/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectLicensees]
AS
/*
	Created: Alan
	Date: 20180627
	DB: DBOIC/bodb_OIC  

	Revisions:
		- 20180627@Alan: Mapping China Markets Option for Void By Currency [97393]
		- 20180824@Alan: Get LicenseeName from RegisteredLicenseeName [100481]
*/
BEGIN
SET NOCOUNT ON

	DECLARE @MBCGroup_Id		 INT		  = -1
		  , @MBCGroup_Name		 VARCHAR(100) = 'MBC Group'
		  , @789y_Id			 INT		  = 0
		  , @789y_Name			 VARCHAR(100) = '789y'
		  , @Others_GroupName	 VARCHAR(100) = 'Others'
		  , @China_GroupName	 VARCHAR(100) = 'China rules'
		  , @Asia_GroupName		 VARCHAR(100) = 'Asia rules'

	CREATE TABLE #LicenseeGroupInfo
	(
		Id INT,
		Name VARCHAR(100) PRIMARY KEY,
		GroupName VARCHAR(100)
	)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	VALUES (@MBCGroup_Id, @MBCGroup_Name, @Others_GroupName)
	, (@789y_Id, @789y_Name, @Others_GroupName)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	SELECT
		LicenseeId AS Id
	   ,RegisteredLicenseeName AS Name
	   ,CASE WHEN IsChineseMarketOnly = 1 THEN @China_GroupName
			ELSE @Asia_GroupName END AS GroupName
	FROM dbo.Licensee WITH(NOLOCK)
	WHERE LicenseeStatusId = 3 AND RegisteredLicenseeName IS NOT NULL

	SELECT Id ,Name ,GroupName
	FROM #LicenseeGroupInfo
	ORDER BY CASE GroupName
		WHEN @China_GroupName THEN 1
		WHEN @Asia_GroupName THEN 2
		ELSE 3	END ASC	,Name ASC

	SET NOCOUNT OFF
	DROP TABLE #LicenseeGroupInfo
END
GO