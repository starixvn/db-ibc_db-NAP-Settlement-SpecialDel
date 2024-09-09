/*<info serverAlias="DBTXN-bodb02,DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="1"></info>*/
ALTER FUNCTION [dbo].[f_Set_NegativeBalance_ActionGroup] ()
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
  Created:20180104@Helen
  Task: List of ActionID for Negative Balance [Redmine:#80774]
  DB: DBTXN/bodb02, DBLOG/bodb_CustomerLog
  
  Revisions:
    - 20180104@Helen: List of ActionID for Negative Balance [Redmine:#80774]
    - 20190103@Vicky: Incorporate BetBuilder [Redmine:#106903]
    - 20230406@Aries: Un-calculate FT Only [Redmine: #146737]
    - 20240909@Aries: The lack of some ActionIDs when inserting Negative Balance of Parlay Settlement [Redmine: #210338]

  Parameters Explanation:    
*/

RETURN (
  SELECT t.ActionId, t.GroupId, g.GroupName
  FROM (
      VALUES 
        (1, 'Single Bet')
        ,(2,'MixParlay Bet')
		) AS g (GroupId, GroupName)
    INNER JOIN (
          SELECT ActionId, GroupId, IsActive
          FROM (
            VALUES 
            (100, 1, 1)  --CAL All
            ,(101, 1, 1) --CAL FT
            ,(102, 1, 1) --CAL HT
            ,(103, 1, 1) --UNDO
            ,(109, 1, 1) --Refund All
            ,(110, 1, 1) --Refund HT
            ,(111, 1, 1) --Refund FT
            ,(157, 1, 1) -- AutoPayout CAL-HT
            ,(158, 1, 1) -- AutoPayout CAL-FT
            ,(163, 1, 1) -- FGLG CAL-FT
            ,(164, 1, 1) -- FGLG CAL-HT
            ,(148, 1, 1) -- Auto CAL
            ,(149, 1, 1) -- Auto UNDO
            ,(150, 1, 1) -- Auto Refund
            ,(165, 1, 1) -- FM CAL
            ,(166, 1, 1) -- FM UNDO
            ,(167, 1, 1) -- FM Refund
            ,(151, 1, 1) -- Conner CAL
            ,(161, 1, 1) -- Conner FT
            ,(162, 1, 1) -- Conner HT
			,(189, 1, 1) -- CAL Early Settlement
			,(190, 1, 1) -- UNDO Early Settlement
			,(191, 1, 1) -- REFUND Early Settlement
			,(182, 1, 1) -- UNDO Instant Settlement
            ,(81040, 1, 1) -- UNDO FT
			-- Parlay
			,(104, 2, 1) -- Calculate Mix Parlay
			,(105, 2, 1) -- Undo Mix Parlay Settlement
			,(106, 2, 1) -- Refund Mix Parlay FT
			,(107, 2, 1) -- Refund Mix Parlay All
			,(120, 2, 1) -- Refund Mix Parlay HT
			,(81009, 2, 1) -- CAL BetBuilder Settlement
			,(81010, 2, 1) -- UNDO BetBuilder Settlement
            ,(81028, 2, 1) -- Calculate Parlay
			,(81029, 2, 1) -- Refund Parlay
            ,(81030, 2, 1) -- Undo Parlay
        ) AS t (ActionId, GroupId, IsActive)
    ) AS t ON t.GroupId = g.GroupId
  WHERE t.IsActive = 1
)
GO
