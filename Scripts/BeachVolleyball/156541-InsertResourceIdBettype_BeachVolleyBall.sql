/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by: 20210611@Louisa
    Task: 20210611@Louisa: Beach Volleyball [Redmine:#156541]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210611@Louisa: Beach Volleyball [Redmine:#156541]
*/

USE bodb02
GO



	--- 4 main bettype - 4 rows
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
			VALUES 
			 ( 10	,45 ,1	,0 ,'00' ,'MNL' ,'FT', 99 ,0 , NULL ) --Handicap		
			,( 2	,45 ,2	,0 ,'00' ,'MNL' ,'FT', 99 ,0 , NULL ) --Odd/Even (Settle on TotalPoint)		
			,( 3	,45 ,3	,0 ,'00' ,'MNL' ,'FT', 99 ,0 , NULL ) --Over/Under (Settle on TotalPoint)					
			,( 20	,45 ,20	,0 ,'00' ,'MNL' ,'FT', 99 ,0 , NULL ) --Moneyline		

GO
