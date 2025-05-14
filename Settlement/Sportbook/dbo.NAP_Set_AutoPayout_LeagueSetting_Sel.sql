/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_LeagueSetting_Sel]
	 @LeagueId					INT
    ,@Sporttype					SMALLINT
	,@AutoType					TINYINT			= 6
AS
/*	Creator: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider
	DB: DBPRO/BODB02
	
	Revisions:
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 1: Auto Payout
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 5: Direct Payout
			+ 6: Auto Payout Model 2
 
*/
BEGIN
	SET NOCOUNT ON

	SELECT	 @LeagueId													AS LeagueId
			,ISNULL(ss.Main_WaitingTime, sr.AP_Main_WaitingTime)		AS Main_WaitingTime
			,ISNULL(ss.Main_HasTrader,1)								AS Main_HasTrader
			,ISNULL(ss.Main_NumberProvider,sr.AP_Main_NumberProvider)	AS Main_NumberProvider
			,ISNULL(ss.Main_PrimaryProvider,'')							AS Main_PrimaryProvider
			,ISNULL(ss.Main_TotalPrimaryProvider,0)						AS Main_TotalPrimaryProvider
			,ISNULL(ss.Main_SecondaryProvider,'')						AS Main_SecondaryProvider
			,ISNULL(ss.Main_TotalSecondaryProvider,0)					AS Main_TotalSecondaryProvider
			,ISNULL(ss.Main_InactiveProvider,'')						AS Main_InactiveProvider
			,ISNULL(ss.EAR_WaitingTime, sr.AP_EAR_WaitingTime)			AS EAR_WaitingTime
			,ISNULL(ss.EAR_HasTrader,1)									AS EAR_HasTrader
			,ISNULL(ss.EAR_NumberProvider,sr.AP_EAR_NumberProvider)		AS EAR_NumberProvider
			,ISNULL(ss.EAR_PrimaryProvider,'')							AS EAR_PrimaryProvider
			,ISNULL(ss.EAR_TotalPrimaryProvider,0)						AS EAR_TotalPrimaryProvider
			,ISNULL(ss.EAR_SecondaryProvider,'')						AS EAR_SecondaryProvider
			,ISNULL(ss.EAR_TotalSecondaryProvider,0)					AS EAR_TotalSecondaryProvider
			,ISNULL(ss.EAR_InactiveProvider,'')							AS EAR_InactiveProvider
			,ss.[Enable]												AS [Enable]
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
	WHERE sr.Sporttype = @Sporttype 	

	
END
GO