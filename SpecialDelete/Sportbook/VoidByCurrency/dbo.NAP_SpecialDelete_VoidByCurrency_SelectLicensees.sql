/*<info serverAlias="DBOIC-bodb_OIC" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectLicensees]
AS
/*
	Created: 20180627@Alan
	DB: DBOIC/bodb_OIC  

	Revisions:
		- 20180627@Alan: Mapping China Markets Option for Void By Currency [97393]
		- 20180824@Alan: Get LicenseeName from RegisteredLicenseeName [100481]
		- 20181010@Alan: Include Test Licensee with status is soft launch [102917]
		- 20190320@Alan: Add CN88 into Others Group [109858]
		- 20190412@Alan: Order by CN88 [108826]
		- 20240123@July: Separate group to view data of 777 site [Redmine: #198089]
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MBCGroup_Name		VARCHAR(100) = 'MBC Group'
		  , @789y_Name			VARCHAR(100) = '789y'
		  , @cn88_Name			VARCHAR(100) = 'CN88'
		  , @777_Name			VARCHAR(100) = '777'
		  , @Others_GroupName	VARCHAR(100) = 'Others'
		  , @China_GroupName	VARCHAR(100) = 'China rules'
		  , @Asia_GroupName		VARCHAR(100) = 'Asia rules'

	CREATE TABLE #LicenseeGroupInfo
	(
		Id INT,
		Name VARCHAR(100) PRIMARY KEY,
		GroupName VARCHAR(100)
	)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	VALUES (-1, @MBCGroup_Name, @Others_GroupName)
		 , (0, @789y_Name, @Others_GroupName)
		 , (0, @cn88_Name, @Others_GroupName)
		 , (0, @777_Name, @Others_GroupName)

	INSERT INTO #LicenseeGroupInfo (Id, Name, GroupName)
	SELECT
		LicenseeId AS Id
	   ,RegisteredLicenseeName AS Name
	   ,CASE WHEN IsChineseMarketOnly = 1 THEN @China_GroupName
			ELSE @Asia_GroupName END AS GroupName
	FROM dbo.Licensee WITH(NOLOCK)
	WHERE LicenseeStatusId IN (2, 3) AND RegisteredLicenseeName IS NOT NULL

	SELECT Id ,Name ,GroupName
	FROM #LicenseeGroupInfo
	ORDER BY CASE GroupName
				  WHEN @China_GroupName THEN 1
				  WHEN @Asia_GroupName THEN 2
				  ELSE 3 END ASC,
			 CASE Name 
				  WHEN @789y_Name THEN 1
				  WHEN @MBCGroup_Name THEN 2
				  WHEN @cn88_Name THEN 3
				  WHEN @777_Name THEN 4
				  ELSE 5 END ASC

	DROP TABLE #LicenseeGroupInfo

	SET NOCOUNT OFF
	
END
GO