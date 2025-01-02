/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241118@Louisa
	Task: InitData for SIT Testing  - Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/


---- RUN THIS SCRIPT ON SIT ONLY
 
USE bodb02
GO 


;WITH cte_ResultDetailOS (MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo)
AS (	--CASE 1: Mercy rule (Away turn not finished.)
		SELECT  65964327, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964327, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964327, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964327, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964327, '0105', '0', '1', 5, 4, 'Mercy'	UNION ALL
		SELECT  65964327, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964327, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964327, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964327, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964327, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964327, '00'  ,'18', '3', 5, 4, NULL		UNION ALL
		--CASE 2: Mercy rule (Away turn finished, Home turn not started OR started or has earned 0 Run at the time.)
		SELECT  65964348, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964348, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964348, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964348, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964348, '0105', '0', '1', 5, 4, 'Mercy'	UNION ALL
		SELECT  65964348, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964348, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964348, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964348, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964348, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964348, '00'  ,'18', '3', 5, 4, NULL		UNION ALL
		--CASE 3: Mercy rule (Away turn finished, Home earned 2 Runs)
		SELECT  65964361, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964361, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964361, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964361, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964361, '0105', '2', '1', 5, 4, 'Mercy'	UNION ALL
		SELECT  65964361, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964361, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964361, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964361, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964361, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964361, '00'  ,'20', '3', 5, 4, NULL		UNION ALL
		--CASE 4: Abandon (Away earned 1 Run ＆ has not finished, Home turn not started)
		SELECT  65964578, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964578, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964578, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964578, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964578, '0105', '0', '1', 5, 7, 'A:0'		UNION ALL
		SELECT  65964578, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964578, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964578, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964578, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964578, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964578, '00'  , '' , '' , 5, 7, NULL		UNION ALL
		--CASE 5: Abandon (Away earned 1 Run ＆ finished normally, Home turn not started OR started or has earned 0 Run at the time)
		SELECT  65964579, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964579, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964579, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964579, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964579, '0105', '0', '1', 5, 7, 'A:1'		UNION ALL
		SELECT  65964579, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964579, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964579, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964579, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964579, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964579, '00'  , '' , '' , 5, 7, NULL		UNION ALL
		--CASE 6: Abandon (Away earned 1 Run ＆ finished normally, Home turn started and Home earned 2 Runs at the time)
		SELECT  65964628, '0101', '3', '0', 5, 4, NULL		UNION ALL
		SELECT  65964628, '0102', '4', '1', 5, 4, NULL		UNION ALL
		SELECT  65964628, '0103', '5', '0', 5, 4, NULL		UNION ALL
		SELECT  65964628, '0104', '6', '1', 5, 4, NULL		UNION ALL
		SELECT  65964628, '0105', '2', '1', 5, 7, 'A:1'		UNION ALL
		SELECT  65964628, '0106', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964628, '0107', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964628, '0108', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964628, '0109', '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964628, 'EI'  , '' , '' , 5, 7, NULL		UNION ALL
		SELECT  65964628, '00'  , '' , '' , 5, 7, NULL 
		)
INSERT INTO ResultDetailOS (MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
SELECT MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo, 8, GETDATE(), 8, GETDATE()
FROM cte_ResultDetailOS
		
		
		
		
		
		

