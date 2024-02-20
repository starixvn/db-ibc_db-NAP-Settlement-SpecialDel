/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0" isNested=""></info>*/

/*	
	Creator: 20240206@Louisa 
	Task: Enhance code VS
	DB: DBPRO-bodb02
	
	Revisions:
		- 20240206: Rename un-use SP [Redmine:#189854]
 
*/

USE bodb02
GO

BEGIN
	DROP TABLE IF EXISTS #RedundantObject_Temp

	CREATE TABLE #RedundantObject_Temp ( ObjectsName VARCHAR(200) )

	INSERT INTO #RedundantObject_Temp ( ObjectsName )
	SELECT DISTINCT o.name 
	FROM (VALUES	 ( 'NAP_Set_Match_s193_Sel'	 )										  
					,( 'NAP_Set_Match_s180_Sel'	 )
					,( 'NAP_Set_Match_s178_Sel'	 )
		)SP(ObjectsName)
		INNER JOIN sys.objects o ON SP.ObjectsName = o.name
	WHERE o.is_published = 0

	-------------------------------------------------
	DECLARE @sqlRenameObjects NVARCHAR(MAX) = ''

	SELECT @sqlRenameObjects =  @sqlRenameObjects + 'EXEC sp_rename '
								+ '''' + ObjectsName + ''''
								+ ' , ''DEL_' + ObjectsName + ''';' + CHAR(13)  
	FROM #RedundantObject_Temp  

	EXEC sys.sp_executesql @sqlRenameObjects
	

	---Checking:
	SELECT * FROM sys.objects o
		INNER JOIN #RedundantObject_Temp t ON o.name =  'DEL_' + t.ObjectsName

	SELECT * FROM sys.objects o
		INNER JOIN #RedundantObject_Temp t ON o.name =   t.ObjectsName

END
GO

