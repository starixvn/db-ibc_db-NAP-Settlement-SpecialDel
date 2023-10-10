/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20230810@Louisa
	Task: Cleanup un-use objects for Settlement [Redmine: #188116]
	DB: DBCTG-bodb02
*/

---SP in replication

USE bodb02
	

 	DROP TABLE IF EXISTS #RedundantObject_Temp
	CREATE TABLE #RedundantObject_Temp ( SPName VARCHAR(200) )

	INSERT INTO #RedundantObject_Temp ( SPName )
	VALUES	( 'NAP_Admin_Calculate_1'			)
			,( 'NAP_Admin_Calculate_13'			)
			,( 'NAP_Admin_Calculate_1324'		)
			,( 'NAP_Admin_Calculate_135'		)
			,( 'NAP_Admin_Calculate_2'			)
			,( 'NAP_Admin_Calculate_24'			)
			,( 'NAP_Admin_Calculate_25'			)
			,( 'NAP_Admin_Calculate_26'			)
			,( 'NAP_Admin_Calculate_27'			)
			,( 'NAP_Admin_Calculate_28'			)
			,( 'NAP_Admin_Calculate_3'			)
			,( 'NAP_Admin_Calculate_4'			)
			,( 'NAP_Admin_Calculate_468'		)
			,( 'NAP_Admin_Calculate_5'			)
			,( 'NAP_Admin_Calculate_6'			)
			,( 'NAP_Admin_Calculate_603'		)
			,( 'NAP_Admin_Calculate_7'			)
			,( 'NAP_Admin_Calculate_8'			)
			,( 'NAP_Admin_Calculate_901'		)
			,( 'NAP_Admin_Calculate_911'		)
			,( 'NAP_Admin_Calculate_9999'		)
			,( 'NAP_Admin_Calculate_MP_9'		)
			,( 'NAP_Admin_Calculate_Refund_901'	)
			,( 'NAP_Admin_Calculate_RefundAll'	)
			,( 'NAP_Admin_Calculate_RefundFT'	)
			,( 'NAP_Admin_Calculate_RefundHT'	)
			,( 'NAP_Admin_PreCalculate_s160'	)
					
	SELECT count(1) as cnt FROM #RedundantObject_Temp 

	SELECT * FROM bodb02.dbo.MSreplication_objects o WITH(NOLOCK)
	INNER JOIN #RedundantObject_Temp t ON t.SPName = o.article

	----Drop SP original
	BEGIN
		DECLARE @sqlDropProcedure NVARCHAR(MAX) = ''

		SELECT 'DROP PROCEDURE IF EXISTS ' + p.SPName + ' ; '	+ CHAR(13) FROM #RedundantObject_Temp p

		SELECT @sqlDropProcedure = @sqlDropProcedure + 'DROP PROCEDURE IF EXISTS ' + p.SPName	+ ' ; '	+ CHAR(13)
		FROM #RedundantObject_Temp p

		EXEC (@sqlDropProcedure)

		/* For Checking:
			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  'del_' + p.SPName

			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  p.SPName
		*/
	END

	----Drop SP version
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