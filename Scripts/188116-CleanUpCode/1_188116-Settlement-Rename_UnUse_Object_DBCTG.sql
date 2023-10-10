/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20230810@Louisa
	Task: Cleanup un-use objects for Settlement [Redmine: #188116]
	DB: DBCTG-bodb02
*/


---RUN on DBTRANS/bodb02 only

USE bodb02
GO
 

DROP TABLE IF EXISTS #RedundantObject_Temp

CREATE TABLE #RedundantObject_Temp ( ObjectsName VARCHAR(200) )

INSERT INTO #RedundantObject_Temp ( ObjectsName )
SELECT DISTINCT o.name FROM (VALUES	 ( 'Admin_3rdAutoSettlement_s151_Admin_Step1'	 )										  
						,( 'Admin_3rdAutoSettlement_s151_Admin_Step2'	 	)										  
						,( 'Admin_3rdAutoSettlement_s151_Admin_Step3'	 	)										  
						,( 'Admin_3rdCalculate_s151_Admin'				 	)										  
						,( 'Admin_3rdCalculate_s151_Refund_Admin'		 	)										  
						,( 'Admin_3rdCalculate_s151_Reject_Admin'		 	)
						,( 'Dot_Acc_Race_ResultUpd'					 		)										  
						,( 'Dot_Acc_Race_StatusUpd'					 		)
						,( 'Dot_Admin_HorseResultResettle_Step2'		 	)									  
						,( 'NAP_Admin_Calculate_1101'					 	)										  
						,( 'NAP_Admin_Calculate_1101G'					 	)										  
						,( 'NAP_Admin_Calculate_s162_Refund'			 	)									  
						,( 'NAP_Admin_Settlement_s162'					 	)									  
						,( 'NAP_Get_LiveCasinoGameDetail'				 	)
						,( 'NAP_Get_LiveCasinoGameList'				 		)
						,( 'NAP_Admin_Match_Update_s160'				 	)										  
						,( 'NAP_Admin_Settlement_s160'					 	)										  
						,( 'NAP_Set_MatchSel_s160'						 	)										  
						,( 'NAP_Set_MatchSelDetail_s160'				 	)										  
						,( 'NAP_Set_WinningShareSel'					 	)
						,( 'NAP_Admin_Result_Update_2b'				 		)
						,( 'NAP_Set_MatchSelDetail_Early_2b'			 	)									  
						,( 'NAP_Set_ParlayWaitingSel'					 	)
						,( 'NAP_Set_ResourceResult'						 	)
						,( 'NAP_Admin_Result_Update'					 	)
						,( 'NAP_Set_CheckingMarkedTransaction_OtherSports'	) 
						,( 'NAP_Admin_Settlement_1_CheckBetStatus'		 	)										  
						,( 'NAP_Set_MatchSel_OnePage'					 	)									  
						,( 'NAP_Set_MatchSel_ResultDetail'				 	)										  
						,( 'NAP_Set_MatchSelCompleted'					 	)										  
						,( 'NAP_Set_MatchSelCompletedHT'				 	)
						,( 'NAP_Admin_Settlement_FGLG_Push'			 		)
						,( 'NAP_Admin_Settlement_FGLG'				 		)
						,( 'NAP_Set_AutoPayout_MatchSelFGLG'		 		)
						,( 'NAP_Admin_Settlement_2_Auto_1s'		 			)								  
						,( 'NAP_Admin_Settlement_3_Auto_1s'		 			)
						,( 'NAP_Admin_Calculate_801'				 		)
						,( 'NAP_UserLog_Settle3rd_MatchSelByID'	 			)
						,( 'NAP_Admin_MetricGamingResult_Update'	 		)
						,( 'Nap_Admin_Settlement_MetricGaming'		  		)
						,( 'Nap_Set_LeagueMetricGamingSel'			 		)							  
						,( 'Nap_Set_MatchMetricGamingSel'			 		)							  
						,( 'Nap_Set_MatchMetricGamingSelEvent'		 		)
						,( 'Nap_Set_MatchMetricGamingStatusSel'	 			)
						,( 'NAP_Admin_Calculate_500'		 				)			  
						,( 'NAP_Admin_Calculate_904'		 				)			  
						,( 'NAP_Admin_Calculate_914'		 				)
						,( 'f_Set_Parlay_SDT_CalModds_BetRadar'	 			)
						,( 'f_Set_Parlay_SDT_CalModds_Corner'				)
						,( 'f_Set_Parlay_SDT_CalModds_GoalRecord'			)
						,( 'f_Set_Parlay_SDT_CalModds'				 		)								  
						,( 'NAP_Admin_Settlement_2'				 			)						  
						,( 'NAP_Admin_Settlement_2b_Push'			 		)								  
						,( 'NAP_Admin_Settlement_2b'				 		)							  
						,( 'NAP_Admin_Settlement_3_Basketball'		 		)							  
						,( 'NAP_Admin_Settlement_3_Corner'			 		)							  
						,( 'NAP_Admin_Settlement_4'				 			)						  
						,( 'NAP_Admin_Settlement_Refund_All_Push'	 		)							  
						,( 'NAP_Admin_Settlement_Refund_All'		 		)
						,( 'NAP_Admin_Settlement_RefundFT_Push'	 			)						  
						,( 'NAP_Admin_Settlement_RefundFT'			 		)							  
						,( 'NAP_Admin_Settlement_RefundHT_Push'	 			)						  
						,( 'NAP_Admin_Settlement_RefundHT'			 		)							  
						,( 'NAP_Admin_Settlement_5'				 			)						 
						,( 'NAP_Admin_Settlement_Corner_Push'		 		)							 
						,( 'NAP_Admin_Settlement_Corner'			 		)							 
						,( 'NAP_Admin_Settlement_Refund_FGLG_Push'	 		)							 
						,( 'NAP_Admin_Settlement_Refund_FGLG'		 		)
						,( 'NAP_Admin_Settlement_MP_Push'			 		)							  
						,( 'NAP_Admin_Settlement_MP'				 		)
						,( 'NAP_Admin_Settlement_Parlay_Calculate_9001' 	)
						,( 'NAP_Admin_Settlement_Parlay_Calculate'		 	)								  
						,( 'NAP_Admin_Settlement_Parlay_Refund'		 		)							  
						,( 'NAP_Admin_Settlement_Parlay_SDT'			 	)									  
						,( 'NAP_Admin_Settlement_Refund_MP_Push'		 	)									  
						,( 'NAP_Admin_Settlement_Refund_MP'			 		)								  
						,( 'f_Set_Bettrans_GetBatchTicket'				 	)
						,( 'NAP_Admin_Settlement_1_InstantCalculation'		) 
						,( 'NAP_Admin_Settlement_1_InstantCalculation_Push' )												  
						,( 'NAP_Admin_Settlement_1_InstantCalculation_Undo' )
						,( 'NAP_Admin_Settlement_Parlay_BetRadar'			) 
	)SP(ObjectsName)
		INNER JOIN sys.objects o ON SP.ObjectsName = o.name
	WHERE o.is_published = 0

--SELECT * FROM  #RedundantObject_Temp t 

--SELECT 'EXEC sp_rename '
--		+ '''' + ObjectsName + ''''
--		+ ' , ''DEL_' + ObjectsName + ''''
--FROM #RedundantObject_Temp


DECLARE @sqlRenameObjects NVARCHAR(MAX) = ''

SELECT @sqlRenameObjects =  @sqlRenameObjects + 'EXEC sp_rename '
							+ '''' + ObjectsName + ''''
							+ ' , ''DEL_' + ObjectsName + ''';' + CHAR(13)  
FROM #RedundantObject_Temp  

EXEC sys.sp_executesql @sqlRenameObjects


---Checking:
SELECT * FROM sys.objects o
	INNER JOIN #RedundantObject_Temp t ON o.name =  'del_' + t.ObjectsName

SELECT * FROM sys.objects o
	INNER JOIN #RedundantObject_Temp t ON o.name =   t.ObjectsName
