/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210906@Louisa
    Task: 20210906@Louisa: Settle by profile for Volleyball [Redmine:#160478]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210906@Louisa: Insert SettlementSpecialBettypeProfile for Volleyball [Redmine:#160478]
*/

USE bodb02
GO

IF OBJECT_ID('tempdb..#tmpBettype') IS NOT NULL
DROP TABLE #tmpBettype

CREATE TABLE #tmpBettype ( sporttype SMALLINT, pfID SMALLINT, BetType SMALLINT, BetID BIGINT, ResourceID VARCHAR(20), OrdNo SMALLINT, RoundID VARCHAR(10), GroupType CHAR(2), RefResourceId VARCHAR(20)	)

INSERT INTO #tmpBettype ( sporttype, pfID, BetType, BetID, ResourceID, OrdNo, RoundID, GroupType, RefResourceId )

VALUES ( 6	,1	,1	,0	,'00'		,99		,NULL	,'FT' , NULL) 
	,  ( 6	,2	,2	,0	,'0100'		,99		,NULL	,'FT' , '00')
	,  ( 6	,3	,3	,0	,'0100'		,99		,NULL	,'FT' , '00') 
	,  ( 6	,20 ,20 ,0	,'00'		,99		,NULL	,'FT' , NULL)


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
					  ,RefResourceId
					)
	SELECT tmp.pfID, tmp.sporttype, tmp.BetType, tmp.BetID, tmp.ResourceID, 'MNL', '', tmp.OrdNo, tmp.RoundID, NULL, tmp.RefResourceId
	FROM #tmpBettype tmp 
		LEFT JOIN dbo.SettlementSpecialBettypeProfile sp WITH(NOLOCK) 
			ON sp.SportType = tmp.sporttype
				AND sp.BetType  = tmp.BetType
				AND sp.pfID		= tmp.pfID
	WHERE sp.BetType IS NULL

