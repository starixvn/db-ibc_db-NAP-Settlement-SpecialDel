/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidByCurrency_SelectAllLicensee]
AS
/*
	Created: Kent
	Date: 20170412
	DB: DBACC/bodb02

	Revisions: 		
		- 20170412@Kent: Get all licensee [Redmine:#75009]		
		- 20180131@Kathy: Update licensees list for China Market [Redmine:#90158]
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
		Name VARCHAR(100) PRIMARY KEY,
		GroupName VARCHAR(100)
	)
	
	INSERT INTO #LicenseeGroupInfo(Name, GroupName) 
	VALUES  -- Others
		    (@MBCGroup_Name, @Others_GroupName)
	      , (@789y_Name, @Others_GroupName)
		    -- China
	      , ('Avia', @China_GroupName)
	      , ('Boma365', @China_GroupName)
	      , ('FLC', @China_GroupName)
	      , ('Hengcai88', @China_GroupName)
	      , ('Salon365', @China_GroupName)
	      , ('Sun988', @China_GroupName)
	      , ('VCBA', @China_GroupName)
	      , ('Webet168', @China_GroupName)
	      , ('Happy1668', @China_GroupName)
	      , ('Leon', @China_GroupName)
	      , ('TLC', @China_GroupName)
	      , ('KeenOcean', @China_GroupName)			
	      , ('88Macao', @China_GroupName)
	      , ('AG', @China_GroupName)
	      , ('Honbet', @China_GroupName)
	      , ('XTD3', @China_GroupName)
	      , ('IBO', @China_GroupName)
	      , ('NewHonbet', @China_GroupName)
	      , ('Abcasino', @China_GroupName)
	      , ('Hecbet', @China_GroupName)
	      , ('TGO', @China_GroupName)
	      , ('365Online', @China_GroupName)
	      , ('HuangMa', @China_GroupName)
	      , ('BigGaming', @China_GroupName)
	      , ('Mayayule', @China_GroupName)
	      , ('Gampag', @China_GroupName)
	      , ('Boying', @China_GroupName)
	      , ('GDC', @China_GroupName)
	      , ('PKbet', @China_GroupName)
	      , ('Webet138', @China_GroupName)
	      , ('CGame', @China_GroupName)
	      , ('TCL', @China_GroupName)
	      , ('Dawoo', @China_GroupName)
	      , ('BetStar', @China_GroupName)
	      , ('TGame', @China_GroupName)
	      , ('LZYQ', @China_GroupName)
	      , ('Starnet', @China_GroupName) 
	      , ('IGPTech', @China_GroupName)
	      , ('BuyWin', @China_GroupName)
	      , ('Ty777', @China_GroupName)
	      , ('HonorW', @China_GroupName)

		  , ('99UU', @China_GroupName)
		  , ('jinyazhou', @China_GroupName)
		  , ('MrCat', @China_GroupName)
		  , ('Swin', @China_GroupName)
		  , ('PanguGame', @China_GroupName)
		  , ('818Bet', @China_GroupName)
		  , ('Heaven', @China_GroupName)
		  , ('Longbao', @China_GroupName)
		  , ('GOAB88', @China_GroupName)
		  , ('Wuming', @China_GroupName)
		  , ('e8casino', @China_GroupName)
		  , ('HongChow', @China_GroupName)
		  , ('Sunrise', @China_GroupName)
		  , ('AK318', @China_GroupName)
		  , ('Holey', @China_GroupName)
		
	;WITH LicenseeList AS
	(     
		SELECT siteid as Id, site as Name
		FROM site WITH(NOLOCK)
		WHERE isLicensee = 1 AND isActive =1 
		  AND siteID NOT IN (29,35)	
		UNION ALL
		SELECT @MBCGroup_Id AS Id, @MBCGroup_Name As Name
		UNION ALL
		SELECT @789y_Id AS Id, @789y_Name As Name 
	)
	SELECT l.Id
		 , l.Name
		 , ISNULL(g.GroupName, @Asia_GroupName) AS GroupName
	FROM LicenseeList l
		 LEFT JOIN #LicenseeGroupInfo g
				 ON l.Name = g.Name
	ORDER BY CASE ISNULL(g.GroupName, @Asia_GroupName)
				WHEN @China_GroupName THEN 1
				WHEN @Asia_GroupName THEN 2
				ELSE 3
			 END ASC
		   , l.Name ASC			 	  		      
	
	SET NOCOUNT OFF
END
GO