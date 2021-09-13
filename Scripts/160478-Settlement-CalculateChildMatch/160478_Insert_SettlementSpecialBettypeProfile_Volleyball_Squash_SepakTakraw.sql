/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210906@Louisa: Insert SettlementSpecialBettypeProfile for Volleyball, Squash, Sepak Takraw [Redmine:#160478]
*/

USE bodb02
GO

IF OBJECT_ID('tempdb..#tmpBettypeVolleyball') IS NOT NULL
DROP TABLE #tmpBettypeVolleyball

CREATE TABLE #tmpBettypeVolleyball ( sporttype SMALLINT, pfID SMALLINT, BetType SMALLINT, BetID BIGINT, ResourceID VARCHAR(20), OrdNo SMALLINT, RoundID VARCHAR(10), GroupType CHAR(2)	)

INSERT INTO #tmpBettypeVolleyball ( sporttype, pfID, BetType, BetID, ResourceID, OrdNo, RoundID, GroupType )
---BetType		 Enabled
VALUES ( 6	,1	,1	,0	,'00'		,99		,NULL	,'FT' ) --1	
	,  ( 6	,2	,2	,0	,'00'		,99		,NULL	,'FT' ) --1	
	,  ( 6	,2	,2	,0	,'0100'		,99		,NULL	,'FT' )
	,  ( 6	,3	,3	,0	,'00'		,99		,NULL	,'FT' )
	,  ( 6	,3	,3	,0	,'0100'		,99		,NULL	,'FT' ) --1
	,  ( 6	,20 ,20 ,0	,'00'		,99		,NULL	,'FT' ) --1	Moneyline
	, ( 30	,1	,1	,0  ,'00'		,99		,NULL	,'FT' ) 
	, ( 30	,2	,2	,0  ,'00'		,99		,NULL	,'FT' ) 
	, ( 30	,2	,2	,0  ,'0100'		,99		,NULL	,'FT' )
	, ( 30	,3	,3	,0  ,'00'		,99		,NULL	,'FT' )
	, ( 30	,3	,3	,0  ,'0100'		,99		,NULL	,'FT' ) 
	, ( 30	,20	,20 ,0  ,'00'		,99		,NULL	,'FT' ) 
	, ( 48	,1	,1	,0  ,'00'		,99		,NULL	,'FT' ) 
	, ( 48	,2	,2	,0  ,'00'		,99		,NULL	,'FT' ) 
	, ( 48	,2	,2	,0  ,'0100'		,99		,NULL	,'FT' )
	, ( 48	,3	,3	,0  ,'00'		,99		,NULL	,'FT' )
	, ( 48	,3	,3	,0  ,'0100'		,99		,NULL	,'FT' ) 
	, ( 48	,20	,20 ,0  ,'00'		,99		,NULL	,'FT' ) 


	INSERT INTO dbo.SettlementSpecialBettypeProfile 
					( pfID
					  ,SportType
					  ,BetType
					  ,BetID
					  ,ResourceID
					  ,SettleType
					  ,GroupType
					  ,OrdNo
					  ,RoundID
					  ,OddsType
					)
	SELECT tmp.pfID, tmp.sporttype, tmp.BetType, tmp.BetID, tmp.ResourceID, 'MNL', '', tmp.OrdNo, tmp.RoundID, NULL
	FROM #tmpBettypeVolleyball tmp 
		LEFT JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON sp.SportType = tmp.sporttype
				AND sp.BetType  = tmp.BetType
				AND sp.pfID		= tmp.pfID
	WHERE sp.BetType IS NULL

