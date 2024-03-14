/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0" isNested=""></info>*/

/*	
	Creator: 20240206@Louisa 
	Task: Enhance code VS
	DB: DBPRO-bodb02
	
	Revisions:
		- 20240206: DROP un-use SP  [Redmine:#189854]
 
*/
USE bodb02
GO

BEGIN

 	DROP TABLE IF EXISTS #RedundantObject_Temp
	CREATE TABLE #RedundantObject_Temp ( SPName VARCHAR(200) )
	
	INSERT INTO #RedundantObject_Temp ( SPName )
	VALUES	 ( 'NAP_Set_Match_s193_Sel'	 )										  
			,( 'NAP_Set_Match_s180_Sel'	 )
			,( 'NAP_Set_Match_s178_Sel'	 )

	---- 1. Drop SP original with name has prefix Del_ 
	BEGIN
		DECLARE @sqlDropProcedure NVARCHAR(MAX) = ''

		SELECT 'DROP PROCEDURE IF EXISTS DEL_' + p.SPName + ' ; '	+ CHAR(13) FROM #RedundantObject_Temp p

		SELECT @sqlDropProcedure = @sqlDropProcedure + 'DROP PROCEDURE IF EXISTS DEL_' + p.SPName	+ ' ; '	+ CHAR(13)
		FROM #RedundantObject_Temp p

		EXEC (@sqlDropProcedure)

		/* For Checking:
			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  'del_' + p.SPName
		*/
	END

	---- 2. Drop SP version
	BEGIN
		DECLARE @sqlDropProcedureVersion NVARCHAR(MAX) = ''

		SELECT 'DROP PROCEDURE IF EXISTS '+ p.SPName + c.version + ' ; '	+ CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c

		SET @sqlDropProcedureVersion = ''
		SELECT @sqlDropProcedureVersion = @sqlDropProcedureVersion + 'DROP PROCEDURE IF EXISTS ' + p.SPName + c.version + ' ; '	+ CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c

		EXEC (@sqlDropProcedureVersion)

		/* For Checking:
			SELECT * FROM sys.objects o	
				CROSS APPLY ( SELECT p.SPName FROM #RedundantObject_Temp p 
								WHERE o.name =  p.SPName + '_xtest'
									OR o.name = p.SPName + '_xpre'
									OR o.name = p.SPName + '_UAT1'
									OR o.name = p.SPName + '_UAT2'
									OR o.name = p.SPName + '_UAT3'
									OR o.name = p.SPName + '_UAT4'
							)p
		*/
	END

END
GO

