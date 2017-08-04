/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="1"></info>*/
CREATE FUNCTION [dbo].[f_Settle_NegativeBalance_ActionGroup] ()
RETURNS TABLE
WITH SCHEMABINDING
AS
/*
  Created:20170801@Bobby
  Task: Implement new capture balance method [Redmine:#80774]
  DB: DBTXN/bodb02
  Revisions:
    - 20170801@Bobby: Initial

  Parameters Explanation:    
*/

RETURN (
  SELECT t.ActionId, t.GroupId, g.GroupName
  FROM (
      VALUES 
        (1,   'Single Bet')
        ,(2,  'MixParlay Bet')
        ,(3,  'Outright Bet')
        ,(7,  'Virtual Sport')
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
            ,(108, 1, 1) -- FGLG CAL
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
        ) AS t (ActionId, GroupId, IsActive)
    ) AS t ON t.GroupId = g.GroupId
  WHERE t.IsActive = 1
)
GO
