/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241204@Louisa
	Task: InitData for SIT Testing  - Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/


---- RUN THIS SCRIPT ON SIT ONLY
 
USE bodb02
GO 
 /*
 	 66251446 --mercy Inn5 0-1, away not yet completed
	,66251460 --mercy Inn5 0-1, away completed , Home not yet started OR started or has earned 0 Run at time
	,66251461 --mercy Inn5 2-1, Home earned 2 Runs at the time
	,66251464 --Abandon Inn5 0-1, away not yet completed
	,66251481 --Abandon Inn5 0-1, away is early completed, Home not yet started OR started or has earned 0 Run at time
	,66251486 --Abandon Inn5 2-1, Home earned 2 Runs at the time.
	*/


UPDATE match WITH(ROWLOCK, UPDLOCK)
SET eventstatus = 'Completed'
WHERE MatchID IN (  66251446 ,66251460 ,66251461 ,66251464  ,66251481  ,66251486 )
-----------------------------------------------------------------------

UPDATE match WITH(ROWLOCK, UPDLOCK)
SET betstatus = 'Refund'
WHERE MatchID IN (  66251464,66251481,66251486 )
-----------------------------------------------------------------------

UPDATE match WITH(ROWLOCK, UPDLOCK)
SET finalhomescore = 18, finalawayscore = 3
WHERE MatchID IN (  66251446 ,66251460, 66251464 ,66251481)
-----------------------------------------------------------------------
 
UPDATE match WITH(ROWLOCK, UPDLOCK)
SET finalhomescore = 20, finalawayscore = 3
WHERE MatchID IN ( 66251461 ,66251486)
-----------------------------------------------------------------------

;WITH cte_ResultDetailOS (MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo)
AS (	--CASE 1: mercy Inn5 0-1, away not yet completed
		SELECT  66251446, '0101', '3'  , '0'  , 5, 4, NULL		UNION ALL
		SELECT  66251446, '0102', '4'  , '1'  , 5, 4, NULL		UNION ALL
		SELECT  66251446, '0103', '5'  , '0'  , 5, 4, NULL		UNION ALL
		SELECT  66251446, '0104', '6'  , '1'  , 5, 4, NULL		UNION ALL
		SELECT  66251446, '0105', '0'  , '1'  , 5, 4, 'Mercy'	UNION ALL
		SELECT  66251446, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251446, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251446, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251446, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251446, 'EI'  , NULL , NULL , 5, 4, NULL		UNION ALL
		SELECT  66251446, '00'  ,'18'  , '3'  , 5, 4, NULL		UNION ALL
		--CASE 2: mercy Inn5 0-1, away completed , Home not yet started OR started or has earned 0 Run at time
		SELECT  66251460, '0101', '3' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251460, '0102', '4' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251460, '0103', '5' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251460, '0104', '6' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251460, '0105', '0' , '1'   , 5, 4, 'Mercy'	UNION ALL
		SELECT  66251460, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251460, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251460, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251460, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251460, 'EI'  , NULL , NULL , 5, 4, NULL		UNION ALL
		SELECT  66251460, '00'  ,'18'  , '3'  , 5, 4, NULL		UNION ALL
		--CASE 3: mercy Inn5 2-1, Home earned 2 Runs at the time
		SELECT  66251461, '0101', '3' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251461, '0102', '4' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251461, '0103', '5' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251461, '0104', '6' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251461, '0105', '2' , '1'   , 5, 4, 'Mercy'	UNION ALL
		SELECT  66251461, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251461, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251461, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251461, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251461, 'EI'  , NULL , NULL , 5, 4, NULL		UNION ALL
		SELECT  66251461, '00'  ,'20'  , '3'  , 5, 4, NULL		UNION ALL
		--CASE 4: Abandon Inn5 0-1, away not yet completed
		SELECT  66251464, '0101', '3' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251464, '0102', '4' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251464, '0103', '5' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251464, '0104', '6' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251464, '0105', '0' , '1'   , 5, 7, 'A'		UNION ALL
		SELECT  66251464, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251464, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251464, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251464, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251464, '00'  , '18'  ,'3'  , 5, 7, NULL		UNION ALL
		--CASE 5: Abandon Inn5 0-1, away is early completed, Home not yet started OR started or has earned 0 Run at time
		SELECT  66251481, '0101', '3' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251481, '0102', '4' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251481, '0103', '5' , '0'   , 5, 4, NULL		UNION ALL
		SELECT  66251481, '0104', '6' , '1'   , 5, 4, NULL		UNION ALL
		SELECT  66251481, '0105', '0' , '1'   , 5, 7, NULL		UNION ALL
		SELECT  66251481, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251481, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251481, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251481, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251481, '00'  , '18' , '3'  , 5, 7, NULL		UNION ALL
		--CASE 6: Abandon Inn5 2-1, Home earned 2 Runs at the time.
		SELECT  66251486, '0101', '3'  , '0'  , 5, 4, NULL		UNION ALL
		SELECT  66251486, '0102', '4'  , '1'  , 5, 4, NULL		UNION ALL
		SELECT  66251486, '0103', '5'  , '0'  , 5, 4, NULL		UNION ALL
		SELECT  66251486, '0104', '6'  , '1'  , 5, 4, NULL		UNION ALL
		SELECT  66251486, '0105', '2'  , '1'  , 5, 7, NULL		UNION ALL
		SELECT  66251486, '0106', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251486, '0107', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251486, '0108', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251486, '0109', NULL , NULL , 5, 1, NULL		UNION ALL
		SELECT  66251486, '00'  , '20' , '3'  , 5, 7, NULL 
		)
INSERT INTO ResultDetailOS (MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo, CreateBy, CreateDate, LastModifyBy, LastModifyDate)
SELECT MatchID, ResourceID, HomeValue, AwayValue, ResultStatusID, SettlementStatusID, OtherInfo, 8, GETDATE(), 8, GETDATE()
FROM cte_ResultDetailOS


 