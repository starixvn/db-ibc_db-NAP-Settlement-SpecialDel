/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_MatchSetting_Sel]
	 @LeagueId					INT
	,@MatchId					INT
    ,@Sporttype					SMALLINT
	,@AutoType					TINYINT			= 6
AS
/*	Creator: 20231211@Aries
	Task: Enhance AutoPayout2 to support Direct Payout
	DB: DBPRO/BODB02
	
	Revisions:
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 6: Auto Payout Model 2
 
*/
BEGIN
	SET NOCOUNT ON

	SELECT	 @LeagueId																			AS LeagueId
			,@MatchId																			AS MatchId
			,COALESCE(ms.Main_WaitingTime,ss.Main_WaitingTime, sr.AP_Main_WaitingTime)			AS Main_WaitingTime
			,COALESCE(ms.Main_HasTrader,ss.Main_HasTrader,1)									AS Main_HasTrader
			,COALESCE(ms.Main_NumberProvider,ss.Main_NumberProvider,sr.AP_Main_NumberProvider)	AS Main_NumberProvider
			,COALESCE(ms.Main_PrimaryProvider,ss.Main_PrimaryProvider,'')						AS Main_PrimaryProvider
			,COALESCE(ms.Main_TotalPrimaryProvider,ss.Main_TotalPrimaryProvider,0)				AS Main_TotalPrimaryProvider
			,COALESCE(ms.Main_SecondaryProvider,ss.Main_SecondaryProvider,'')					AS Main_SecondaryProvider
			,COALESCE(ms.Main_TotalSecondaryProvider,ss.Main_TotalSecondaryProvider,0)			AS Main_TotalSecondaryProvider
			,COALESCE(ms.Main_InactiveProvider,ss.Main_InactiveProvider,'')						AS Main_InactiveProvider
			,COALESCE(ms.EAR_WaitingTime,ss.EAR_WaitingTime, sr.AP_EAR_WaitingTime)				AS EAR_WaitingTime
			,COALESCE(ms.EAR_HasTrader,ss.EAR_HasTrader,1)										AS EAR_HasTrader
			,COALESCE(ms.EAR_NumberProvider,ss.EAR_NumberProvider,sr.AP_EAR_NumberProvider)		AS EAR_NumberProvider
			,COALESCE(ms.EAR_PrimaryProvider,ss.EAR_PrimaryProvider,'')							AS EAR_PrimaryProvider
			,COALESCE(ms.EAR_TotalPrimaryProvider,ss.EAR_TotalPrimaryProvider,0)				AS EAR_TotalPrimaryProvider
			,COALESCE(ms.EAR_SecondaryProvider,ss.EAR_SecondaryProvider,'')						AS EAR_SecondaryProvider
			,COALESCE(ms.EAR_TotalSecondaryProvider,ss.EAR_TotalSecondaryProvider,0)			AS EAR_TotalSecondaryProvider
			,COALESCE(ms.EAR_InactiveProvider,ss.EAR_InactiveProvider,'')						AS EAR_InactiveProvider
			,COALESCE(ms.[Enable],ss.[Enable],NULL)												AS [Enable]
	FROM SettlementResultTableSetting AS sr  WITH(NOLOCK)  
		OUTER APPLY(
			SELECT  s.WaitingTime AS Main_WaitingTime
				   ,s.Main_HasTrader
				   ,s.Main_NumberProvider
				   ,s.Main_PrimaryProvider
				   ,s.Main_TotalPrimaryProvider
				   ,s.Main_SecondaryProvider
				   ,s.Main_TotalSecondaryProvider
				   ,s.Main_InactiveProvider
				   ,s.EAR_WaitingTime
				   ,s.EAR_HasTrader
				   ,s.EAR_NumberProvider
				   ,s.EAR_PrimaryProvider	
				   ,s.EAR_TotalPrimaryProvider
				   ,s.EAR_SecondaryProvider
				   ,s.EAR_TotalSecondaryProvider
				   ,s.EAR_InactiveProvider
				   ,s.[Enable]
			FROM dbo.SettlementSetting AS s WITH(NOLOCK)  
			WHERE s.LeagueId = @LeagueId
			AND s.AutoType = @AutoType
		) AS ss
		OUTER APPLY(
			SELECT  m.WaitingTime AS Main_WaitingTime
				   ,m.Main_HasTrader
				   ,m.Main_NumberProvider
				   ,m.Main_PrimaryProvider
				   ,m.Main_TotalPrimaryProvider
				   ,m.Main_SecondaryProvider
				   ,m.Main_TotalSecondaryProvider
				   ,m.Main_InactiveProvider
				   ,m.EAR_WaitingTime
				   ,m.EAR_HasTrader
				   ,m.EAR_NumberProvider
				   ,m.EAR_PrimaryProvider	
				   ,m.EAR_TotalPrimaryProvider
				   ,m.EAR_SecondaryProvider
				   ,m.EAR_TotalSecondaryProvider
				   ,m.EAR_InactiveProvider
				   ,m.[Enable]
			FROM dbo.AutoPayoutSetting AS m WITH(NOLOCK)  
			WHERE m.MatchId = @MatchId
			AND m.AutoType = @AutoType
		) AS ms
	WHERE sr.Sporttype = @Sporttype 	

	
END
GO