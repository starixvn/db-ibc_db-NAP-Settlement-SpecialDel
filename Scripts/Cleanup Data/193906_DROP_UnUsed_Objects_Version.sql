/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created:20231227@Louisa
    Task: drop un-use objects [Redmine:#193906]
    DB: DBPRO/bodb02

*/

USE bodb02
GO

IF OBJECT_ID('tempdb..#tmp_Objects') IS NOT NULL
DROP TABLE #tmp_Objects

CREATE TABLE #tmp_Objects ( ObjectName VARCHAR(100) )

INSERT INTO #tmp_Objects ( ObjectName )
VALUES ( 'Acc_ExchangeDel'							   )
	 , ( 'Acc_HedgeDel'								   )
	 , ( 'Acc_HedgeUpd'								   )
	 , ( 'Acc_Set_MatchUpdIsUndecided'				   )
	 , ( 'Acc_Set_MatchUpdScore'					   )
	 , ( 'Acc_UpdateNumberGameBalls'				   )
	 , ( 'Admin_3rdAutoSettlement_s151_Admin_Step1'	   )
	 , ( 'Admin_3rdAutoSettlement_s151_Admin_Step3'	   )
	 , ( 'Admin_3rdAutoSettlement_s151_step1'		   )
	 , ( 'Admin_3rdAutoSettlement_s151_Step3'		   )
	 , ( 'Admin_Settlement_BetDaq_Move'				   )
	 , ( 'Admin_Settlement_Refund_FGLG'				   )
	 , ( 'DBA_DeleteBet_Parlay'						   )
	 , ( 'DBA_SettleOutright_Undo_Event'			   )
	 , ( 'Dot_Acc_Race_ResultUpd'					   )
	 , ( 'Dot_Acc_Race_StatusUpd'					   )
	 , ( 'NAP_Set_MatchUpdIsUndecided'				   )
	 , ( 'NAP_Set_MatchUpdPending'					   )


SELECT COUNT(1) FROM #tmp_Objects

----Drop SP version
BEGIN
	DECLARE @sqlDropProcedureVersion NVARCHAR(MAX) = ''

	SELECT 'DROP PROCEDURE IF EXISTS '+ p.ObjectName + c.version + ' ; '	+ CHAR(13)
	FROM #tmp_Objects p
		CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c

	SET @sqlDropProcedureVersion = ''
	SELECT @sqlDropProcedureVersion = @sqlDropProcedureVersion + 'DROP PROCEDURE IF EXISTS ' + p.ObjectName + c.version + ' ; '	+ CHAR(13)
	FROM #tmp_Objects p
		CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c

	EXEC (@sqlDropProcedureVersion)

	/* For Checking:
		SELECT * FROM sys.objects o	
			CROSS APPLY ( SELECT p.ObjectName FROM #tmp_Objects p 
							WHERE o.name =  p.ObjectName + '_xtest'
								OR o.name = p.ObjectName + '_xpre'
								OR o.name = p.ObjectName + '_UAT1'
								OR o.name = p.ObjectName + '_UAT2'
								OR o.name = p.ObjectName + '_UAT3'
								OR o.name = p.ObjectName + '_UAT4'
						)p
	*/
END
