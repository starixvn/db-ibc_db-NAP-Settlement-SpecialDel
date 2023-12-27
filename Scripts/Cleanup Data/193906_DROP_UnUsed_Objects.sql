/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created:20230915@Louisa
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
SELECT COUNT(1)
FROM #tmp_Objects tmp
INNER JOIN sys.objects o WITH(NOLOCK)
	ON  tmp.ObjectName = o.name

DECLARE @sqlDropProcedure NVARCHAR(MAX) = ''

SELECT @sqlDropProcedure = @sqlDropProcedure + 'DROP PROCEDURE IF EXISTS ' + tmp.ObjectName	+ ' ; ' + CHAR(13)
FROM #tmp_Objects tmp

PRINT @sqlDropProcedure

EXEC sys.sp_executesql @sqlDropProcedure 

/* For Checking:
	
	SELECT o.name 
	FROM #tmp_Objects tmp
	INNER JOIN sys.objects o WITH(NOLOCK)
		ON  tmp.ObjectName = o.name

*/

