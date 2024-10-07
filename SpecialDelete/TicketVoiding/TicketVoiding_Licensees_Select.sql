/*<info serverAlias="DBOIC-bodb_OIC" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Licensees_Select]
AS
/*	Created by: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCUST-CustDB
	
	Revisions: 
		- 20240925@July: Create new SP [Redmine: #187408]
	
	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MBCGroup_Name		VARCHAR(100) = 'MBC Group'
		  , @789y_Name			VARCHAR(100) = '789y'
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
				  WHEN @777_Name THEN 3
				  ELSE 4 END ASC

	DROP TABLE #LicenseeGroupInfo

	SET NOCOUNT OFF
	
END
GO