/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20230810@Louisa
	Task: Cleanup un-use objects for Settlement [Redmine: #188116]
	DB: DBTXN-bodb02

	Format:
		DROP PROCEDURE DEL_XX
		DROP PROCEDURE XX_xtest | XX_xpre | XX_UAT1 | XX_UAT2 | XX_UAT3 | XX_UAT4
*/


USE bodb02

 	DROP TABLE IF EXISTS #RedundantObject_Temp
	CREATE TABLE #RedundantObject_Temp ( SPName VARCHAR(200), IsFunction BIT  DEFAULT(0) )

	INSERT INTO #RedundantObject_Temp ( SPName )
	VALUES	 ( 'Admin_3rdAutoSettlement_s151_Admin_Step1'		)										  
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
			,( 'NAP_Admin_Settlement_1_InstantCalculation'		) 
			,( 'NAP_Admin_Settlement_1_InstantCalculation_Push' )												  
			,( 'NAP_Admin_Settlement_1_InstantCalculation_Undo' )
			,( 'NAP_Admin_Settlement_Parlay_BetRadar'			) 

	INSERT INTO #RedundantObject_Temp ( SPName, IsFunction )
	VALUES	 ( 'f_Set_Parlay_SDT_CalModds_BetRadar'		, 1 ) 
			,( 'f_Set_Parlay_SDT_CalModds_Corner'		, 1 ) 									  
			,( 'f_Set_Parlay_SDT_CalModds_GoalRecord'	, 1 ) 
			,( 'f_Set_Parlay_SDT_CalModds'				, 1 ) 
			,( 'f_Set_Bettrans_GetBatchTicket'			, 1 )

	SELECT IsFunction , COUNT(1) as cnt  FROM #RedundantObject_Temp GROUP BY IsFunction

	----Drop SP original
	BEGIN
		DECLARE @sqlDropProcedure NVARCHAR(MAX) = ''

		SELECT 'DROP PROCEDURE IF EXISTS DEL_' + p.SPName	+ ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
		WHERE p.IsFunction = 0

		SELECT @sqlDropProcedure = @sqlDropProcedure + 'DROP PROCEDURE IF EXISTS DEL_' + p.SPName	+ ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
		WHERE p.IsFunction = 0

		EXEC sys.sp_executesql @sqlDropProcedure 
		
		/* For Checking:
			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  'del_' + p.SPName
			WHERE p.IsFunction = 0

			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  p.SPName
			WHERE p.IsFunction = 0
		*/

	END

	----Drop SP version
	BEGIN
		DECLARE @sqlDropProcedureVersion NVARCHAR(MAX) = ''
		
		SELECT 'DROP PROCEDURE IF EXISTS '+ p.SPName + c.version+ ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c
		WHERE p.IsFunction = 0

		SELECT @sqlDropProcedureVersion = @sqlDropProcedureVersion + 'DROP PROCEDURE IF EXISTS ' + p.SPName + c.version + ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c
		WHERE p.IsFunction = 0 

		EXEC (@sqlDropProcedureVersion)

		/* For Checking:
			SELECT * FROM sys.objects o	
				CROSS APPLY ( SELECT p.SPName, p.IsFunction FROM #RedundantObject_Temp p 
								WHERE o.name =  p.SPName + '_xtest'
									OR o.name = p.SPName + '_xpre'
									OR o.name = p.SPName + '_UAT1'
									OR o.name = p.SPName + '_UAT2'
									OR o.name = p.SPName + '_UAT3'
									OR o.name = p.SPName + '_UAT4'
							)p
			WHERE p.IsFunction = 0
		*/
	END

	----Drop function original
	BEGIN
		DECLARE @sqlDropFunction NVARCHAR(MAX) = ''

		SELECT 'DROP FUNCTION IF EXISTS DEL_' + p.SPName + ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p WHERE p.IsFunction = 1

		SELECT @sqlDropFunction = @sqlDropFunction + 'DROP FUNCTION IF EXISTS DEL_' + p.SPName + ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
		WHERE p.IsFunction = 1

		EXEC (@sqlDropFunction)

		/* For Checking:
			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  'del_' + p.SPName
			WHERE p.IsFunction = 1

			SELECT * FROM sys.objects o	INNER JOIN #RedundantObject_Temp p ON o.name =  p.SPName
			WHERE p.IsFunction = 1
		*/
	END
	
	----Drop fuction version
	BEGIN
		DECLARE @sqlDropFunctionVersion NVARCHAR(MAX) = ''

		SELECT 'DROP FUNCTION IF EXISTS '+ p.SPName + c.version + ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c
		WHERE p.IsFunction = 1

		SELECT @sqlDropFunctionVersion = @sqlDropFunctionVersion + 'DROP FUNCTION IF EXISTS ' + p.SPName + c.version + ' ; ' + CHAR(13)
		FROM #RedundantObject_Temp p
			CROSS APPLY (SELECT version FROM (VALUES('_xtest'), ('_xpre'), ('_UAT1'), ('_UAT2'), ('_UAT3'), ('_UAT4') )v(version) ) c
		WHERE p.IsFunction = 1

		EXEC (@sqlDropFunctionVersion)

		/* For Checking:
			SELECT * FROM sys.objects o	
				CROSS APPLY ( SELECT p.SPName, p.IsFunction FROM #RedundantObject_Temp p 
								WHERE o.name =  p.SPName + '_xtest'
									OR o.name = p.SPName + '_xpre'
									OR o.name = p.SPName + '_UAT1'
									OR o.name = p.SPName + '_UAT2'
									OR o.name = p.SPName + '_UAT3'
									OR o.name = p.SPName + '_UAT4'
							)p
			WHERE p.IsFunction = 1
		*/
	END
	 
